using Civ13.Launcher;

// control.php commands and their JSON answers, the shared check-update parser and the log tail.
// Process starts are not run; this suite launches nothing.
static class LocalBotTests {
    public static int Run(string root) {
        var assertions = 0;
        void Require(bool condition, string message) {
            assertions++;
            if (!condition) throw new Exception("Local bot contract: " + message);
        }
        var dir = Path.Combine(root, "local-bot");
        Directory.CreateDirectory(dir);
        var bot = new HostBot(Path.Combine(dir, "php.exe"), Path.Combine(dir, "bot & spaces"), Path.Combine(dir, "profile.json"), 25565);

        foreach (var action in LocalBot.Actions) {
            var step = LocalBot.Control(bot, action);
            Require(step.FileName == bot.Php && step.WorkingDirectory == bot.Root && !step.UseShellExecute && step.CreateNoWindow &&
                step.ArgumentList.SequenceEqual(new[] { "scripts/windows/control.php", action, bot.Profile }), action + " argv changed");
            Require(step.RedirectStandardError && step.RedirectStandardOutput == (action != "start") && step.RedirectStandardInput == (action != "start"), action + " capture changed");
        }
        try { LocalBot.Control(bot, "reloadconfig"); throw new Exception("unsupported bot action accepted"); } catch (ArgumentException) { assertions++; }
        Require(LocalHosting.ControlActions.Contains("check-update"), "server check-update action missing");

        var status = LocalBot.ParseStatus(0, "{\"ok\":true,\"running\":true,\"stop_pending\":false,\"reload_pending\":false,\"state_dir\":\"D:/s\",\"stdout_log\":\"D:/s/stdout.log\",\"stderr_log\":\"D:/s/stderr.log\"}\n");
        Require(status is { Ok: true, Running: true, StopPending: false, StdoutLog: "D:/s/stdout.log", StderrLog: "D:/s/stderr.log" }, "status not read");
        status = LocalBot.ParseStatus(0, "{\"ok\":true,\"running\":false,\"stop_pending\":true}");
        Require(status is { Ok: true, Running: false, StopPending: true, StdoutLog: null }, "pending stop not read");
        status = LocalBot.ParseStatus(1, "Portable control failed: Usage: php control.php check|start|stop|update ABSOLUTE_PROFILE\n");
        Require(!status.Ok && status.Error!.StartsWith("Usage:"), "old bot without status not reported: " + status.Error);
        status = LocalBot.ParseStatus(1, "{\"ok\":false,\"error\":\"Profile unreadable\"}\nPortable control failed: Profile unreadable");
        Require(!status.Ok && status.Error == "Profile unreadable", "status failure not read");
        Require(LocalBot.FailureText(1, "") == "exit 1", "empty failure text");

        var check = UpdateCheck.Parse("bot", 0, "warning\n{\"ok\":true,\"component\":\"bot\",\"current\":\"1111111aaaa\",\"available\":\"2222222bbbb\",\"behind\":3,\"can_update\":true,\"reason\":\"\",\"fresh\":true,\"running\":true}");
        Require(check is { Ok: true, HasUpdate: true, CanUpdate: true, Behind: 3 } && check.Describe() == "Update available: 3 new commits (1111111 -> 2222222).", "bot update: " + check.Describe());
        check = UpdateCheck.Parse("bot", 0, "{\"ok\":true,\"component\":\"bot\",\"current\":\"1111111aaaa\",\"available\":\"2222222bbbb\",\"behind\":1,\"can_update\":false,\"reason\":\"local edits retained (update needs a clean checkout): M composer.lock\"}");
        Require(check is { HasUpdate: true, CanUpdate: false } && check.Describe().EndsWith("Local edits retained (update needs a clean checkout): M composer.lock."), "blocked bot update: " + check.Describe());
        check = UpdateCheck.Parse("server", 0, "{\"ok\": true, \"component\": \"server\", \"current\": \"abcdef0123\", \"available\": \"abcdef0123\", \"behind\": 0, \"can_update\": false, \"reason\": \"up to date\"}");
        Require(check is { Ok: true, HasUpdate: false } && check.Describe() == "Up to date (abcdef0).", "server up to date: " + check.Describe());
        check = UpdateCheck.Parse("server", 0, "{\"ok\": true, \"component\": \"server\", \"current\": \"abcdef0123\", \"available\": \"9876543210\", \"behind\": 1, \"can_update\": false, \"reason\": \"stop the server before updating\"}");
        Require(check is { HasUpdate: true, CanUpdate: false } && check.Describe() == "Update available: 1 new commit (abcdef0 -> 9876543). Stop the server before updating.", "running server: " + check.Describe());
        // A group's save, update and restart stops the worlds itself, so only this reason may be passed over.
        Require(check.OnlyNeedsStop && check.Describe(withReason: false) == "Update available: 1 new commit (abcdef0 -> 9876543).", "running server deploy: " + check.Describe(false));
        Require(!UpdateCheck.Parse("server", 0, "{\"ok\": true, \"component\": \"server\", \"current\": \"a\", \"available\": \"b\", \"behind\": 2, \"can_update\": false, \"reason\": \"another action is still running; stop the server before updating\"}").OnlyNeedsStop,
            "a busy group counted as only running");
        Require(!UpdateCheck.Parse("server", 0, "{\"ok\": true, \"component\": \"server\", \"current\": \"a\", \"available\": \"a\", \"behind\": 0, \"can_update\": false, \"reason\": \"up to date\"}").OnlyNeedsStop,
            "an up-to-date server offered a deploy");
        check = UpdateCheck.Parse("server", 0, "{\"ok\": true, \"component\": \"server\", \"current\": \"a\", \"available\": \"b\", \"behind\": 2, \"can_update\": true, \"reason\": null}");
        Require(check is { HasUpdate: true, CanUpdate: true, Reason: null }, "server null reason");
        check = UpdateCheck.Parse("server", 1, "{\"ok\": false, \"component\": \"server\", \"error\": \"git fetch failed\"}");
        Require(!check.Ok && !check.HasUpdate && check.Describe() == "Check failed: git fetch failed", "failed check: " + check.Describe());
        Require(!UpdateCheck.Parse("server", 0, "{\"ok\":true,\"component\":\"bot\",\"behind\":5}").Ok, "another component's answer accepted");
        Require(!UpdateCheck.Parse("bot", 2, "Traceback").Ok, "garbage accepted");
        Require(UpdateCheck.Parse("bot", 0, "{\"ok\":true,\"component\":\"bot\",\"behind\":-4}").Behind == 0, "negative behind accepted");

        var log = Path.Combine(dir, "stdout.log");
        File.WriteAllText(log, "");
        Require(LocalBot.Tail(Path.Combine(dir, "missing.log")) == "" && LocalBot.Tail(log) == "", "empty or missing log");
        using (var writer = new FileStream(log, FileMode.Append, FileAccess.Write, FileShare.ReadWrite)) {
            var bytes = System.Text.Encoding.UTF8.GetBytes(string.Concat(Enumerable.Range(0, 200).Select(i => $"line {i}\n")));
            writer.Write(bytes);
            writer.Flush();
            // The bot keeps its log open for writing; the tail must still read it.
            var tail = LocalBot.Tail(log, 100);
            var lines = tail.Split(Environment.NewLine, StringSplitOptions.RemoveEmptyEntries);
            Require(lines.Length > 0 && lines.All(line => line.StartsWith("line ")) && lines[^1] == "line 199", "tail did not start on a whole line: " + tail);
            Require(LocalBot.Tail(log).Split(Environment.NewLine, StringSplitOptions.RemoveEmptyEntries).Length == 200, "short log not read whole");
        }
        // Forced stop finds only this bot's supervisor and bot.php, by command line, whatever the slashes or case.
        var listing = "[" +
            "{\"ProcessId\":11,\"CommandLine\":\"\\\"C:\\\\php\\\\php.exe\\\" scripts/windows/control.php start " + bot.Profile.Replace("\\", "/").Replace("\"", "") + "\"}," +
            "{\"ProcessId\":12,\"CommandLine\":\"\\\"C:\\\\php\\\\php.exe\\\" \\\"" + Path.Combine(bot.Root, "BOT.php").Replace("\\", "/") + "\\\"\"}," +
            "{\"ProcessId\":13,\"CommandLine\":\"php.exe scripts/windows/control.php start D:/other/profile.json\"}," +
            "{\"ProcessId\":14,\"CommandLine\":\"php.exe scripts/windows/control.php status " + bot.Profile.Replace("\\", "/") + "\"}," +
            "{\"ProcessId\":15,\"CommandLine\":null},{\"ProcessId\":0,\"CommandLine\":\"x/bot.php\"}]";
        Require(LocalBot.ParseBotProcesses(bot, listing).SequenceEqual(new[] { 11, 12 }), "bot processes: " + string.Join(",", LocalBot.ParseBotProcesses(bot, listing)));
        Require(LocalBot.ParseBotProcesses(bot, "{\"ProcessId\":7,\"CommandLine\":\"php " + Path.Combine(bot.Root, "bot.php").Replace("\\", "\\\\") + "\"}").SequenceEqual(new[] { 7 }), "single process object");
        Require(LocalBot.ParseBotProcesses(bot, "").Count == 0 && LocalBot.ParseBotProcesses(bot, "garbage").Count == 0, "empty listing");
        var kill = LocalBot.KillTree(11);
        Require(kill.FileName.EndsWith("taskkill.exe", StringComparison.OrdinalIgnoreCase) && kill.CreateNoWindow && kill.ArgumentList.SequenceEqual(new[] { "/F", "/T", "/PID", "11" }), "kill argv");
        Require(LocalBot.ListPhpProcesses() is { CreateNoWindow: true, RedirectStandardOutput: true } list && list.ArgumentList.Last().Contains("Name='php.exe'"), "process listing");
        Console.WriteLine($"PASS local bot: {assertions} assertions; control.php argv per action, status/check-update parsing for old and new bots, shared server/bot update check, open-log tail.");
        return assertions;
    }
}
