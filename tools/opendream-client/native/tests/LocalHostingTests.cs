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
        Require(controlStep.FileName == python && !controlStep.UseShellExecute && controlStep.RedirectStandardOutput && controlStep.RedirectStandardInput &&
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
        status = LocalHosting.ParseControl("status", 0, "{\"ok\": true, \"regions\": [{\"name\": \"\u0915\u0940" + string.Concat(Enumerable.Repeat("\u5317", 70)) + " <@&1>\", \"state\": \"awake\"}]}");
        Require(status.Message.EndsWith("Regions: \u0915\u0940" + string.Concat(Enumerable.Repeat("\u5317", 62)) + ": awake."), "unicode region name: " + status.Message);
        Require(!LocalHosting.ParseControl("stop", 0, "{\"ok\": true, \"accepted\": true, \"action\": \"start\"}").Ok, "acceptance for another action counted");
        Require(LocalHosting.ParseControl("update", 1, "Traceback (most recent call last)") is { Ok: false, Busy: false } garbage && garbage.Message.Contains("no answer"), "garbage output accepted");
        Require(LocalHosting.ParseControl("restart", 0, "warning: x\n{\"ok\": true, \"accepted\": true, \"action\": \"restart\"}") is { Ok: true, Busy: true }, "answer after a warning line not found");

        // control.group: every region through shard_group.py, plus deploy.bat and restart-host.bat, all from control.script's checkout.
        var checkout = Path.Combine(dir, "checkout");
        var hostScript = Path.Combine(checkout, "scripts", "gaia-host", "gaia_host.py");
        var shard = Path.Combine(checkout, "scripts", "shard-group", "shard_group.py");
        var deploy = Path.Combine(checkout, "scripts", "windows", "host", "deploy.bat");
        var restartHost = Path.Combine(checkout, "scripts", "windows", "host", "restart-host.bat");
        var groupConfig = Path.Combine(dir, "earth.json");
        foreach (var file in new[] { hostScript, shard, deploy, restartHost, groupConfig }) {
            Directory.CreateDirectory(Path.GetDirectoryName(file)!);
            File.WriteAllText(file, "");
        }
        Write(new { schema = 1, game_directory = game, world = "civ13.dmb", port = 1714, control = new { python, script = hostScript, config = controlConfig, group = groupConfig } });
        host = LocalHosting.Load(launcher)!;
        Require(host.Control?.Group is { } grouped && grouped.Config == groupConfig && grouped.ShardScript == shard && grouped.Deploy == deploy && grouped.RestartHost == restartHost,
            "control.group not read");
        var groupStep = LocalHosting.GroupStep(host.Control!, "stop");
        Require(groupStep.FileName == python && groupStep.CreateNoWindow && !groupStep.UseShellExecute && groupStep.RedirectStandardInput &&
            groupStep.ArgumentList.SequenceEqual(new[] { "-I", "-B", shard, "--config", groupConfig, "stop" }), "group argv changed: " + string.Join(" ", groupStep.ArgumentList));
        try { LocalHosting.GroupStep(host.Control!, "setup"); throw new Exception("unsupported group action accepted"); } catch (ArgumentException) { assertions++; }
        var deployStep = LocalHosting.GroupScriptStep(host.Control!, "deploy");
        Require(deployStep.FileName.EndsWith("cmd.exe", StringComparison.OrdinalIgnoreCase) && deployStep.CreateNoWindow && deployStep.RedirectStandardOutput && deployStep.RedirectStandardInput &&
            deployStep.ArgumentList.SequenceEqual(new[] { "/d", "/c", deploy }), "deploy step changed");
        Require(LocalHosting.GroupScriptStep(host.Control!, "restart-host").ArgumentList.Last() == restartHost, "restart-host step changed");
        Require(LocalHosting.GroupScriptStep(host.Control!, "deploy", resume: true).ArgumentList.SequenceEqual(new[] { "/d", "/c", deploy, "continue" }), "deploy continue step changed");
        try { LocalHosting.GroupScriptStep(host.Control!, "restart-host", resume: true); throw new Exception("restart-host continue accepted"); } catch (ArgumentException) { assertions++; }
        Require(LocalHosting.GroupScriptStep(host.Control!, "deploy", true, ["gaia", "mars"]).ArgumentList.SequenceEqual(new[] { "/d", "/c", deploy, "continue", "gaia", "mars" })
            && LocalHosting.GroupScriptStep(host.Control!, "deploy", regions: ["gaia"]).ArgumentList.SequenceEqual(new[] { "/d", "/c", deploy, "gaia" }), "deploy for chosen regions");
        foreach (var bad in new[] { "&calc", "Gaia", "-x x" }) {
            try { LocalHosting.GroupScriptStep(host.Control!, "deploy", regions: [bad]); throw new Exception("bad deploy region accepted: " + bad); } catch (ArgumentException) { assertions++; }
        }
        try { LocalHosting.GroupScriptStep(host.Control!, "restart-host", regions: ["gaia"]); throw new Exception("restart-host regions accepted"); } catch (ArgumentException) { assertions++; }
        File.WriteAllText(groupConfig, "{\"group\": \"earth\", \"mainland\": \"gaia\", \"regions\": [{\"id\": \"railyard\", \"name\": \"Rail Yard\"}, {\"id\": \"gaia\", \"name\": \"Gaia\"}, {\"id\": \"Bad Id\", \"name\": \"x\"}, {\"id\": \"mars\", \"name\": \"Mars\"}]}");
        var listed = LocalHosting.GroupRegions(host.Control!.Group!);
        Require(listed.SequenceEqual(new[] { new LocalHosting.GroupRegion("railyard", "Rail Yard", false), new LocalHosting.GroupRegion("gaia", "Gaia", true), new LocalHosting.GroupRegion("mars", "Mars", false) }),
            "group regions: " + string.Join(" | ", listed));
        File.WriteAllText(groupConfig, "{\"regions\": [{\"id\": \"gaia\", \"name\": \"Gaia\"}, {\"id\": \"mars\", \"name\": \"Mars\"}]}");
        Require(LocalHosting.GroupRegions(host.Control!.Group!)[0].Mainland, "the first region is the default mainland");
        File.WriteAllText(groupConfig, "{\"regions\": []}");
        Reject(() => LocalHosting.GroupRegions(host.Control!.Group!), "a group with no regions");
        File.WriteAllText(groupConfig, "");
        Require(LocalHosting.GroupStep(host.Control!, "kill", "gaia").ArgumentList.SequenceEqual(new[] { "-I", "-B", shard, "--config", groupConfig, "kill", "--region", "gaia" }), "one-region kill argv");
        Require(LocalHosting.GroupStep(host.Control!, "check-update").ArgumentList.Last() == "check-update", "group check-update not allowed");
        foreach (var bad in new[] { "--all", "Gaia", "", "a b", @"..\x", new string('a', 33) }) {
            try { LocalHosting.GroupStep(host.Control!, "kill", bad); throw new Exception("bad region id accepted: " + bad); } catch (ArgumentException) { assertions++; }
        }
        // deploy.bat exit 3: which regions did not save (still running, nothing under way) and why.
        var deployOutput = "[2/6] Saving and stopping every region...\n{\"accepted\": {\"railyard\": {\"accepted\": true}, \"mars\": {\"accepted\": true}}, \"refused\": {\"gaia\": \"the world is busy or not ready, so it cannot save now\", \"moon\": \"the server is not running\"}, \"ok\": true}\n" +
            "gaia failed: it is still running and not saving\n";
        var afterStop = "{\"group\": \"earth\", \"regions\": {" +
            "\"gaia\": {\"name\": \"Gaia\", \"state\": \"awake\", \"listening\": true, \"busy\": false, \"operation\": {\"action\": \"start\", \"phase\": \"done\", \"error\": null}}, " +
            "\"railyard\": {\"name\": \"Rail Yard\", \"state\": \"stopped\", \"listening\": false, \"busy\": false, \"operation\": {\"action\": \"stop\", \"phase\": \"stopped\", \"error\": null}}, " +
            "\"mars\": {\"name\": \"Mars\", \"state\": \"awake\", \"listening\": true, \"busy\": false, \"operation\": {\"action\": \"stop\", \"phase\": \"failed\", \"error\": \"the world reported a save error: disk full\"}}, " +
            "\"moon\": {\"name\": \"Moon\", \"state\": \"cold\", \"listening\": false, \"busy\": false}, " +
            "\"barren\": {\"name\": \"Still saving\", \"state\": \"awake\", \"listening\": true, \"busy\": true}}, \"ok\": true}";
        var unsaved = LocalHosting.UnsavedRegions(afterStop, deployOutput);
        Require(unsaved.Count == 2 && unsaved[0] == new LocalHosting.UnsavedRegion("gaia", "Gaia", "its save was refused: the world is busy or not ready, so it cannot save now")
            && unsaved[1] == new LocalHosting.UnsavedRegion("mars", "Mars", "the world reported a save error: disk full"),
            "unsaved regions: " + string.Join(" | ", unsaved));
        Require(LocalHosting.UnsavedRegions("Traceback", deployOutput).Count == 0 && LocalHosting.UnsavedRegions(afterStop, "").Count == 2, "unsaved garbage");
        Require(LocalHosting.UnsavedRegions("{\"regions\": {\"../x\": {\"listening\": true}}}", "").Count == 0, "unsafe region id offered for a kill");
        try { LocalHosting.GroupScriptStep(host.Control!, @"..\evil"); throw new Exception("unknown group script accepted"); } catch (ArgumentException) { assertions++; }
        File.Delete(deploy);
        Reject(() => LocalHosting.Load(launcher), "control.group without deploy.bat in the checkout");
        File.WriteAllText(deploy, "");
        var groupStatus = LocalHosting.ParseGroup("status", 0, "{\"group\": \"earth\", \"regions\": {\"gaia\": {\"name\": \"Gaia\", \"state\": \"awake\", \"busy\": false, \"world\": {\"ready\": 1, \"clients\": 5}, \"operation\": {\"action\": \"start\", \"phase\": \"done\", \"error\": null}}, \"railyard\": {\"name\": \"Rail Yard\", \"state\": \"stopped\", \"busy\": true, \"operation\": {\"action\": \"update\", \"phase\": \"compiling\", \"error\": null}}}, \"coordinator\": true, \"ok\": true}");
        Require(groupStatus.Ok && groupStatus.Busy && groupStatus.Message == "Group: Gaia: awake, 5 players, last start (done); Rail Yard: stopped, last update (compiling).", "group status line: " + groupStatus.Message);
        var groupStop = LocalHosting.ParseGroup("stop", 0, "{\"accepted\": {\"gaia\": {\"accepted\": true}}, \"refused\": {\"railyard\": \"the server is not running\"}, \"ok\": true}");
        Require(groupStop is { Ok: true, Busy: true } && groupStop.Message == "Saving, then stopping gaia... Refused: railyard: the server is not running.", "group stop line: " + groupStop.Message);
        var groupRefused = LocalHosting.ParseGroup("start", 1, "{\"ok\": false, \"refused\": {\"gaia\": \"already running\"}}");
        Require(groupRefused is { Ok: false, Busy: false } && groupRefused.Message == "Refused: gaia: already running", "group refusal line: " + groupRefused.Message);
        Require(LocalHosting.ParseGroup("update", 1, "{\"ok\": false, \"refused\": \"git fetch origin failed\"}").Message == "Refused: git fetch origin failed", "whole-group refusal");
        Require(!LocalHosting.ParseGroup("restart", 0, "{\"ok\": true, \"accepted\": {}, \"refused\": {}}").Ok, "an empty acceptance counted");
        Require(!LocalHosting.ParseGroup("status", 1, "Traceback").Ok, "group garbage accepted");
        // Forced stop and restart: no save, the next start loads the last completed one.
        Require(LocalHosting.ParseControl("kill", 0, "{\"killed\": true, \"pid\": 4, \"reason\": \"forced stop\", \"ok\": true}") is { Ok: true, Busy: false } killed
            && killed.Message.Contains("without saving"), "kill answer");
        Require(LocalHosting.ParseControl("kill", 1, "{\"ok\": false, \"refused\": \"the server is not running\"}").Message == "Refused: the server is not running", "kill refusal");
        Require(LocalHosting.ParseControl("force-restart", 0, "{\"accepted\": true, \"action\": \"start\", \"operation\": \"x\", \"killed\": true, \"ok\": true}") is { Ok: true, Busy: true } forced
            && forced.Message.StartsWith("Server force-stopped without saving; starting"), "force-restart answer");
        Require(LocalHosting.ControlStep(host.Control!, "kill").ArgumentList.Last() == "kill" && LocalHosting.GroupStep(host.Control!, "force-restart").ArgumentList.Last() == "force-restart", "force actions not allowed");
        var groupKill = LocalHosting.ParseGroup("kill", 0, "{\"done\": {\"gaia\": {\"killed\": true}}, \"refused\": {\"railyard\": \"the server is not running\"}, \"ok\": true}");
        Require(groupKill is { Ok: true, Busy: false } && groupKill.Message.StartsWith("Force-stopped gaia without saving") && groupKill.Message.Contains("railyard: the server is not running"), "group kill: " + groupKill.Message);
        var groupForce = LocalHosting.ParseGroup("force-restart", 0, "{\"accepted\": {\"gaia\": {}, \"railyard\": {}}, \"refused\": {}, \"ok\": true}");
        Require(groupForce is { Ok: true, Busy: true } && groupForce.Message.EndsWith("gaia, railyard..."), "group force-restart: " + groupForce.Message);

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
