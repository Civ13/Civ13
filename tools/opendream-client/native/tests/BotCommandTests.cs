using System.Diagnostics;
using Civ13.Launcher;

// Civ13.exe --bot: argument parsing, the detached start command and each action's control.php
// sequence, driven by a scripted fake. This suite launches nothing.
static class BotCommandTests {
    public static async Task<int> Run(string root) {
        var assertions = 0;
        void Require(bool condition, string message) {
            assertions++;
            if (!condition) throw new Exception("Bot command contract: " + message);
        }
        var dir = Path.Combine(root, "bot-command");
        Directory.CreateDirectory(dir);
        var bot = new HostBot(Path.Combine(dir, "php.exe"), Path.Combine(dir, "bot & spaces"), Path.Combine(dir, "profile.json"), 25565);

        Require(BotCommand.Parse(["--bot", "start"]) == ("start", null), "plain start");
        Require(BotCommand.Parse(["--bot", "restart", "--root", dir]) == ("restart", dir), "explicit root");
        foreach (var bad in new[] { new[] { "--bot" }, ["--bot", "reload"], ["--bot", "start", "--root"], ["--bot", "start", "--console"], ["--bot", "start", "--root", "relative"] }) {
            try { BotCommand.Parse(bad); throw new Exception("accepted " + string.Join(" ", bad)); } catch (Exception e) when (e is ArgumentException or IOException) { assertions++; }
        }

        var detach = BotCommand.DetachedStart(bot);
        Require(!detach.UseShellExecute && detach.CreateNoWindow && detach.RedirectStandardOutput && detach.ArgumentList.Last() == BotCommand.DetachScript, "detached start shape");
        Require(detach.Environment["CIV13_BOT_COMMAND"] == $"\"{bot.Php}\" \"scripts/windows/control.php\" start \"{bot.Profile}\"" &&
            detach.Environment["CIV13_BOT_ROOT"] == bot.Root, "detached command line: " + detach.Environment["CIV13_BOT_COMMAND"]);
        Require(!BotCommand.DetachScript.Contains(bot.Php) && BotCommand.DetachScript.Contains("$env:CIV13_BOT_COMMAND"), "paths reach the script only through the environment");
        try { BotCommand.CommandLine(bot with { Profile = "D:/a\"b.json" }); throw new Exception("quoted path accepted"); } catch (InvalidDataException) { assertions++; }

        const string Running = "{\"ok\":true,\"running\":true,\"stop_pending\":false,\"stdout_log\":\"D:/s/stdout.log\"}";
        const string Stopped = "{\"ok\":true,\"running\":false,\"stop_pending\":false}";
        async Task<(int Exit, List<string> Calls, string Output)> Script(string action, params (int, string)[] answers) {
            var calls = new List<string>();
            var queue = new Queue<(int, string)>(answers);
            var hooks = new BotCommand.Hooks(step => {
                calls.Add(step.ArgumentList.Contains("-Command") ? "detach" : step.ArgumentList[1]);
                return queue.Count > 0 ? queue.Dequeue() : (0, Stopped);
            }, _ => Task.CompletedTask);
            var output = new StringWriter();
            var exit = await BotCommand.Run(action, bot, output, hooks);
            return (exit, calls, output.ToString());
        }

        var r = await Script("start", (0, Stopped), (0, "CREATED 42"), (0, Stopped), (0, Running));
        Require(r.Exit == 0 && r.Calls.SequenceEqual(["status", "detach", "status", "status"]) && r.Output.Contains("started"), "start: " + r.Output);
        r = await Script("start", (0, Running));
        Require(r.Exit == 0 && r.Calls.SequenceEqual(["status"]) && r.Output.Contains("already running"), "start while running: " + r.Output);
        r = await Script("start", (0, Stopped), (1, "Portable control failed: Win32_Process.Create returned 9"));
        Require(r.Exit == 1 && r.Output.Contains("returned 9"), "failed create: " + r.Output);
        r = await Script("start", [(0, Stopped), (0, "CREATED 42"), .. Enumerable.Repeat((0, Stopped), 40)]);
        Require(r.Exit == 1 && r.Output.Contains("did not report running"), "start never running: " + r.Output);

        r = await Script("stop", (0, Running), (0, "{\"ok\":true}"), (0, Running), (0, Stopped));
        Require(r.Exit == 0 && r.Calls.SequenceEqual(["status", "stop", "status", "status"]) && r.Output.Contains("stopped."), "stop: " + r.Output);
        r = await Script("stop", (0, Stopped));
        Require(r.Exit == 0 && r.Calls.SequenceEqual(["status"]), "stop while stopped");
        r = await Script("stop", (0, Running), (1, "Portable control failed: Profile unreadable"));
        Require(r.Exit == 1 && r.Output.Contains("Stop refused: Profile unreadable"), "stop refused: " + r.Output);

        r = await Script("restart", (0, Running), (0, "{\"ok\":true}"), (0, Stopped), (0, Stopped), (0, "CREATED 7"), (0, Running));
        Require(r.Exit == 0 && r.Calls.SequenceEqual(["status", "stop", "status", "status", "detach", "status"]), "restart: " + string.Join(",", r.Calls));
        r = await Script("restart", [(0, Running), (0, "{\"ok\":true}"), .. Enumerable.Repeat((0, Running), 60)]);
        Require(r.Exit == 1 && !r.Calls.Contains("detach"), "restart must not start a bot that did not stop");

        r = await Script("status", (0, Running));
        Require(r.Exit == 0 && r.Output.StartsWith("Civilizationbot is running."), "status: " + r.Output);
        r = await Script("check-update", (0, "{\"ok\":true,\"component\":\"bot\",\"current\":\"1111111a\",\"available\":\"1111111a\",\"behind\":0,\"can_update\":false}"));
        Require(r.Exit == 0 && r.Output.StartsWith("Up to date (1111111)."), "check-update: " + r.Output);
        r = await Script("update", (1, "Portable control failed: stop the bot before updating"));
        Require(r.Exit == 1 && r.Output.Contains("stop the bot before updating"), "update refused: " + r.Output);
        return assertions;
    }
}
