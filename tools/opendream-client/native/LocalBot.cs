using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Civ13.Launcher;

// The configured Civilizationbot (host.json "bot") driven through its own scripts/windows/control.php.
// status and check-update are read-only JSON commands; start runs the foreground supervisor, which the
// launcher window owns so the bot stops when the launcher closes.
public sealed record BotStatus(bool Ok, bool Running, bool StopPending, string? StdoutLog, string? StderrLog, string? Error);

// One component's answer to check-update: the server (gaia_host.py) and the bot (control.php) share this shape.
public sealed record UpdateCheck(bool Ok, string Component, string Current, string Available, int Behind, bool CanUpdate, string? Reason, string? Error) {
    public bool HasUpdate => Ok && Behind > 0;
    // The only thing in the way is a running server: a save, update and restart (deploy) can still run.
    public bool OnlyNeedsStop => HasUpdate && !CanUpdate && Reason is "stop the server before updating" or "stop the region before updating";

    public string Describe(bool withReason = true) {
        if (!Ok) return "Check failed: " + (Error ?? "no answer");
        var at = Short(Current);
        if (Behind <= 0) return $"Up to date ({at}).";
        var line = $"Update available: {Behind} new commit{(Behind == 1 ? "" : "s")} ({at} -> {Short(Available)}).";
        return !withReason || CanUpdate || string.IsNullOrEmpty(Reason) ? line : line + " " + Capital(Reason) + ".";
    }

    private static string Short(string sha) => sha.Length >= 7 ? sha[..7] : (sha.Length > 0 ? sha : "unknown");
    private static string Capital(string text) => text.Length == 0 ? text : char.ToUpperInvariant(text[0]) + text[1..].TrimEnd('.');

    // The last JSON object line wins, so warnings printed before it are ignored.
    public static UpdateCheck Parse(string component, int exit, string output) {
        UpdateCheck Fail(string error) => new(false, component, "", "", 0, false, null, error);
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{'));
        if (line == null) return Fail($"no answer (exit {exit})");
        try {
            using var document = JsonDocument.Parse(line);
            var json = document.RootElement;
            if (json.ValueKind != JsonValueKind.Object || !json.TryGetProperty("ok", out var ok) || ok.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                return Fail($"no answer (exit {exit})");
            if (!ok.GetBoolean()) return Fail(LocalBot.Str(json, "error") ?? LocalBot.Str(json, "refused") ?? "no reason given");
            if (LocalBot.Str(json, "component") is { } named && named != component) return Fail("answer was for " + named);
            var behind = json.TryGetProperty("behind", out var count) && count.ValueKind == JsonValueKind.Number && count.TryGetInt32(out var n) && n >= 0 ? n : 0;
            return new UpdateCheck(true, component, LocalBot.Str(json, "current") ?? "", LocalBot.Str(json, "available") ?? "", behind,
                LocalBot.Bool(json, "can_update"), LocalBot.Str(json, "reason"), null);
        } catch (JsonException) { return Fail($"no answer (exit {exit})"); }
    }
}

public static class LocalBot {
    public static readonly string[] Actions = ["status", "check-update", "start", "stop", "update"];

    // Only the action and the configured profile reach control.php. Every action but start is captured.
    public static ProcessStartInfo Control(HostBot bot, string action) {
        if (!Actions.Contains(action)) throw new ArgumentException("Unsupported bot action.", nameof(action));
        var step = new ProcessStartInfo(bot.Php) { UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = bot.Root,
            RedirectStandardInput = action != "start", RedirectStandardOutput = action != "start", RedirectStandardError = true };
        foreach (var argument in new[] { "scripts/windows/control.php", action, bot.Profile }) step.ArgumentList.Add(argument);
        return step;
    }

    // The bot's log level lives in its portable profile ("log_level"); the bot reads it when it starts and
    // uses info when it is missing or unknown, so a bad value never stops it booting.
    public static readonly string[] LogLevels = ["debug", "info", "notice", "warning", "error"];
    public const string DefaultLogLevel = "info";

    public static string NormalLogLevel(string? value) {
        var name = value?.Trim().ToLowerInvariant();
        return name != null && LogLevels.Contains(name) ? name : DefaultLogLevel;
    }

    // The level the bot will use at its next start. Anything unreadable reads as the default.
    public static string ReadLogLevel(string profile) {
        try {
            if (JsonNode.Parse(File.ReadAllText(profile)) is JsonObject json && json["log_level"] is JsonValue value && value.TryGetValue<string>(out var level))
                return NormalLogLevel(level);
        } catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException or InvalidOperationException) { }
        return DefaultLogLevel;
    }

    // Sets "log_level" and keeps every other profile field. Written UTF-8 without a BOM (PHP's json_decode
    // rejects one) through a temporary file, so a failed write leaves the old profile in place.
    public static void WriteLogLevel(string profile, string level) {
        if (!LogLevels.Contains(level)) throw new ArgumentException("Unknown log level: " + level, nameof(level));
        var text = File.ReadAllText(profile);
        if (JsonNode.Parse(text) is not JsonObject json) throw new InvalidDataException("The bot profile is not a JSON object.");
        json["log_level"] = level;
        var options = new JsonSerializerOptions { WriteIndented = true, Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping };
        var temporary = profile + ".tmp";
        File.WriteAllText(temporary, json.ToJsonString(options) + "\n", new UTF8Encoding(false));
        File.Move(temporary, profile, true);
    }

    public static BotStatus ParseStatus(int exit, string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{'));
        BotStatus Fail(string error) => new(false, false, false, null, null, error);
        if (line == null) return Fail(FailureText(exit, output));
        try {
            using var document = JsonDocument.Parse(line);
            var json = document.RootElement;
            if (json.ValueKind != JsonValueKind.Object || json.TryGetProperty("ok", out var ok) is false || ok.ValueKind != JsonValueKind.True)
                return Fail(json.ValueKind == JsonValueKind.Object ? Str(json, "error") ?? FailureText(exit, output) : FailureText(exit, output));
            return new BotStatus(true, Bool(json, "running"), Bool(json, "stop_pending"), Str(json, "stdout_log"), Str(json, "stderr_log"), null);
        } catch (JsonException) { return Fail(FailureText(exit, output)); }
    }

    // control.php reports failures as "Portable control failed: <reason>" on stderr.
    public static string FailureText(int exit, string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.Length > 0) ?? "";
        const string prefix = "Portable control failed: ";
        if (line.StartsWith(prefix)) return line[prefix.Length..];
        return line.Length > 0 ? line : $"exit {exit}";
    }

    // The last maxBytes of a log the bot is still writing, starting at a whole line.
    public static string Tail(string path, int maxBytes = 64 * 1024) {
        if (!File.Exists(path)) return "";
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        var start = Math.Max(0, stream.Length - maxBytes);
        stream.Seek(start, SeekOrigin.Begin);
        var buffer = new byte[stream.Length - start];
        var read = 0;
        while (read < buffer.Length) {
            var got = stream.Read(buffer, read, buffer.Length - read);
            if (got == 0) break;
            read += got;
        }
        var text = Encoding.UTF8.GetString(buffer, 0, read);
        if (start > 0 && text.IndexOf('\n') is var cut and >= 0) text = text[(cut + 1)..];
        return text.Replace("\r\n", "\n").Replace("\n", Environment.NewLine);
    }

    // Forced stop for a bot that ignores stop.request: every php.exe (from the kernel's process list, never
    // WMI, which hangs when a provider breaks) whose command line is this bot's supervisor or child.
    public static IReadOnlyList<int> FindBotProcesses(HostBot bot) =>
        ProcessSafety.ByName("php").Where(pid => MatchesBot(bot, ProcessSafety.CommandLine(pid))).ToList();

    // The supervisor runs "control.php start PROFILE" and the bot runs "ROOT/bot.php"; nothing else matches.
    public static bool MatchesBot(HostBot bot, string? command) {
        if (string.IsNullOrWhiteSpace(command)) return false;
        static string Norm(string text) => text.Replace('\\', '/').ToLowerInvariant();
        var text = Norm(command);
        return (text.Contains("control.php") && text.Contains(" start ") && text.Contains(Norm(bot.Profile)))
            || text.Contains(Norm(bot.Root).TrimEnd('/') + "/bot.php");
    }

    // What a forced stop may end: PHP only, never whatever else now holds a recorded pid.
    public static readonly string[] BotImages = ["php.exe", "php-cgi.exe", "php-win.exe"];

    internal static string? Str(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
    internal static bool Bool(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True;
}

// The bot supervisor this launcher started. A Windows job object with kill-on-close ties it (and the
// bot.php child it spawns) to the launcher process, so even a crashed launcher does not leave it behind.
// Normal closing asks control.php to stop first; the job is only the backstop.
public sealed class OwnedBot : IDisposable {
    private Process? process;
    private readonly StringBuilder errors = new();
    private IntPtr job;

    public bool Running { get { try { return process is { HasExited: false }; } catch (InvalidOperationException) { return false; } } }
    public int? ExitCode { get { try { return process is { HasExited: true } p ? p.ExitCode : null; } catch (InvalidOperationException) { return null; } } }
    public string Errors { get { lock (errors) return errors.ToString().Trim(); } }

    public void Start(ProcessStartInfo start) {
        if (Running) throw new InvalidOperationException("The launcher's Civilizationbot is already running.");
        process?.Dispose();
        lock (errors) errors.Clear();
        var started = Process.Start(start) ?? throw new IOException("Could not start " + Path.GetFileName(start.FileName) + ".");
        process = started;
        if (start.RedirectStandardError) {
            started.ErrorDataReceived += (_, e) => { if (e.Data != null) lock (errors) errors.AppendLine(e.Data); };
            started.BeginErrorReadLine();
        }
        if (OperatingSystem.IsWindows()) KillWithLauncher(started);
    }

    public async Task<bool> WaitForExit(TimeSpan timeout) {
        if (process == null) return true;
        using var cancel = new CancellationTokenSource(timeout);
        try { await process.WaitForExitAsync(cancel.Token); return true; }
        catch (OperationCanceledException) { return false; }
        catch (InvalidOperationException) { return true; }
    }

    public void Dispose() {
        process?.Dispose();
        process = null;
        // Closing the last job handle ends anything still inside it.
        if (job != IntPtr.Zero) { CloseHandle(job); job = IntPtr.Zero; }
    }

    private void KillWithLauncher(Process started) {
        if (job == IntPtr.Zero) {
            job = CreateJobObject(IntPtr.Zero, null);
            if (job == IntPtr.Zero) return;
            var info = new ExtendedLimitInformation { BasicLimitInformation = new BasicLimitInformation { LimitFlags = KillOnJobClose } };
            var size = Marshal.SizeOf<ExtendedLimitInformation>();
            var pointer = Marshal.AllocHGlobal(size);
            try {
                Marshal.StructureToPtr(info, pointer, false);
                if (!SetInformationJobObject(job, ExtendedLimitInformationClass, pointer, (uint)size)) { CloseHandle(job); job = IntPtr.Zero; return; }
            } finally { Marshal.FreeHGlobal(pointer); }
        }
        try { AssignProcessToJobObject(job, started.Handle); }
        catch (InvalidOperationException) { }
    }

    private const uint KillOnJobClose = 0x2000;
    private const int ExtendedLimitInformationClass = 9;

    [StructLayout(LayoutKind.Sequential)]
    private struct BasicLimitInformation {
        public long PerProcessUserTimeLimit, PerJobUserTimeLimit;
        public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize;
        public uint ActiveProcessLimit;
        public UIntPtr Affinity;
        public uint PriorityClass, SchedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IoCounters { public ulong Reads, Writes, Others, ReadBytes, WriteBytes, OtherBytes; }

    [StructLayout(LayoutKind.Sequential)]
    private struct ExtendedLimitInformation {
        public BasicLimitInformation BasicLimitInformation;
        public IoCounters IoInfo;
        public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr CreateJobObject(IntPtr attributes, string? name);
    [DllImport("kernel32.dll")] private static extern bool SetInformationJobObject(IntPtr job, int infoClass, IntPtr info, uint length);
    [DllImport("kernel32.dll")] private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll")] private static extern bool CloseHandle(IntPtr handle);
}
