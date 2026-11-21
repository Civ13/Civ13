using Civ13.Launcher;

// shard_group.py translator-status / translator-start / translator-stop: argv and the JSON answers the
// Translator tab shows. Process starts are not run; this suite launches nothing.
static class LocalTranslatorTests {
    public static int Run(string root) {
        var assertions = 0;
        void Require(bool condition, string message) {
            assertions++;
            if (!condition) throw new Exception("Local translator contract: " + message);
        }
        var dir = Path.Combine(root, "local-translator");
        Directory.CreateDirectory(dir);
        var group = new HostGroup(Path.Combine(dir, "earth.json"), Path.Combine(dir, "shard_group.py"), Path.Combine(dir, "deploy.bat"), Path.Combine(dir, "restart-host.bat"));
        var control = new HostControl(Path.Combine(dir, "python.exe"), Path.Combine(dir, "gaia_host.py"), Path.Combine(dir, "gaia.json"), group);
        foreach (var action in new[] { "translator-status", "translator-start", "translator-stop" }) {
            var step = LocalHosting.GroupStep(control, action);
            Require(step.FileName == control.Python && step.ArgumentList.SequenceEqual(new[] { "-I", "-B", group.ShardScript, "--config", group.Config, action }), action + " argv");
        }
        Require(LocalHosting.ActionLimit("translator-status") == LocalHosting.ActionLimit("help-status"), "status is a quick read");

        var status = LocalTranslator.ParseStatus(0, "{\"configured\": true, \"running\": true, \"pid\": 4120, \"port\": 55581, \"stopped\": false, \"answering\": true, " +
            "\"url\": \"http://127.0.0.1:55581\", \"log\": \"D:/r/chat-translator/service.log\", \"started_seconds_ago\": 900, " +
            "\"stats\": {\"translated\": 12, \"skipped\": 40, \"failed\": 1, \"busy\": 0, \"waiting\": 0}, \"ok\": true}\n");
        Require(status is { Ok: true, Configured: true, Running: true, Answering: true, Stuck: false, Pid: 4120, Port: 55581, Translated: 12, Failed: 1 }, "status not read");
        Require(status.Describe() == "Running (PID 4120) on port 55581, answering. Translated 12 lines, 1 failed.", "describe: " + status.Describe());
        Require(status.Log == "D:/r/chat-translator/service.log", "log path");
        var opening = LocalTranslator.ParseStatus(0, "{\"configured\": true, \"running\": true, \"pid\": 5, \"port\": 55581, \"stopped\": false, \"answering\": false, \"started_seconds_ago\": 20, \"ok\": true}");
        Require(!opening.Stuck && opening.Describe() == "Running (PID 5) on port 55581, opening Edge.", "opening: " + opening.Describe());
        var stuck = LocalTranslator.ParseStatus(0, "{\"configured\": true, \"running\": true, \"pid\": 5, \"port\": 55581, \"stopped\": false, \"answering\": false, \"started_seconds_ago\": 600, \"ok\": true}");
        Require(stuck.Stuck && stuck.Describe().Contains("not answering"), "stuck");
        var stopped = LocalTranslator.ParseStatus(0, "{\"configured\": true, \"running\": false, \"pid\": null, \"port\": 55581, \"stopped\": true, \"answering\": false, \"ok\": true}");
        Require(stopped is { Running: false, Stopped: true } && stopped.Describe().StartsWith("Stopped on request"), "stopped");
        status = LocalTranslator.ParseStatus(0, "{\"configured\": false, \"ok\": true}");
        Require(status is { Ok: true, Configured: false } && status.Describe().StartsWith("Not set up"), "unconfigured");
        status = LocalTranslator.ParseStatus(2, "usage: shard_group.py ... invalid choice: 'translator-status'\n");
        Require(!status.Ok && status.Error!.Contains("invalid choice"), "old shard_group not reported: " + status.Error);

        Require(LocalTranslator.DescribeAction("translator-start", 0, "{\"started\": true, \"ok\": true}") == "Chat translator started; Edge opens in the background.", "start text");
        Require(LocalTranslator.DescribeAction("translator-start", 0, "{\"started\": false, \"ok\": true}") == "Chat translator is running.", "already running");
        Require(LocalTranslator.DescribeAction("translator-stop", 0, "{\"stopped\": true, \"ok\": true}") == "Chat translator stopped.", "stop text");
        Require(LocalTranslator.DescribeAction("translator-stop", 0, "{\"stopped\": false, \"ok\": true}") == "Chat translator was not running; it stays stopped.", "stop idle");
        Require(LocalTranslator.DescribeAction("translator-start", 1, "{\"ok\": false, \"refused\": \"chat_translator is not configured for this group\"}") ==
            "Chat translator: chat_translator is not configured for this group", "refusal");
        Console.WriteLine($"PASS local translator: {assertions} assertions; translator-status/start/stop argv, status and action answers for the Translator tab.");
        return assertions;
    }
}
