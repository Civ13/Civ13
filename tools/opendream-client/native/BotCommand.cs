using System.Diagnostics;

namespace Civ13.Launcher;

// Civ13.exe --bot ACTION [--root FOLDER]: the Civilizationbot tab's buttons without the window, so a
// script (or a remote helper) can manage the configured bot. Every action goes through the bot's own
// scripts/windows/control.php with only the action and host.json's profile on the command line.
// Unlike the window, start leaves the bot running after this command exits: the supervisor is created
// by Windows (CIM Win32_Process.Create), outside this process and any job object its caller holds.
public static class BotCommand {
    public const string Option = "--bot";
    public static readonly string[] Actions = ["status", "check-update", "start", "stop", "restart", "update", "repair"];
    public static readonly TimeSpan StopWait = TimeSpan.FromSeconds(90);
    public static readonly TimeSpan StartWait = TimeSpan.FromSeconds(30);
    private static readonly TimeSpan Poll = TimeSpan.FromSeconds(2);

    // StartDirect: the start used when Windows' WMI service does not answer (null: no fallback).
    public sealed record Hooks(Func<ProcessStartInfo, (int Exit, string Output)> Run, Func<TimeSpan, Task> Delay, Func<HostBot, int>? StartDirect = null);

    public static Hooks System { get; } = new(LocalHosting.RunCaptured, Task.Delay, bot => ProcessSafety.StartDetached(CommandLine(bot), bot.Root));

    // A WMI create that has not answered by then is treated as broken (criticality: a start never waits on WMI).
    public static readonly TimeSpan DetachLimit = TimeSpan.FromSeconds(20);

    // Returns the action and an explicit --root, or throws for anything else on the command line.
    public static (string Action, string? Root) Parse(string[] args) {
        if (args.Length < 2 || args[0] != Option || !Actions.Contains(args[1]))
            throw new ArgumentException("Usage: --bot " + string.Join("|", Actions) + " [--root <absolute folder>]");
        if (args.Length == 2) return (args[1], null);
        if (args.Length == 4 && args[2] == "--root") return (args[1], LocalDreamDaemon.RequirePath(args[3]));
        throw new ArgumentException("Usage: --bot " + string.Join("|", Actions) + " [--root <absolute folder>]");
    }

    // Civ13.exe --bot log-level [debug|info|notice|warning|error] [--root FOLDER]: shows or sets the profile's
    // log_level, which the bot reads when it next starts. Kept apart from Actions so Parse stays unchanged.
    public const string LogLevelAction = "log-level";
    private static string LogLevelUsage => "Usage: --bot log-level [" + string.Join("|", LocalBot.LogLevels) + "] [--root <absolute folder>]";

    public static (string? Level, string? Root) ParseLogLevel(string[] args) {
        if (args.Length < 2 || args[0] != Option || args[1] != LogLevelAction) throw new ArgumentException(LogLevelUsage);
        var rest = args[2..];
        string? level = null, root = null;
        if (rest.Length is 1 or 3 && LocalBot.LogLevels.Contains(rest[0])) { level = rest[0]; rest = rest[1..]; }
        if (rest.Length == 2 && rest[0] == "--root") { root = LocalDreamDaemon.RequirePath(rest[1]); rest = []; }
        if (rest.Length != 0) throw new ArgumentException(LogLevelUsage);
        return (level, root);
    }

    public static int LogLevel(HostBot bot, string? level, TextWriter output) {
        if (level == null) { output.WriteLine("Civilizationbot log level: " + LocalBot.ReadLogLevel(bot.Profile) + "."); return 0; }
        LocalBot.WriteLogLevel(bot.Profile, level);
        output.WriteLine($"Civilizationbot log level set to {level}; it is used from the bot's next start (--bot restart).");
        return 0;
    }

    public static HostBot Load(string root) {
        var host = LocalHosting.Load(root) ?? throw new IOException("No host.json in " + root + "; configure local hosting first.");
        return host.Bot ?? throw new IOException("host.json has no \"bot\" section.");
    }

    public static async Task<int> Run(string action, HostBot bot, TextWriter output, Hooks hooks) {
        switch (action) {
            case "status": {
                var status = Status(bot, hooks);
                if (!status.Ok) { output.WriteLine("Status failed: " + status.Error); return 1; }
                output.WriteLine(Describe(status));
                return 0;
            }
            case "check-update": {
                var (exit, text) = hooks.Run(LocalBot.Control(bot, "check-update"));
                var check = UpdateCheck.Parse("bot", exit, text);
                output.WriteLine(check.Describe());
                return check.Ok ? 0 : 1;
            }
            case "update": {
                var (exit, text) = hooks.Run(LocalBot.Control(bot, "update"));
                if (exit != 0) { output.WriteLine("Update refused: " + LocalBot.FailureText(exit, text)); return 1; }
                output.WriteLine("Civilizationbot updated.");
                return 0;
            }
            case "repair": {
                // Repair and update: git puts the checkout back on a clean, current main, keeping local work aside.
                var status = Status(bot, hooks);
                if (status.Ok && status.Running) { output.WriteLine("Stop Civilizationbot before repairing its source."); return 1; }
                var result = BotRepair.Run(bot, hooks.Run, DateTime.UtcNow);
                output.WriteLine(result.Summary);
                return result.Ok ? 0 : 1;
            }
            case "stop": return await Stop(bot, output, hooks) ? 0 : 1;
            case "start": return await Start(bot, output, hooks) ? 0 : 1;
            case "restart": return await Stop(bot, output, hooks) && await Start(bot, output, hooks) ? 0 : 1;
            default: throw new ArgumentException("Unsupported bot action.", nameof(action));
        }
    }

    private static async Task<bool> Stop(HostBot bot, TextWriter output, Hooks hooks) {
        var status = Status(bot, hooks);
        if (!status.Ok) { output.WriteLine("Status failed: " + status.Error); return false; }
        if (!status.Running) { output.WriteLine("Civilizationbot is not running."); return true; }
        var (exit, text) = hooks.Run(LocalBot.Control(bot, "stop"));
        if (exit != 0) { output.WriteLine("Stop refused: " + LocalBot.FailureText(exit, text)); return false; }
        output.WriteLine("Asked Civilizationbot to stop; waiting for it to save and close...");
        for (var waited = TimeSpan.Zero; waited < StopWait; waited += Poll) {
            await hooks.Delay(Poll);
            status = Status(bot, hooks);
            if (status.Ok && !status.Running) { output.WriteLine("Civilizationbot stopped."); return true; }
        }
        output.WriteLine($"Civilizationbot did not stop within {StopWait.TotalSeconds:0} s; use the launcher window's Force stop.");
        return false;
    }

    private static async Task<bool> Start(HostBot bot, TextWriter output, Hooks hooks) {
        var status = Status(bot, hooks);
        if (!status.Ok) { output.WriteLine("Status failed: " + status.Error); return false; }
        if (status.Running) { output.WriteLine("Civilizationbot is already running."); return true; }
        int exit;
        string text;
        try { (exit, text) = hooks.Run(DetachedStart(bot)); }
        catch (Exception e) when (e is IOException or global::System.ComponentModel.Win32Exception or InvalidOperationException) { (exit, text) = (1, e.Message); }
        if (exit != 0 || !text.Contains("CREATED")) {
            // WMI broken or hung (2026-11-19): start the supervisor directly rather than not at all.
            if (hooks.StartDirect is not { } direct) { output.WriteLine("Could not start Civilizationbot: " + LocalBot.FailureText(exit, text)); return false; }
            try {
                var pid = direct(bot);
                output.WriteLine($"Windows' process service (WMI) did not start Civilizationbot ({LocalBot.FailureText(exit, text).Trim()}); started it directly as process {pid}.");
            } catch (Exception e) when (e is IOException or global::System.ComponentModel.Win32Exception or InvalidOperationException or PlatformNotSupportedException) {
                output.WriteLine("Could not start Civilizationbot: " + LocalBot.FailureText(exit, text) + "; a direct start failed too: " + e.Message);
                return false;
            }
        }
        for (var waited = TimeSpan.Zero; waited < StartWait; waited += Poll) {
            await hooks.Delay(Poll);
            status = Status(bot, hooks);
            if (status.Ok && status.Running) {
                output.WriteLine("Civilizationbot started." + (status.StdoutLog is { } log ? " Log: " + log : ""));
                return true;
            }
        }
        output.WriteLine($"Civilizationbot did not report running within {StartWait.TotalSeconds:0} s." +
            (status.StderrLog is { } errors ? " Check " + errors : ""));
        return false;
    }

    private static BotStatus Status(HostBot bot, Hooks hooks) {
        var (exit, text) = hooks.Run(LocalBot.Control(bot, "status"));
        return LocalBot.ParseStatus(exit, text);
    }

    public static string Describe(BotStatus status) =>
        (status.Running ? "Civilizationbot is running." : "Civilizationbot is stopped.") +
        (status.StopPending ? " A stop is pending." : "") +
        (status.StdoutLog is { } log ? " Log: " + log : "");

    // A hidden PowerShell asks Windows to create "php control.php start PROFILE" in the bot folder and
    // prints CREATED with the new process id. The paths travel as environment variables, never as script text.
    public static ProcessStartInfo DetachedStart(HostBot bot) {
        var step = new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, "WindowsPowerShell", "v1.0", "powershell.exe")) {
            UseShellExecute = false, CreateNoWindow = true, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "-NoProfile", "-NonInteractive", "-Command", DetachScript }) step.ArgumentList.Add(argument);
        step.Environment["CIV13_BOT_COMMAND"] = CommandLine(bot);
        step.Environment["CIV13_BOT_ROOT"] = bot.Root;
        return step.WithLimit(DetachLimit);
    }

    public const string DetachScript =
        "$r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $env:CIV13_BOT_COMMAND; CurrentDirectory = $env:CIV13_BOT_ROOT }; " +
        "if ($r.ReturnValue -eq 0) { 'CREATED ' + $r.ProcessId } else { 'Portable control failed: Win32_Process.Create returned ' + $r.ReturnValue; exit 1 }";

    // Windows paths cannot contain quotes, so quoting each argument is enough; anything else is refused.
    public static string CommandLine(HostBot bot) {
        string Quote(string value) => value.Contains('"') ? throw new InvalidDataException("Bot paths cannot contain quotes.") : "\"" + value + "\"";
        return string.Join(" ", Quote(bot.Php), Quote("scripts/windows/control.php"), "start", Quote(bot.Profile));
    }
}
