using Civ13.Launcher;

// shard_group.py help-status / help-start / help-stop: argv and the JSON answers the Player help tab shows.
// Process starts are not run; this suite launches nothing.
static class LocalHelpTests {
    public static int Run(string root) {
        var assertions = 0;
        void Require(bool condition, string message) {
            assertions++;
            if (!condition) throw new Exception("Local help contract: " + message);
        }
        var dir = Path.Combine(root, "local-help");
        Directory.CreateDirectory(dir);
        var group = new HostGroup(Path.Combine(dir, "earth.json"), Path.Combine(dir, "shard_group.py"), Path.Combine(dir, "deploy.bat"), Path.Combine(dir, "restart-host.bat"));
        var control = new HostControl(Path.Combine(dir, "python.exe"), Path.Combine(dir, "gaia_host.py"), Path.Combine(dir, "gaia.json"), group);
        foreach (var action in new[] { "help-status", "help-start", "help-stop" }) {
            var step = LocalHosting.GroupStep(control, action);
            Require(step.FileName == control.Python && step.ArgumentList.SequenceEqual(new[] { "-I", "-B", group.ShardScript, "--config", group.Config, action }), action + " argv");
        }

        var status = LocalHelp.ParseStatus(0, "{\"configured\": true, \"stopped\": false, \"config\": \"D:/h.json\", \"regions\": {" +
            "\"gaia\": {\"running\": true, \"pid\": 38088, \"log\": \"D:/r/player-help/gaia.log\", \"enabled\": true, \"heartbeat_age_seconds\": 1}, " +
            "\"railyard\": {\"running\": true, \"pid\": 56340, \"log\": \"D:/r/player-help/railyard.log\", \"enabled\": true, \"heartbeat_age_seconds\": 400}, " +
            "\"barren\": {\"running\": false, \"pid\": null, \"log\": \"D:/r/player-help/barren.log\", \"enabled\": false}}, \"ok\": true}\n");
        Require(status is { Ok: true, Configured: true, Stopped: false, AnyRunning: true } && status.Regions.Count == 3, "status not read");
        Require(status.Regions[0] is { Id: "gaia", Running: true, Pid: 38088, Stale: false, Log: "D:/r/player-help/gaia.log" }, "gaia region");
        Require(status.Regions[1].Stale && status.Regions[1].Describe() == "running (PID 56340), no heartbeat for 400 s", "stale: " + status.Regions[1].Describe());
        Require(status.Regions[2].Describe() == "not running" && status.Regions[0].Describe() == "running (PID 38088), answering", "describe");
        Require(status.Describe().StartsWith("Kept running by the host service.") && status.Describe().Contains("barren: not running"), "status text");

        status = LocalHelp.ParseStatus(0, "{\"configured\": false, \"ok\": true}");
        Require(status is { Ok: true, Configured: false } && status.Describe().StartsWith("Not configured"), "unconfigured");
        status = LocalHelp.ParseStatus(2, "usage: shard_group.py ... invalid choice: 'help-status'\n");
        Require(!status.Ok && status.Error!.Contains("invalid choice"), "old shard_group not reported: " + status.Error);
        status = LocalHelp.ParseStatus(2, "{\"ok\": false, \"error\": \"config: player_help needs a config path\"}");
        Require(!status.Ok && status.Error == "config: player_help needs a config path", "config error");

        Require(LocalHelp.DescribeAction("help-stop", 0, "{\"stopped\": [\"gaia\", \"railyard\"], \"forced\": [\"railyard\"], \"ok\": true}") ==
            "Player help stopped (gaia, railyard); ended without finishing: railyard.", "stop text");
        Require(LocalHelp.DescribeAction("help-start", 0, "{\"started\": [\"gaia\"], \"errors\": {\"barren\": \"bridge is missing\"}, \"ok\": true}") ==
            "Player help started (gaia). Could not start barren: bridge is missing.", "start text");
        Require(LocalHelp.DescribeAction("help-start", 0, "{\"started\": [], \"errors\": {}, \"ok\": true}") == "Player help is running.", "already running");
        Require(LocalHelp.DescribeAction("help-stop", 1, "{\"ok\": false, \"refused\": \"player_help is not configured for this group\"}") ==
            "Player help: player_help is not configured for this group", "refusal");
        Console.WriteLine($"PASS local help: {assertions} assertions; help-status/start/stop argv, status and action answers for the Player help tab.");
        return assertions;
    }
}
