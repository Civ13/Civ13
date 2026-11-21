using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace Civ13.Launcher;

// Experimental (off by default): notices when Windows' management service (WMI) stops answering and
// guides a person through the usual repairs. On 2026-11-19 a broken WMI provider ("Provider load
// failure") made tasklist hang and kept Gaia down; a hung WmiPrvSE.exe or a winmgmt service stuck
// stopping also makes Windows restarts hang on "Restarting".
//
// The check only reads: one small WMI query with a short limit, the service state from the service
// manager (sc.exe, not WMI) and the count of WMI provider hosts from the kernel's process list. This is
// the one place the launcher asks WMI anything on purpose. Every repair step needs administrator rights
// and runs only when the person clicks it, through Windows' own elevation prompt.
public static partial class WmiHealth {
    public const string Option = "--wmi";
    public const string FileName = "experimental.json";
    public const string Setting = "wmi_health_check";
    public static readonly TimeSpan QueryLimit = TimeSpan.FromSeconds(15);
    public static readonly TimeSpan ServiceLimit = TimeSpan.FromSeconds(10);
    // A query slower than this counts as struggling even when it answers.
    public static readonly TimeSpan SlowQuery = TimeSpan.FromSeconds(5);

    public enum State { Healthy, Slow, Broken, Unknown }

    public sealed record Diagnosis(State State, string Summary, string? ServiceState, int? ServicePid, int ProviderHosts, string Detail) {
        public bool NeedsHelp => State is State.Slow or State.Broken;
    }

    // One repair: what it does, and the PowerShell it runs elevated. {pid} is the winmgmt service host's pid.
    public sealed record Step(string Id, string Title, string Explanation, string Command, bool NeedsServicePid = false);

    public static readonly IReadOnlyList<Step> Steps = [
        new("end-providers", "1. End the WMI provider hosts",
            "Most broken WMI is a hung WmiPrvSE.exe. Ending them is safe: Windows starts new ones on the next query.",
            "Get-Process WmiPrvSE -ErrorAction SilentlyContinue | Stop-Process -Force; 'Ended the WMI provider hosts.'"),
        new("restart-service", "2. Restart the WMI service",
            "Restarts winmgmt. Services that depend on it (such as IP Helper) restart with it; check they came back.",
            "Restart-Service winmgmt -Force; Get-Service winmgmt | Format-List Name,Status"),
        new("end-service-host", "3. End the stuck WMI service host",
            "Only when the service hangs on \"Stopping\": ends its host process, then starts the service again. On some " +
            "Windows builds that host carries other services too; restart those afterwards.",
            "Stop-Process -Id {pid} -Force; Start-Sleep -Seconds 2; Start-Service winmgmt; Get-Service winmgmt | Format-List Name,Status", NeedsServicePid: true),
        new("verify", "4. Check the WMI repository",
            "Reports whether WMI's database is consistent. It changes nothing.",
            "winmgmt /verifyrepository"),
        new("salvage", "5. Repair the WMI repository",
            "Only when step 4 reports it inconsistent, or WMI keeps breaking: rebuilds what it can of WMI's database.",
            "winmgmt /salvagerepository"),
    ];

    // -- the setting (launcher root, experimental.json) --------------------------------------------------
    public static bool Enabled(string root) {
        try {
            var path = Path.Combine(root, FileName);
            return File.Exists(path) && JsonNode.Parse(File.ReadAllText(path)) is JsonObject json
                && json[Setting] is JsonValue value && value.TryGetValue<bool>(out var on) && on;
        } catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException) { return false; }
    }

    public static void SetEnabled(string root, bool on) {
        var path = Path.Combine(root, FileName);
        JsonObject json;
        try { json = File.Exists(path) && JsonNode.Parse(File.ReadAllText(path)) is JsonObject read ? read : new JsonObject(); }
        catch (JsonException) { json = new JsonObject(); }
        json[Setting] = on;
        var temporary = path + ".tmp";
        File.WriteAllText(temporary, json.ToJsonString(new JsonSerializerOptions { WriteIndented = true }) + "\n");
        File.Move(temporary, path, true);
    }

    // -- the check -------------------------------------------------------------------------------------
    public static ProcessStartInfo QueryStep() {
        var step = PowerShell("(Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).Caption");
        return step.WithLimit(QueryLimit);
    }

    public static ProcessStartInfo ServiceStep() {
        var step = new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, "sc.exe")) {
            UseShellExecute = false, CreateNoWindow = true, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "queryex", "winmgmt" }) step.ArgumentList.Add(argument);
        return step.WithLimit(ServiceLimit);
    }

    public static Diagnosis Check(Func<ProcessStartInfo, (int Exit, string Output)>? run = null, Func<int>? providerHosts = null) {
        run ??= LocalHosting.RunCaptured;
        string? serviceState = null;
        int? servicePid = null;
        try {
            var (_, service) = run(ServiceStep());
            (serviceState, servicePid) = ParseService(service);
        } catch (Exception e) when (e is IOException or System.ComponentModel.Win32Exception or InvalidOperationException) { }
        var hosts = 0;
        try { hosts = (providerHosts ?? (() => ProcessSafety.ByName("WmiPrvSE").Count))(); }
        catch (Exception e) when (e is InvalidOperationException or System.ComponentModel.Win32Exception) { }
        var watch = Stopwatch.StartNew();
        try {
            var (exit, output) = run(QueryStep());
            return Classify(exit, output, false, watch.Elapsed, serviceState, servicePid, hosts);
        } catch (LocalHosting.StepTimedOut) {
            return Classify(-1, "", true, watch.Elapsed, serviceState, servicePid, hosts);
        } catch (Exception e) when (e is IOException or System.ComponentModel.Win32Exception or InvalidOperationException) {
            return new(State.Unknown, "The check could not run: " + e.Message, serviceState, servicePid, hosts, e.Message);
        }
    }

    // sc.exe queryex winmgmt: "STATE : 4  RUNNING" and "PID : 1234".
    public static (string? State, int? Pid) ParseService(string output) {
        var state = StateLine().Match(output) is { Success: true } s ? s.Groups[1].Value.ToUpperInvariant() : null;
        int? pid = PidLine().Match(output) is { Success: true } p && int.TryParse(p.Groups[1].Value, out var value) && value > 0 ? value : null;
        return (state, pid);
    }

    public static Diagnosis Classify(int exit, string output, bool timedOut, TimeSpan elapsed, string? serviceState, int? servicePid, int hosts) {
        var detail = output.Trim();
        string Service() => serviceState == null ? "" : $" The WMI service is {serviceState.ToLowerInvariant().Replace('_', ' ')}.";
        if (serviceState is "STOP_PENDING" or "START_PENDING")
            return new(State.Broken, $"The WMI service is stuck {(serviceState == "STOP_PENDING" ? "stopping" : "starting")}. Try step 3, then step 4.",
                serviceState, servicePid, hosts, detail);
        if (timedOut)
            return new(State.Broken, $"WMI did not answer within {QueryLimit.TotalSeconds:0} s.{Service()} Try steps 1 and 2, then step 4.",
                serviceState, servicePid, hosts, detail);
        if (exit != 0 || detail.Length == 0) {
            var provider = detail.Contains("Provider load failure", StringComparison.OrdinalIgnoreCase);
            return new(State.Broken, (provider ? "WMI reports \"Provider load failure\"." : "The WMI query failed.") + Service() +
                " Try steps 1 and 2, then step 4.", serviceState, servicePid, hosts, detail);
        }
        if (elapsed > SlowQuery)
            return new(State.Slow, $"WMI answered, but took {elapsed.TotalSeconds:0} s.{Service()} If it stays slow, try step 1.",
                serviceState, servicePid, hosts, detail);
        return new(State.Healthy, $"WMI answers normally ({elapsed.TotalSeconds:0.0} s).{Service()}", serviceState, servicePid, hosts, detail);
    }

    public static string Describe(Diagnosis diagnosis) =>
        diagnosis.Summary + $" WMI provider hosts running: {diagnosis.ProviderHosts}." +
        (diagnosis.ServicePid is { } pid ? $" Service host process: {pid}." : "");

    // -- repairs -----------------------------------------------------------------------------------------
    // The elevated PowerShell for a step. Its output goes to outputFile, since an elevated process cannot
    // write to this one's pipes. Windows asks the person to confirm the elevation.
    public static ProcessStartInfo Elevated(Step step, string outputFile, int? servicePid = null) {
        if (step.NeedsServicePid && servicePid is not > 0) throw new InvalidOperationException("The WMI service host's process id is unknown; run the check again.");
        var command = step.Command.Replace("{pid}", servicePid?.ToString() ?? "");
        if (outputFile.Contains('\'')) throw new InvalidDataException("The output path cannot contain quotes.");
        var script = $"& {{ {command} }} *>&1 | Out-File -Encoding utf8 -FilePath '{outputFile}'";
        return new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe")) {
            UseShellExecute = true, Verb = "runas", WindowStyle = ProcessWindowStyle.Hidden,
            Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"" + script.Replace("\"", "\\\"") + "\"" };
    }

    // Runs a step elevated and returns what it printed. Throws Win32Exception when the person declines.
    public static string RunElevated(Step step, int? servicePid = null) {
        var output = Path.Combine(Path.GetTempPath(), "civ13-wmi-" + Guid.NewGuid().ToString("N") + ".txt");
        try {
            using var process = Process.Start(Elevated(step, output, servicePid)) ?? throw new IOException("Could not start PowerShell.");
            if (!process.WaitForExit(TimeSpan.FromMinutes(3))) return "The step is still running after 3 minutes; check again later.";
            var text = File.Exists(output) ? File.ReadAllText(output).Trim() : "";
            return text.Length > 0 ? text : $"Finished (exit {process.ExitCode}).";
        } finally {
            try { File.Delete(output); } catch (IOException) { } catch (UnauthorizedAccessException) { }
        }
    }

    // Civ13.exe --wmi check: the read-only check, for a script or a remote helper. Repairs stay in the window.
    public static int Command(string[] args, TextWriter output) {
        if (args.Length != 2 || args[1] != "check") { output.WriteLine("Usage: --wmi check"); return 2; }
        var diagnosis = Check();
        output.WriteLine(Describe(diagnosis));
        if (diagnosis.NeedsHelp) {
            output.WriteLine("Repairs (each needs an administrator PowerShell; the launcher window can run them for you):");
            foreach (var step in Steps) output.WriteLine($"  {step.Title}: {step.Command.Replace("{pid}", diagnosis.ServicePid?.ToString() ?? "<pid>")}");
        }
        return diagnosis.State switch { State.Healthy => 0, State.Unknown => 3, _ => 1 };
    }

    private static ProcessStartInfo PowerShell(string command) {
        var step = new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe")) {
            UseShellExecute = false, CreateNoWindow = true, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "-NoProfile", "-NonInteractive", "-Command", command }) step.ArgumentList.Add(argument);
        return step;
    }

    [GeneratedRegex(@"STATE\s*:\s*\d+\s+(\w+)", RegexOptions.IgnoreCase)] private static partial Regex StateLine();
    [GeneratedRegex(@"\bPID\s*:\s*(\d+)", RegexOptions.IgnoreCase)] private static partial Regex PidLine();
}
