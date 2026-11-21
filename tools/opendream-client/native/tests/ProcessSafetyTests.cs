using System.Diagnostics;
using Civ13.Launcher;

// Criticality rules for the launcher (scripts/gaia-host/README.md, Process safety): captured steps honour their
// limits even while a child holds the pipes, kills only match verified targets, and the experimental WMI check
// reads without changing anything. The real-process checks run /bin/sh and are skipped off Linux/macOS.
static class ProcessSafetyTests {
    public static int Run(string root) {
        var assertions = 0;
        void Require(bool condition, string message) {
            assertions++;
            if (!condition) throw new Exception("Process safety contract: " + message);
        }

        // Verification is by program file name and age; unknown never matches.
        var now = DateTime.UtcNow;
        var dd = new ProcessSafety.Identity(10, now.AddMinutes(-5), @"C:\BYOND\bin\dd.exe");
        Require(ProcessSafety.Problem(dd, ["dd.exe", "dreamdaemon.exe"]) == null, "DreamDaemon matches");
        Require(ProcessSafety.Problem(dd with { Image = @"C:\Windows\explorer.exe" }, ["dd.exe"]) is { } other && other.Contains("explorer.exe"), "another program is named");
        Require(ProcessSafety.Problem(dd, ["dd.exe"], now.AddMinutes(-10)) is { } reused && reused.Contains("reused"), "a younger process holds a reused pid");
        Require(ProcessSafety.Problem(dd, ["dd.exe"], now) == null, "an older process is the recorded one");
        Require(ProcessSafety.Problem(null, ["dd.exe"]) is { } unknown && unknown.Contains("could not be inspected"), "unknown is not a match");
        Require(ProcessSafety.Problem(dd with { Image = null }, ["dd.exe"]) != null, "no image is not a match");

        // Limits by tier: status reads are short, quick requests answer in minutes, builds keep the long limit.
        Require(LocalHosting.ActionLimit("status") == LocalHosting.StatusLimit && LocalHosting.ActionLimit("kill") == LocalHosting.RequestLimit &&
            LocalHosting.ActionLimit("start") == LocalHosting.StartLimit && LocalHosting.ActionLimit("update") == LocalHosting.LongLimit &&
            LocalHosting.ActionLimit("stage") == LocalHosting.LongLimit, "action limits");
        var control = new HostControl("python.exe", Path.Combine(root, "gaia_host.py"), Path.Combine(root, "gaia.json"));
        Require(LocalHosting.LimitOf(LocalHosting.ControlStep(control, "status")) == LocalHosting.StatusLimit, "a status step carries its limit");
        Require(LocalHosting.LimitOf(new ProcessStartInfo("x")) == LocalHosting.LongLimit, "an unlabelled step keeps the long limit");

        if (!OperatingSystem.IsWindows() && File.Exists("/bin/sh")) {
            ProcessStartInfo Shell(string script) {
                var step = new ProcessStartInfo("/bin/sh") { UseShellExecute = false, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
                step.ArgumentList.Add("-c");
                step.ArgumentList.Add(script);
                return step;
            }
            var watch = Stopwatch.StartNew();
            try { LocalHosting.RunCaptured(Shell("sleep 30").WithLimit(TimeSpan.FromSeconds(1))); throw new Exception("a hung step was not ended"); }
            catch (LocalHosting.StepTimedOut e) { Require(e.Message.Contains("did not answer within 1 s"), "timeout message: " + e.Message); }
            Require(watch.Elapsed < TimeSpan.FromSeconds(10), "the limit holds: " + watch.Elapsed);
            watch.Restart();
            // A grandchild keeping stdout open used to block the read forever (the limit was never reached).
            var (exit, output) = LocalHosting.RunCaptured(Shell("sleep 2 & echo hi").WithLimit(TimeSpan.FromSeconds(30)));
            Require(exit == 0 && output.Contains("hi") && watch.Elapsed < TimeSpan.FromSeconds(15), "a finished step answers: " + output);
            Require(LocalHosting.RunCaptured(Shell("echo out; echo err >&2; exit 3")) is (3, var both) && both.Contains("out") && both.Contains("err"), "exit and both streams");
        }

        // The experimental WMI check: parsing, classification, the setting and the elevated step shape.
        var (state, pid) = WmiHealth.ParseService("SERVICE_NAME: winmgmt\r\n        TYPE               : 30  WIN32\r\n        STATE              : 3  STOP_PENDING\r\n" +
            "        PID                : 2468\r\n");
        Require(state == "STOP_PENDING" && pid == 2468, $"sc queryex parsed: {state} {pid}");
        Require(WmiHealth.ParseService("garbage") == (null, null), "nothing parsed from garbage");
        Require(WmiHealth.Classify(0, "Microsoft Windows 11 Pro", false, TimeSpan.FromSeconds(1), "RUNNING", 2468, 2).State == WmiHealth.State.Healthy, "healthy");
        Require(WmiHealth.Classify(0, "Microsoft Windows 11 Pro", false, TimeSpan.FromSeconds(9), "RUNNING", 2468, 2).State == WmiHealth.State.Slow, "slow");
        Require(WmiHealth.Classify(-1, "", true, TimeSpan.FromSeconds(15), "RUNNING", 2468, 9) is { State: WmiHealth.State.Broken } hung && hung.Summary.Contains("did not answer"), "hung");
        Require(WmiHealth.Classify(1, "Get-CimInstance : Provider load failure", false, TimeSpan.FromSeconds(1), "RUNNING", 2468, 2) is { State: WmiHealth.State.Broken } provider
            && provider.Summary.Contains("Provider load failure"), "provider load failure");
        Require(WmiHealth.Classify(0, "x", false, TimeSpan.FromSeconds(1), "STOP_PENDING", 2468, 2) is { State: WmiHealth.State.Broken } stuck && stuck.Summary.Contains("step 3"), "stuck stopping");
        var timedOut = WmiHealth.Check(step => step.FileName.EndsWith("sc.exe", StringComparison.OrdinalIgnoreCase)
            ? (0, "STATE : 4  RUNNING\nPID : 99\n") : throw new LocalHosting.StepTimedOut("powershell.exe did not answer"), () => 3);
        Require(timedOut is { State: WmiHealth.State.Broken, ServicePid: 99, ProviderHosts: 3 }, "check classifies a timed-out query: " + timedOut.Summary);
        Require(LocalHosting.LimitOf(WmiHealth.QueryStep()) == WmiHealth.QueryLimit && LocalHosting.LimitOf(WmiHealth.ServiceStep()) == WmiHealth.ServiceLimit, "check limits");

        var settings = Path.Combine(root, "wmi-setting");
        Directory.CreateDirectory(settings);
        Require(!WmiHealth.Enabled(settings), "off by default");
        File.WriteAllText(Path.Combine(settings, WmiHealth.FileName), "{\"other\":1}");
        WmiHealth.SetEnabled(settings, true);
        Require(WmiHealth.Enabled(settings) && File.ReadAllText(Path.Combine(settings, WmiHealth.FileName)).Contains("\"other\""), "turned on, other settings kept");
        WmiHealth.SetEnabled(settings, false);
        Require(!WmiHealth.Enabled(settings), "turned off");
        File.WriteAllText(Path.Combine(settings, WmiHealth.FileName), "not json");
        Require(!WmiHealth.Enabled(settings), "a broken file reads as off");

        foreach (var step in WmiHealth.Steps) {
            var start = WmiHealth.Elevated(step, @"C:\Temp\out.txt", 2468);
            Require(start.UseShellExecute && start.Verb == "runas" && start.Arguments.Contains(step.Command.Replace("{pid}", "2468").Replace("\"", "\\\"")), step.Id + " runs elevated");
        }
        var hostStep = WmiHealth.Steps.Single(step => step.NeedsServicePid);
        try { WmiHealth.Elevated(hostStep, @"C:\Temp\out.txt", null); throw new Exception("ended an unknown service host"); } catch (InvalidOperationException) { assertions++; }
        try { WmiHealth.Elevated(WmiHealth.Steps[0], @"C:\Temp\o'ut.txt"); throw new Exception("quoted output path accepted"); } catch (InvalidDataException) { assertions++; }
        Require(WmiHealth.Steps.All(step => !step.Command.Contains("taskkill", StringComparison.OrdinalIgnoreCase)), "repairs do not use taskkill");

        Console.WriteLine($"PASS process safety: {assertions} assertions; enforced step limits, verified kill matching, WMI check parsing and elevated repair shape.");
        return assertions;
    }
}
