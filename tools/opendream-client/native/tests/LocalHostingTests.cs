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
        Require(LocalHosting.MobileAddress("https://192.168.1.8:8443") == "https://192.168.1.8:8443", "mobile LAN address changed");
        Require(LocalHosting.BattlePhase("rotating") == "building the next map" && LocalHosting.BattlePhase("pregame") == "forming"
            && LocalHosting.BattlePhase("odd<phase>") == "oddphase", "TDM battle phase words");
        using (var details = JsonDocument.Parse("{\"port\":1715,\"region_view\":{\"players\":4,\"battle_phase\":\"playing\"}}"))
            Require(LocalHosting.RegionDetails(details.RootElement).EndsWith("battle in progress"), "battle phase on the region row: " + LocalHosting.RegionDetails(details.RootElement));
        foreach (var invalid in new[] { "http://192.168.1.8:8443", "https://8.8.8.8:8443", "https://localhost:8443",
                "https://192.168.1.8:8443/path", "https://user@192.168.1.8:8443", "https://192.168.1.8:8443/?token=secret" })
            Reject(() => LocalHosting.MobileAddress(invalid), "unsafe mobile address");
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
        Require(LocalHosting.GroupStep(host.Control!, "fresh-world", "gaia", null, "gaia").ArgumentList.SequenceEqual(
            new[] { "-I", "-B", shard, "--config", groupConfig, "fresh-world", "--region", "gaia", "--confirm-region", "gaia" }), "fresh world explicit region confirmation argv");
        foreach (var (selected, confirmation) in new (string?, string?)[] { (null, null), ("gaia", null), ("gaia", "deep"), ("gaia", "GAIA") })
            try { LocalHosting.GroupStep(host.Control!, "fresh-world", selected, null, confirmation); throw new Exception("unsafe fresh world accepted"); } catch (ArgumentException) { assertions++; }
        try { LocalHosting.GroupStep(host.Control!, "start", "gaia", null, "gaia"); throw new Exception("confirmation on ordinary start accepted"); } catch (ArgumentException) { assertions++; }
        var groupStep = LocalHosting.GroupStep(host.Control!, "stop");
        Require(groupStep.FileName == python && groupStep.CreateNoWindow && !groupStep.UseShellExecute && groupStep.RedirectStandardInput &&
            groupStep.ArgumentList.SequenceEqual(new[] { "-I", "-B", shard, "--config", groupConfig, "stop" }), "group argv changed: " + string.Join(" ", groupStep.ArgumentList));
        try { LocalHosting.GroupStep(host.Control!, "adopt"); throw new Exception("unsupported group action accepted"); } catch (ArgumentException) { assertions++; }
        foreach (var bad in new[] { "config-migrate", "enrol" })
            try { LocalHosting.GroupStep(host.Control!, bad, "gaia"); throw new Exception("unsupported group action accepted: " + bad); } catch (ArgumentException) { assertions++; }
        foreach (var one in new[] { "freeze", "thaw", "stage", "setup" })
            Require(LocalHosting.GroupStep(host.Control!, one, "moon").ArgumentList.SequenceEqual(new[] { "-I", "-B", shard, "--config", groupConfig, one, "--region", "moon" }), "one-region " + one + " argv");
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
        File.WriteAllText(groupConfig, "{\"root\": \"" + dir.Replace("\\", "/") + "/regions\", \"regions\": [{\"id\": \"gaia\", \"name\": \"Gaia\", \"port\": 1714, \"transfer_port\": 1724}, {\"id\": \"mars\", \"name\": \"Mars\", \"port\": 99999}]}");
        var ported = LocalHosting.GroupRegions(host.Control!.Group!);
        Require(ported[0].Mainland && ported[0].Port == 1714 && ported[0].TransferPort == 1724, "the first region is the default mainland, with its ports");
        Require(ported[1].Port == 0 && ported[1].TransferPort == 0, "an out-of-range port was kept");
        Require(LocalHosting.RegionLog(host.Control!.Group!, "mars") == Path.Combine(Path.GetFullPath(Path.Combine(dir, "regions")), "mars", "logs", "world.log"), "region log path");
        try { LocalHosting.RegionLog(host.Control!.Group!, "../gaia"); throw new Exception("bad region id accepted for a log"); } catch (ArgumentException) { assertions++; }
        File.WriteAllText(groupConfig, "{\"regions\": [{\"id\": \"gaia\", \"name\": \"Gaia\"}]}");
        Require(LocalHosting.RegionLog(host.Control!.Group!, "gaia") == null, "a log without a group root");
        File.WriteAllText(groupConfig, "{\"regions\": []}");
        Reject(() => LocalHosting.GroupRegions(host.Control!.Group!), "a group with no regions");
        // Host settings live in the group's overlays, never in the checkout a pull updates.
        var sharedOverlay = Path.Combine(dir, "overlay", "shared");
        var gaiaOverlay = Path.Combine(dir, "overlay", "gaia");
        Directory.CreateDirectory(Path.Combine(gaiaOverlay, "config"));
        foreach (var name in new[] { "account_signin.json", "config.txt", "config.txt.migrated", "config.local.txt.previous", "config.txt.bak-20261106", "transfer-token.txt", "kestrel.dll" })
            File.WriteAllText(Path.Combine(gaiaOverlay, "config", name), "{}");
        File.WriteAllText(groupConfig, JsonSerializer.Serialize(new { overlay = sharedOverlay, regions = new object[] {
            new { id = "gaia", name = "Gaia", overlay = gaiaOverlay }, new { id = "mars", name = "Mars" }, new { id = "moon", overlay = "relative" } } }));
        var places = HostSettings.Locations(host.Control!.Group!);
        Require(places.Select(place => (place.Label, place.Folder, place.Region)).SequenceEqual(new[] {
            ("Every region (shared)", Path.GetFullPath(sharedOverlay), (string?)null), ("Gaia only", Path.GetFullPath(gaiaOverlay), "gaia") }),
            "host settings locations: " + string.Join(" | ", places));
        Require(HostSettings.Files(places[1]).SequenceEqual(new[] { HostSettings.LocalConfig, "config/host.txt", "config/account_signin.json", "config/config.txt" }),
            "host settings files: " + string.Join(", ", HostSettings.Files(places[1])));
        Require(HostSettings.Files(places[0]).SequenceEqual(HostSettings.Offered) && HostSettings.Read(places[0], HostSettings.LocalConfig) == "",
            "a missing overlay folder offers the usual files, empty");
        HostSettings.Save(places[0], HostSettings.LocalConfig, "# shared\nDAYNIGHT_CLIENT_TINT\n#SKIP_PERSISTENCE_SAVING\n");
        HostSettings.Save(places[0], HostSettings.LocalConfig, "WEBHOOK_ADDRESS http://127.0.0.1\n");
        HostSettings.Save(places[0], HostSettings.LocalConfig, "WEBHOOK_ADDRESS http://127.0.0.1\n");
        Require(HostSettings.Read(places[0], HostSettings.LocalConfig) == "WEBHOOK_ADDRESS http://127.0.0.1\n"
            && File.ReadAllText(Path.Combine(sharedOverlay, "config", "config.local.txt.previous")).Contains("DAYNIGHT_CLIENT_TINT"), "save keeps the previous version");
        Require(HostSettings.WithSetting("# shared\nWEBHOOK_KEY k\n#BUG_REPORT_GITHUB_TOKEN old\nbug_report_github_token older\n", HostSettings.BugReportToken, "github_pat_new")
            == "# shared\nWEBHOOK_KEY k\nBUG_REPORT_GITHUB_TOKEN github_pat_new\n", "bug report token replaces the old lines in place");
        Require(HostSettings.WithSetting("WEBHOOK_KEY k", HostSettings.BugReportToken, " ghp_x ") == "WEBHOOK_KEY k\nBUG_REPORT_GITHUB_TOKEN ghp_x\n"
            && HostSettings.WithSetting("", HostSettings.BugReportToken, "ghp_x") == "BUG_REPORT_GITHUB_TOKEN ghp_x\n", "bug report token is appended");
        Require(HostSettings.TokenValid("github_pat_11AAAAAAAAAAAAAAAAAAAA") && !HostSettings.TokenValid("short")
            && !HostSettings.TokenValid("github_pat_with space inside it"), "bug report token format");
        Require(HostSettings.Problem(HostSettings.LocalConfig, HostSettings.WithSetting("", HostSettings.BugReportToken, "ghp_x")) == null, "the token line is a valid setting");
        Reject(() => HostSettings.WithSetting("", "BAD KEY", "x"), "a setting name with a space");
        var withToken = "WEBHOOK_KEY k\nBUG_REPORT_GITHUB_TOKEN github_pat_secret\n";
        Require(HostSettings.HideSecrets(withToken) == "WEBHOOK_KEY k\nBUG_REPORT_GITHUB_TOKEN (hidden)\n"
            && !HostSettings.HideSecrets(withToken).Contains("github_pat_secret"), "the editor never shows the token");
        Require(HostSettings.RestoreSecrets("WEBHOOK_KEY other\nBUG_REPORT_GITHUB_TOKEN (hidden)\n", withToken)
            == "WEBHOOK_KEY other\nBUG_REPORT_GITHUB_TOKEN github_pat_secret\n", "saving puts the hidden token back");
        Require(HostSettings.RestoreSecrets("WEBHOOK_KEY k\n", withToken) == "WEBHOOK_KEY k\n", "deleting the hidden line removes the token");
        Require(HostSettings.Problem(HostSettings.LocalConfig, "OK 1\n=bad\n") == "Line 2 is not a setting (\"KEY value\", \"KEY\" or \"#KEY\").", "bad override line");
        Require(HostSettings.Problem("config/account_signin.json", "{") is { } jsonProblem && jsonProblem.StartsWith("Not valid JSON"), "bad JSON");
        Reject(() => HostSettings.Save(places[1], "config/account_signin.json", "{"), "invalid JSON saved");
        Reject(() => HostSettings.Save(places[1], "config/transfer-token.txt", "x"), "a file setup writes");
        Reject(() => HostSettings.Save(places[1], "../outside.txt", "x"), "a path outside the overlay");
        // Hub names: only the SERVER_NAME line of config.local.txt changes; an empty name removes it.
        Require(HostSettings.WithServerName("WEBHOOK_KEY k\n#SERVER_NAME\nserver_name Old\n", " Civ13 - Gaia ") == "WEBHOOK_KEY k\nSERVER_NAME Civ13 - Gaia\n", "hub name replaces old lines in place");
        Require(HostSettings.WithServerName("WEBHOOK_KEY k", "Civ13") == "WEBHOOK_KEY k\nSERVER_NAME Civ13\n", "hub name is appended");
        Require(HostSettings.WithServerName("# keep me\nSERVER_NAME Old\nWEBHOOK_KEY k\n#SERVER_NAME\n", "") == "# keep me\nWEBHOOK_KEY k\n", "an empty hub name removes its lines");
        Require(HostSettings.WithServerName("SERVER_NAME Old\n", " ") == "", "removing the only line leaves an empty file");
        Require(HostSettings.Problem(HostSettings.LocalConfig, HostSettings.WithServerName("", "Civ13 Gaia (EU) #1")) == null, "the hub name line is a valid setting");
        foreach (var bad in new[] { "Val's world", "say \"hi\"", "a\\b", "<b>x</b>", "#hidden", "tab\there", new string('x', HostSettings.ServerNameLength + 1) })
            Require(HostSettings.ServerNameProblem(bad) != null, "bad hub name accepted: " + bad);
        Reject(() => HostSettings.WithServerName("", "Val's"), "a hub name with a quote saved");
        Require(HostSettings.SettingValue("SERVER_NAME A\n#SERVER_NAME B\n# SERVER_NAME C\nserver_name  D \n", HostSettings.ServerName) == "D"
            && HostSettings.SettingValue("#SERVER_NAME A\n", HostSettings.ServerName) == null, "setting value as the game reads it");
        File.WriteAllText(groupConfig, JsonSerializer.Serialize(new { root = Path.Combine(dir, "regions"), regions = new object[] { new { id = "gaia" } } }));
        Require(HostSettings.RegionServerName(host.Control!.Group!, "mars") == null, "a region not set up has no hub name");
        Directory.CreateDirectory(Path.Combine(dir, "regions", "gaia", "config"));
        File.WriteAllText(Path.Combine(dir, "regions", "gaia", "config", "config.txt"), "#SERVER_NAME x\n");
        Require(HostSettings.RegionServerName(host.Control!.Group!, "gaia") == HostSettings.DefaultServerName, "no active line falls back to the game default");
        File.WriteAllText(Path.Combine(dir, "regions", "gaia", "config", "config.txt"), "SERVER_NAME Civilization 13\nSERVER_NAME Civ13 Gaia\n");
        Require(HostSettings.RegionServerName(host.Control!.Group!, "gaia") == "Civ13 Gaia", "the merged region config's hub name");
        try { HostSettings.RegionServerName(host.Control!.Group!, "../gaia"); throw new Exception("bad region id accepted for a hub name"); } catch (ArgumentException) { assertions++; }
        Require(LocalHosting.GroupStep(host.Control!, "config-apply", "gaia").ArgumentList.SequenceEqual(new[] { "-I", "-B", shard, "--config", groupConfig, "config-apply", "--region", "gaia" }), "config-apply argv");
        var applied = LocalHosting.ParseGroup("config-apply", 0, "{\"done\": {\"gaia\": {\"copied\": [\"config/config.local.txt\"], \"running\": true}, \"mars\": {\"copied\": [], \"running\": false}}, \"refused\": {\"moon\": \"the region is not set up\"}, \"ok\": true}");
        Require(applied is { Ok: true, Busy: false } && applied.Message == "gaia: 1 file written (running: used from its next restart). mars: already current. Refused: moon: the region is not set up.",
            "config-apply answer: " + applied.Message);
        File.WriteAllText(groupConfig, "");
        // Advance epoch: one epoch for the whole group, never per region; regions follow the mainland.
        Require(LocalHosting.GroupStep(host.Control!, "epoch", null, 9).ArgumentList.SequenceEqual(new[] { "-I", "-B", shard, "--config", groupConfig, "epoch", "--epoch", "9" }), "epoch argv");
        foreach (var (badRegion, badEpoch) in new (string?, int?)[] { (null, null), ("gaia", 9), (null, 10), (null, -1) })
            try { LocalHosting.GroupStep(host.Control!, "epoch", badRegion, badEpoch); throw new Exception($"bad epoch step accepted: {badRegion} {badEpoch}"); } catch (ArgumentException) { assertions++; }
        try { LocalHosting.GroupStep(host.Control!, "stop", null, 9); throw new Exception("an epoch on another action accepted"); } catch (ArgumentException) { assertions++; }
        var advanced = LocalHosting.ParseGroup("epoch", 0, "{\"epoch\": 9, \"name\": \"2026\", \"mainland\": \"gaia\", \"regions\": {\"gaia\": \"set\", \"moon\": \"current\", \"railyard\": \"asleep: follows the mainland when it wakes\"}, \"ok\": true}");
        Require(advanced is { Ok: true, Busy: false } && advanced.Message == "Epoch 2026: gaia: now 2026; moon: already at 2026 or later; railyard: asleep: follows the mainland when it wakes.", "epoch answer: " + advanced.Message);
        Require(LocalHosting.ParseGroup("epoch", 1, "{\"ok\": false, \"refused\": \"the mainland gaia is not awake; start or wake it first (every region follows its epoch)\"}").Message.StartsWith("Refused: the mainland gaia is not awake"), "epoch refusal");
        var withEpoch = LocalHosting.ParseGroup("status", 0, "{\"regions\": {\"gaia\": {\"name\": \"Gaia\", \"state\": \"awake\", \"region_view\": {\"players\": 0, \"epoch\": {\"ordinal\": 8, \"name\": \"2013\"}}}}, \"ok\": true}");
        Require(withEpoch.Message == "Group: Gaia: awake, epoch 2013.", "status epoch: " + withEpoch.Message);
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
        Require(groupStatus.Ok && groupStatus.Busy && groupStatus.Message == "Group: Gaia: awake, 5 players, last start (done); Rail Yard: stopped, last update (compiling). Travel coordinator running.", "group status line: " + groupStatus.Message);
        // Staged builds and handovers: the status line shows the build beside each world, the standby during a handover.
        var stagedStatus = LocalHosting.ParseGroup("status", 0, "{\"regions\": {" +
            "\"gaia\": {\"name\": \"Gaia\", \"state\": \"awake\", \"stage\": {\"phase\": \"ready\", \"pending\": true}, \"operation\": {\"action\": \"handover\", \"phase\": \"loading the standby\"}, \"standby\": {\"port\": 1728, \"listening\": true}}, " +
            "\"railyard\": {\"name\": \"Rail Yard\", \"state\": \"asleep\", \"stage\": {\"phase\": \"waiting for another region's compile\"}}, " +
            "\"barren\": {\"name\": \"Mars\", \"state\": \"awake\", \"stage\": {\"phase\": \"failed\", \"error\": \"compile failed\"}}, " +
            "\"moon\": {\"name\": \"Moon\", \"state\": \"awake\", \"stage\": {\"phase\": \"current\"}, \"operation\": {\"action\": \"handover\", \"phase\": \"handed over\"}}}, \"ok\": true}");
        Require(stagedStatus.Ok && stagedStatus.Message == "Group: Gaia: awake, last handover (loading the standby), update built (ready to hand over), new build running beside it; " +
            "Rail Yard: asleep, building update (waiting for another region's compile); Mars: awake, update build failed: compile failed; Moon: awake, last handover (handed over).",
            "staged status line: " + stagedStatus.Message);
        Require(LocalHosting.GroupStep(host.Control!, "stage").ArgumentList.SequenceEqual(new[] { "-I", "-B", shard, "--config", groupConfig, "stage" })
            && LocalHosting.GroupStep(host.Control!, "handover", "gaia").ArgumentList.SequenceEqual(new[] { "-I", "-B", shard, "--config", groupConfig, "handover", "--region", "gaia" }), "stage and handover argv");
        Require(LocalHosting.ParseGroup("stage", 0, "{\"accepted\": {\"gaia\": {\"accepted\": true}}, \"refused\": {\"moon\": \"a build is already being staged\"}, \"ok\": true}").Message
            == "Building the update beside gaia... Refused: moon: a build is already being staged.", "stage line");
        // The group status also tells staged updates, handovers, the watchdog and travel.
        var detailed = LocalHosting.ParseGroup("status", 0, "{\"group\": \"earth\", \"regions\": {"
            + "\"gaia\": {\"name\": \"Gaia\", \"state\": \"awake\", \"port\": 1714, \"stage\": {\"phase\": \"ready\", \"pending\": true}, \"standby\": {\"port\": 1728, \"listening\": true}, \"transfer_agent\": true}, "
            + "\"railyard\": {\"name\": \"Rail Yard\", \"state\": \"stopped\", \"port\": 1715, \"stage\": {\"phase\": \"compiling\"}, \"watchdog\": {\"gave_up\": 5, \"last_event\": \"crash\", \"restarts\": [1, 2, 3]}, \"transfer_agent\": false}, "
            + "\"barren\": {\"name\": \"Mars\", \"state\": \"awake\", \"stage\": {\"phase\": \"failed\", \"error\": \"compile failed\"}, \"watchdog\": {\"restarts\": [9], \"last_event\": \"hang\"}, \"region_view\": {\"error\": \"no matching shard_region answer\"}}, "
            + "\"moon\": {\"name\": \"Moon\", \"state\": \"asleep\", \"stage\": {\"phase\": \"current\"}}}, \"coordinator\": false, \"ok\": true}");
        Require(detailed.Ok && detailed.Message == "Group: Gaia: awake, port 1714, update built (ready to hand over), new build running beside it; "
            + "Rail Yard: stopped, port 1715, building update (compiling), watchdog gave up after repeated restarts (crash); start it by hand, travel agent not running; "
            + "Mars: awake, update build failed: compile failed, watchdog restarted it 1 time recently (last: hang), not answering as this region; Moon: asleep. "
            + "Travel coordinator is not running (a start or restart starts it).", "detailed group status: " + detailed.Message);
        var frozen = LocalHosting.ParseGroup("freeze", 0, "{\"done\": {\"moon\": {\"frozen\": true, \"pid\": 4}}, \"refused\": {\"gaia\": \"1 client(s) are connected\"}, \"ok\": true}");
        Require(frozen is { Ok: true, Busy: false } && frozen.Message == "Asleep now (a join or travel wakes it): moon. Refused: gaia: 1 client(s) are connected.", "freeze: " + frozen.Message);
        Require(LocalHosting.ParseGroup("thaw", 0, "{\"done\": {\"moon\": {\"thawed\": true}}, \"refused\": {}, \"ok\": true}").Message == "Woken: moon.", "thaw");
        Require(LocalHosting.ParseGroup("thaw", 1, "{\"ok\": false, \"refused\": {\"moon\": \"the server is not frozen\"}}") is { Ok: false } notFrozen
            && notFrozen.Message == "Refused: moon: the server is not frozen", "thaw refusal");
        var setUp = LocalHosting.ParseGroup("setup", 0, "{\"revision\": \"" + new string('a', 40) + "\", \"created\": [\"moon\"], \"regions\": [\"gaia\", \"moon\"], \"region\": \"moon\", \"running\": [\"gaia\"], \"enrolled\": [\"gaia\"], \"ok\": true}");
        Require(setUp is { Ok: true, Busy: false } && setUp.Message == "Set up moon. Enrolled it for travel with the running agents. Running regions learn about it at their next restart. Next: Update, then Start.", "setup: " + setUp.Message);
        Require(LocalHosting.ParseGroup("setup", 0, "{\"created\": [], \"region\": \"moon\", \"running\": [], \"enrolled\": [], \"ok\": true}").Message.StartsWith("Refreshed the config of moon."), "setup refresh");
        Require(LocalHosting.ParseGroup("setup", 1, "{\"ok\": false, \"refused\": \"region moon is running; stop it before setup\"}").Message == "Refused: region moon is running; stop it before setup", "setup refusal");
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
        // Lock files a killed world left: unlock reports what it removed and whether the save loads.
        var unlocked = LocalHosting.ParseControl("unlock", 0, "{\"removed\": [\"1.sav.lk\"], \"forced\": false, \"server_running\": false, \"save\": \"round-v2:x\", \"ok\": true}");
        Require(unlocked is { Ok: true, Busy: false } && unlocked.Message == "removed 1 lock file. The save is ready to load.", "unlock answer: " + unlocked.Message);
        Require(LocalHosting.ParseControl("unlock", 1, "{\"ok\": false, \"refused\": \"the server is running\"}").Message == "Refused: the server is running", "unlock refusal");
        var groupUnlock = LocalHosting.ParseGroup("force-unlock", 0, "{\"done\": {\"gaia\": {\"removed\": [], \"save_refused\": \"level 2 of the save is missing\"}}, \"refused\": {}, \"ok\": true}");
        Require(groupUnlock is { Ok: true } && groupUnlock.Message == "gaia: no lock files. The save still does not load: level 2 of the save is missing.", "group unlock: " + groupUnlock.Message);
        Require(LocalHosting.GroupStep(host.Control!, "unlock", "gaia").ArgumentList.SequenceEqual(new[] { "-I", "-B", shard, "--config", groupConfig, "unlock", "--region", "gaia" }), "one-region unlock argv");
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
