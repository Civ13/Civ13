using Civ13.Launcher;
using System.Diagnostics;
using System.Text.Json;

// Process starts and port probes are injected. This suite launches nothing and opens no socket.
static class LocalHostingTests {
    public static int Run(string root) {
        var assertions = 0;
        void Require(bool condition, string message) {
            assertions++;
            if (!condition) throw new Exception("Local hosting contract: " + message);
        }
        void Reject(Action action, string message) {
            try { action(); } catch (InvalidDataException) { assertions++; return; }
            throw new Exception("Local hosting negative control accepted: " + message);
        }
        var dir = Path.Combine(root, "local-hosting");
        var launcher = Path.Combine(dir, "launcher");
        var game = Path.Combine(dir, "game & spaces");
        var bot = Path.Combine(dir, "bot");
        Directory.CreateDirectory(launcher);
        Directory.CreateDirectory(game);
        Directory.CreateDirectory(Path.Combine(bot, "scripts", "windows"));
        File.WriteAllText(Path.Combine(game, "civ13.dmb"), "");
        File.WriteAllText(Path.Combine(bot, "scripts", "windows", "control.php"), "");
        var php = Path.Combine(dir, "php.exe");
        File.WriteAllText(php, "");
        var profile = Path.Combine(dir, "profile.json");
        File.WriteAllText(profile, JsonSerializer.Serialize(new { http_port = 25565 }));
        void Write(object value) => File.WriteAllText(Path.Combine(launcher, LocalHosting.FileName), JsonSerializer.Serialize(value));

        Require(LocalHosting.Load(launcher) is null, "hosting enabled without host.json");
        using (var plain = new StringWriter()) {
            Civ13.Launcher.Program.WriteMainMenu(plain);
            Require(!plain.ToString().Contains(LocalHosting.Menu), "player menu showed the hosting option");
        }
        using (var hosting = new StringWriter()) {
            Civ13.Launcher.Program.WriteMainMenu(hosting, true);
            Require(hosting.ToString().TrimEnd().EndsWith(LocalHosting.Menu), "hosting option missing after the existing options");
        }

        Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, bot = new { php, root = bot, profile } });
        var host = LocalHosting.Load(launcher) ?? throw new Exception("valid host.json not loaded");
        Require(host.Port == 1714 && host.World == "civ13.dmb" && host.Bot is { HttpPort: 25565 }, "valid profile fields not read");

        var started = new List<ProcessStartInfo>();
        var lines = LocalHosting.Run(host, @"C:\BYOND\bin", _ => false, started.Add);
        Require(started.Count == 2 && lines.Count == 2, "cold start did not start both server and bot supervisor");
        var daemon = started[0];
        Require(daemon.FileName == Path.Combine(@"C:\BYOND\bin", "dd.exe") && daemon.WorkingDirectory == host.GameDirectory && !daemon.UseShellExecute,
            "DreamDaemon start used the wrong executable, folder or shell");
        Require(daemon.ArgumentList.SequenceEqual(new[] { "civ13.dmb", "1714", "-trusted", "-public", "-close", "-log", "logs/world.log" }),
            "DreamDaemon arguments changed: " + string.Join(" ", daemon.ArgumentList));
        Require(Directory.Exists(Path.Combine(game, "logs")), "log folder not created before DreamDaemon start");
        var supervisor = started[1];
        Require(supervisor.FileName == php && supervisor.WorkingDirectory == bot &&
            supervisor.ArgumentList.SequenceEqual(new[] { "scripts/windows/control.php", "start", profile }), "bot supervisor start changed");

        started.Clear();
        lines = LocalHosting.Run(host, @"C:\BYOND\bin", port => port == 1714, started.Add);
        Require(started.Count == 1 && started[0].FileName == php && lines[0].Contains("already running"), "running server was restarted or bot not started");
        started.Clear();
        lines = LocalHosting.Run(host, @"C:\BYOND\bin", port => port == 25565, started.Add);
        Require(started.Count == 1 && started[0].FileName.EndsWith("dd.exe") && lines[1].Contains("already running"), "running bot supervisor was started twice");
        started.Clear();
        LocalHosting.Run(host, @"C:\BYOND\bin", _ => true, started.Add);
        Require(started.Count == 0, "started a component that was already running");

        Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1715 });
        host = LocalHosting.Load(launcher)!;
        started.Clear();
        LocalHosting.Run(host, @"C:\BYOND\bin", _ => false, started.Add);
        Require(host.Bot is null && started.Count == 1 && started[0].ArgumentList.Contains("-public") && !started[0].ArgumentList.Contains("-invisible"), "server-only profile changed");

        var git = Path.Combine(dir, "git.exe");
        File.WriteAllText(git, "");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, update = new { git, branch = "master" } }); LocalHosting.Load(launcher); }, "update without the world's .dme");
        File.WriteAllText(Path.Combine(game, "civ13.dme"), "");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, update = new { git, branch = "--upload-pack=x" } }); LocalHosting.Load(launcher); }, "option-shaped branch");
        Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, update = new { git, branch = "master" } });
        host = LocalHosting.Load(launcher)!;
        Require(host.Update is { Branch: "master" } && host.Update.Git == git, "update section not read");
        var ran = new List<ProcessStartInfo>();
        (int, string) Ok(ProcessStartInfo step) { ran.Add(step); return (0, step.FileName.EndsWith("dm.exe") ? "civ13.dmb - 0 errors, 0 warnings" : ""); }
        started.Clear();
        lines = LocalHosting.Run(host, @"C:\BYOND\bin", _ => false, started.Add, Ok);
        Require(ran.Count == 3 && ran.All(step => step.WorkingDirectory == host.GameDirectory && step.RedirectStandardOutput && !step.UseShellExecute), "update steps not run in the game folder");
        Require(ran[0].FileName == git && ran[0].ArgumentList.SequenceEqual(new[] { "fetch", "origin", "master" }), "fetch step changed");
        Require(ran[1].ArgumentList.SequenceEqual(new[] { "merge", "--ff-only", "FETCH_HEAD" }), "update is not fast-forward only");
        Require(ran[2].FileName == Path.Combine(@"C:\BYOND\bin", "dm.exe") && ran[2].ArgumentList.SequenceEqual(new[] { "-max_errors", "0", "civ13.dme" }), "compile step changed");
        Require(started.Count == 1 && lines[0].StartsWith("Updated to origin/master"), "server not started after a successful update");
        foreach (var (failAt, output, label) in new[] { (1, "fatal: Not possible to fast-forward", "diverged merge"), (2, "civ13.dmb - 0 errors, 3 warnings", "compile warnings") }) {
            ran.Clear(); started.Clear();
            lines = LocalHosting.Run(host, @"C:\BYOND\bin", _ => false, started.Add, step => {
                ran.Add(step);
                return ran.Count - 1 == failAt ? (failAt == 2 ? 0 : 1, output) : (0, step.FileName.EndsWith("dm.exe") ? "0 errors, 0 warnings" : "");
            });
            Require(started.Count == 0 && ran.Count == failAt + 1 && lines[0].Contains("DreamDaemon was not started"), "started DreamDaemon after " + label);
        }
        ran.Clear(); started.Clear();
        LocalHosting.Run(host, @"C:\BYOND\bin", port => port == 1714, started.Add, Ok);
        Require(ran.Count == 0 && started.Count == 0, "updated or restarted a running world");
        // control: the shared gaia_host.py path replaces the direct start and update.
        var python = Path.Combine(dir, "python.exe");
        var script = Path.Combine(dir, "gaia_host.py");
        var controlConfig = Path.Combine(dir, "gaia-host.json");
        foreach (var file in new[] { python, script, controlConfig }) File.WriteAllText(file, "");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, update = new { git, branch = "master" }, control = new { python, script, config = controlConfig } }); LocalHosting.Load(launcher); }, "control and update together");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, control = new { python = "python", script, config = controlConfig } }); LocalHosting.Load(launcher); }, "relative control python");
        Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, control = new { python, script, config = controlConfig } });
        host = LocalHosting.Load(launcher)!;
        Require(host.Control is { } loaded && loaded.Python == python && loaded.Script == script && loaded.Config == controlConfig && host.Update is null, "control section not read");
        var controlStep = LocalHosting.ControlStep(host.Control!, "stop");
        Require(controlStep.FileName == python && !controlStep.UseShellExecute && controlStep.RedirectStandardOutput &&
            controlStep.ArgumentList.SequenceEqual(new[] { "-I", "-B", script, "--config", controlConfig, "stop" }), "control argv changed: " + string.Join(" ", controlStep.ArgumentList));
        try { LocalHosting.ControlStep(host.Control!, "mapswap"); throw new Exception("unsupported control action accepted"); } catch (ArgumentException) { assertions++; }
        ran.Clear(); started.Clear();
        lines = LocalHosting.Run(host, @"C:\BYOND\bin", _ => false, started.Add, s => { ran.Add(s); return (0, "{\"ok\": true, \"accepted\": true, \"action\": \"start\", \"operation\": \"x\"}"); });
        Require(started.Count == 0 && ran.Count == 1 && ran[0].ArgumentList.Last() == "start" && lines[0] == "Starting the server...", "control start did not go through the script");
        ran.Clear();
        lines = LocalHosting.Run(host, @"C:\BYOND\bin", _ => false, started.Add, s => { ran.Add(s); return (1, "{\"ok\": false, \"refused\": \"level 2 of the save is missing\"}"); });
        Require(started.Count == 0 && lines.Single() == "Refused: level 2 of the save is missing", "a refused start was not reported");
        var status = LocalHosting.ParseControl("status", 0, "{\"ok\": true, \"listening\": true, \"busy\": true, \"world\": {\"ready\": false, \"clients\": 4, \"error\": null}, \"operation\": {\"action\": \"restart\", \"phase\": \"saving\", \"error\": null}}");
        Require(status.Ok && status.Busy && status.Message == "Server port is open. World not ready. 4 players. Last action: restart (saving).", "status line: " + status.Message);
        status = LocalHosting.ParseControl("status", 0, "{\"ok\": true, \"listening\": false, \"busy\": false, \"operation\": {\"action\": \"update\", \"phase\": \"failed\", \"error\": \"compile failed\"}}");
        Require(!status.Busy && status.Message == "Server is not running. Last action: update (failed): compile failed.", "failure line: " + status.Message);
        status = LocalHosting.ParseControl("status", 0, "{\"ok\": true, \"listening\": true, \"state\": \"awake\", \"busy\": false, \"world\": {\"ready\": true, \"clients\": 2}, \"regions\": [{\"id\": \"gaia\", \"name\": \"Gaia\", \"state\": \"awake\", \"players\": 2}, {\"id\": \"deep\", \"name\": \"The Deep\", \"state\": \"asleep\", \"players\": null}, 7]}");
        Require(status.Message == "Server port is open. World ready. 2 players.\nRegions: Gaia: awake, 2 players; The Deep: asleep.", "region line: " + status.Message);
        status = LocalHosting.ParseControl("status", 0, "{\"ok\": true, \"listening\": false, \"state\": \"cold\", \"busy\": false}");
        Require(status.Message.StartsWith("Server is asleep (stopped"), "cold line: " + status.Message);
        Require(!LocalHosting.ParseControl("stop", 0, "{\"ok\": true, \"accepted\": true, \"action\": \"start\"}").Ok, "acceptance for another action counted");
        Require(LocalHosting.ParseControl("update", 1, "Traceback (most recent call last)") is { Ok: false, Busy: false } garbage && garbage.Message.Contains("no answer"), "garbage output accepted");
        Require(LocalHosting.ParseControl("restart", 0, "warning: x\n{\"ok\": true, \"accepted\": true, \"action\": \"restart\"}") is { Ok: true, Busy: true }, "answer after a warning line not found");

        Reject(() => { Write(new { schema = 2, game_directory = game, world = "civ13.dmb", port = 1714 }); LocalHosting.Load(launcher); }, "future schema");
        Reject(() => { Write(new { schema = 1, game_directory = "relative", world = "civ13.dmb", port = 1714 }); LocalHosting.Load(launcher); }, "relative game folder");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = @"..\civ13.dmb", port = 1714 }); LocalHosting.Load(launcher); }, "world outside the game folder");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "missing.dmb", port = 1714 }); LocalHosting.Load(launcher); }, "missing world");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 70000 }); LocalHosting.Load(launcher); }, "invalid port");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, bot = new { php, root = game, profile } }); LocalHosting.Load(launcher); }, "bot root without control.php");
        File.WriteAllText(profile, "{}");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, bot = new { php, root = bot, profile } }); LocalHosting.Load(launcher); }, "bot profile without http_port");
        Console.WriteLine($"PASS local hosting: {assertions} assertions; opt-in host.json, menu visibility, DreamDaemon/bot supervisor starts only when absent, strict profile validation, fast-forward update and 0-warning rebuild before start, shared control script.");
        return assertions;
    }
}
