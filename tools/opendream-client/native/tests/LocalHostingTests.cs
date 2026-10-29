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

        Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, @public = true, bot = new { php, root = bot, profile } });
        var host = LocalHosting.Load(launcher) ?? throw new Exception("valid host.json not loaded");
        Require(host.Port == 1714 && host.Public && host.World == "civ13.dmb" && host.Bot is { HttpPort: 25565 }, "valid profile fields not read");

        var started = new List<ProcessStartInfo>();
        var lines = LocalHosting.Run(host, @"C:\BYOND\bin", _ => false, started.Add);
        Require(started.Count == 2 && lines.Count == 2, "cold start did not start both server and bot supervisor");
        var daemon = started[0];
        Require(daemon.FileName == Path.Combine(@"C:\BYOND\bin", "dd.exe") && daemon.WorkingDirectory == host.GameDirectory && !daemon.UseShellExecute,
            "DreamDaemon start used the wrong executable, folder or shell");
        Require(daemon.ArgumentList.SequenceEqual(new[] { "civ13.dmb", "1714", "-trusted", "-public", "-log", "logs/world.log" }),
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
        Require(host.Bot is null && !host.Public && started.Count == 1 && started[0].ArgumentList.Contains("-invisible"), "server-only profile changed");

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
        Reject(() => { Write(new { schema = 2, game_directory = game, world = "civ13.dmb", port = 1714 }); LocalHosting.Load(launcher); }, "future schema");
        Reject(() => { Write(new { schema = 1, game_directory = "relative", world = "civ13.dmb", port = 1714 }); LocalHosting.Load(launcher); }, "relative game folder");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = @"..\civ13.dmb", port = 1714 }); LocalHosting.Load(launcher); }, "world outside the game folder");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "missing.dmb", port = 1714 }); LocalHosting.Load(launcher); }, "missing world");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 70000 }); LocalHosting.Load(launcher); }, "invalid port");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, bot = new { php, root = game, profile } }); LocalHosting.Load(launcher); }, "bot root without control.php");
        File.WriteAllText(profile, "{}");
        Reject(() => { Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, bot = new { php, root = bot, profile } }); LocalHosting.Load(launcher); }, "bot profile without http_port");
        Console.WriteLine($"PASS local hosting: {assertions} assertions; opt-in host.json, menu visibility, DreamDaemon/bot supervisor starts only when absent, strict profile validation, fast-forward update and 0-warning rebuild before start.");
        return assertions;
    }
}
