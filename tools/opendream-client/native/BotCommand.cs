using System.Diagnostics;

namespace Civ13.Launcher;

// Civ13.exe --bot ACTION [--root FOLDER]: the Civilizationbot tab's buttons without the window, so a
// script (or a remote helper) can manage the configured bot. Every action goes through the bot's own
// scripts/windows/control.php with only the action and host.json's profile on the command line.
// Unlike the window, start leaves the bot running after this command exits: the supervisor is created
// by Windows (CIM Win32_Process.Create), outside this process and any job object its caller holds.
public static class BotCommand {
    public const string Option = "--bot";
    public static readonly string[] Actions = ["status", "check-update", "start", "stop", "restart", "update"];
    public static readonly TimeSpan StopWait = TimeSpan.FromSeconds(90);
    public static readonly TimeSpan StartWait = TimeSpan.FromSeconds(30);
    private static readonly TimeSpan Poll = TimeSpan.FromSeconds(2);

    public sealed record Hooks(Func<ProcessStartInfo, (int Exit, string Output)> Run, Func<TimeSpan, Task> Delay);

    public static Hooks System { get; } = new(LocalHosting.RunCaptured, Task.Delay);

    // Returns the action and an explicit --root, or throws for anything else on the command line.
    public static (string Action, string? Root) Parse(string[] args) {
        if (args.Length < 2 || args[0] != Option || !Actions.Contains(args[1]))
            throw new ArgumentException("Usage: --bot " + string.Join("|", Actions) + " [--root <absolute folder>]");
        if (args.Length == 2) return (args[1], null);
        if (args.Length == 4 && args[2] == "--root") return (args[1], LocalDreamDaemon.RequirePath(args[3]));
        throw new ArgumentException("Usage: --bot " + string.Join("|", Actions) + " [--root <absolute folder>]");
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
        var (exit, text) = hooks.Run(DetachedStart(bot));
        if (exit != 0 || !text.Contains("CREATED")) { output.WriteLine("Could not start Civilizationbot: " + LocalBot.FailureText(exit, text)); return false; }
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
        return step;
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
