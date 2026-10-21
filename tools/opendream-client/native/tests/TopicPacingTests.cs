using Civ13.Launcher;
using System.Diagnostics;
using System.Net;
using System.Reflection;
using System.Text.Json.Nodes;

internal static class TopicPacingTests {
    private static readonly DateTimeOffset Epoch = DateTimeOffset.Parse("2026-10-21T04:00:00Z");
    private static readonly IPAddress Address = IPAddress.Parse("72.218.249.221");
    private static readonly GameTarget Target = ServerCatalog.Candidates("ValZarGaming")[0];
    private sealed class Clock {
        public DateTimeOffset Utc = Epoch;
        public long Tick;
        public void Advance(int seconds) { Utc = Utc.AddSeconds(seconds); Tick += seconds * 1000L; }
        public TopicPacer Pacer(string path) => new(path, () => Utc, () => Tick);
    }
    public static int Child(string path) {
        var clock = new Clock { Utc = Epoch.AddSeconds(137) };
        var pacer = clock.Pacer(path);
        clock.Advance(133); // Satisfy this new process's monotonic startup guard.
        try { pacer.Reserve(Target, new[] { Address }); Console.WriteLine("GRANTED"); return 0; }
        catch (TopicWaitException) { Console.WriteLine("WAIT"); return 0; }
    }
    private static Process StartChild(string path) {
        var start = new ProcessStartInfo(Environment.ProcessPath!) {
            UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true
        };
        if (Path.GetFileNameWithoutExtension(start.FileName).Equals("dotnet", StringComparison.OrdinalIgnoreCase))
            start.ArgumentList.Add(Assembly.GetExecutingAssembly().Location);
        start.ArgumentList.Add("--pacing-child"); start.ArgumentList.Add(path);
        return Process.Start(start) ?? throw new Exception("Pacing child did not start");
    }
    private static string FinishChild(Process child) {
        if (!child.WaitForExit(10000)) { child.Kill(); throw new Exception("Pacing child timed out"); }
        var output = child.StandardOutput.ReadToEnd().Trim();
        if (child.ExitCode != 0) throw new Exception("Pacing child failed: " + child.StandardError.ReadToEnd());
        return output;
    }

    public static async Task<int> Run(string root) {
        var assertions = 0;
        void Require(bool condition, string why) { assertions++; if (!condition) throw new Exception(why); }
        int Wait(Action action) {
            try { action(); } catch (TopicWaitException wait) { assertions++; return wait.Seconds; }
            throw new Exception("Early request was allowed");
        }
        void Refuse(Action action) {
            try { action(); } catch (TopicPacingException error) when (error is not TopicWaitException) { assertions++; return; }
            throw new Exception("Invalid pacing state accepted");
        }
        string Scope() => Path.Combine(root, "pacing-" + Guid.NewGuid().ToString("N"));
        var path = Scope(); var clock = new Clock(); var pacer = clock.Pacer(path);
        pacer.Check(Target); pacer.Reserve(Target, new[] { Address });
        Require(Wait(() => pacer.Check(Target)) == 137, "Reservation did not include bounded IO/clock margin");
        var otherProvider = ServerCatalog.Candidates("Civ13.com")[0];
        pacer.Check(otherProvider);
        Require(Wait(() => pacer.Reserve(otherProvider, new[] { Address })) == 137, "DNS alias/provider bypassed endpoint spacing");
        pacer.Reserve(Target with { Port = 1715 }, new[] { Address });
        Require(Wait(() => pacer.Check(Target with { Port = 1715 })) == 137, "Configured other port was not tracked");
        clock.Advance(136); Require(Wait(() => pacer.Check(Target)) == 1, "Boundary opened early");
        clock.Advance(1); pacer.Check(Target); assertions++;
        var restarted = clock.Pacer(path);
        Require(Wait(() => restarted.Check(Target)) == 133, "Restart lost monotonic quarantine");
        clock.Advance(133); restarted.Reserve(Target, new[] { Address }); assertions++;

        var rollbackClock = new Clock(); var rollback = rollbackClock.Pacer(Scope()); rollback.Reserve(Target, new[] { Address });
        rollbackClock.Utc = rollbackClock.Utc.AddSeconds(-3); Refuse(() => rollback.Check(Target));
        var forwardClock = new Clock(); var forward = forwardClock.Pacer(Scope()); forward.Reserve(Target, new[] { Address });
        forwardClock.Utc = forwardClock.Utc.AddSeconds(3); Refuse(() => forward.Check(Target));
        var resetClock = new Clock(); var reset = resetClock.Pacer(Scope()); reset.Check(Target);
        resetClock.Tick = -1; Refuse(() => reset.Check(Target));
        // Full allowed drift swing is -2s at reservation to +2s at the next check.
        // 137s reservation -4s drift -3s possible prior write window retains 130s.
        var driftClock = new Clock(); var drift = driftClock.Pacer(Scope());
        driftClock.Utc = Epoch.AddSeconds(-2); drift.Reserve(Target, new[] { Address });
        driftClock.Tick = 132000; driftClock.Utc = Epoch.AddSeconds(134);
        Require(Wait(() => drift.Check(Target)) == 1, "Clock drift consumed the wire-spacing margin");
        driftClock.Tick = 133000; driftClock.Utc = Epoch.AddSeconds(135); drift.Check(Target); assertions++;

        foreach (var corrupt in new[] { "", "{", new string('x', 32769), "{\"Schema\":1,\"Schema\":1,\"Entries\":[]}",
            "{\"Schema\":1,\"Entries\":[],\"Other\":1}", "{\"Schema\":2,\"Entries\":[]}" }) {
            var brokenPath = Scope(); var broken = new Clock().Pacer(brokenPath); broken.Check(Target);
            File.WriteAllText(Path.Combine(brokenPath, "requests.json"), corrupt);
            Refuse(() => broken.Check(Target));
            Require(File.ReadAllText(Path.Combine(brokenPath, "requests.json")) == corrupt, "Corrupt state was silently reset");
        }
        var missingPath = Scope(); var missing = new Clock().Pacer(missingPath); missing.Check(Target);
        File.Delete(Path.Combine(missingPath, "requests.json")); Refuse(() => missing.Check(Target));
        var orphanPath = Scope(); var orphan = new Clock().Pacer(orphanPath); orphan.Check(Target);
        File.Delete(Path.Combine(orphanPath, "requests.lock")); Refuse(() => orphan.Check(Target));
        Require(!File.Exists(Path.Combine(orphanPath, "requests.lock")), "Missing lock was silently recreated beside old state");
        var linkedIdentityPath = Scope(); var identity = new Clock().Pacer(linkedIdentityPath); identity.Reserve(Target, new[] { Address });
        var statePath = Path.Combine(linkedIdentityPath, "requests.json");
        var original = File.ReadAllText(statePath);
        foreach (var mutation in new Action<JsonObject>[] {
            entry => entry["Port"] = 1716,
            entry => entry["Addresses"] = new JsonArray("127.0.0.1"),
            entry => entry["NotBefore"] = Epoch.AddSeconds(1).ToString("O"),
            entry => entry["ReservedAt"] = Epoch.ToOffset(TimeSpan.FromHours(1)).ToString("O") }) {
            var doc = JsonNode.Parse(original)!.AsObject(); mutation(doc["Entries"]![0]!.AsObject());
            File.WriteAllText(statePath, doc.ToJsonString()); Refuse(() => identity.Check(Target));
        }
        File.WriteAllText(statePath, original);
        var ioPath = Scope(); File.WriteAllText(ioPath, "not a directory"); Refuse(() => new Clock().Pacer(ioPath).Check(Target));
        Refuse(() => new TopicPacer("relative-spacing"));
        Refuse(() => new TopicPacer("\\\\example.invalid\\spacing")); // Syntactic refusal; no network access.
        var linkSkips = 0;
        foreach (var dangling in new[] { false, true }) {
            var linkPath = Scope(); Directory.CreateDirectory(linkPath); var linked = new Clock().Pacer(linkPath);
            var linkedState = Path.Combine(linkPath, "requests.json");
            var ownedTarget = Path.Combine(root, "link-state-" + Guid.NewGuid().ToString("N") + ".json");
            if (!dangling) File.WriteAllText(ownedTarget, "{\"Schema\":1,\"Entries\":[]}");
            try {
                try { File.CreateSymbolicLink(linkedState, ownedTarget); }
                catch (Exception error) when (error is UnauthorizedAccessException or PlatformNotSupportedException ||
                    error is IOException io && (io.HResult & 0xffff) is 1314 or 50) { linkSkips++; continue; }
                Refuse(() => linked.Check(Target));
                Require((File.GetAttributes(linkedState) & FileAttributes.ReparsePoint) != 0, "Linked state was replaced instead of refused");
                Require(!File.Exists(Path.Combine(linkPath, "requests.lock")), "Linked state was not refused before initialization");
            } finally { File.Delete(linkedState); if (File.Exists(ownedTarget)) File.Delete(ownedTarget); }
        }
        var directoryLink = Scope(); var ownedDirectory = Scope(); Directory.CreateDirectory(ownedDirectory);
        try {
            var supported = true;
            try { Directory.CreateSymbolicLink(directoryLink, ownedDirectory); }
            catch (Exception error) when (error is UnauthorizedAccessException or PlatformNotSupportedException ||
                error is IOException io && (io.HResult & 0xffff) is 1314 or 50) { supported = false; linkSkips++; }
            if (supported) Refuse(() => new Clock().Pacer(directoryLink).Check(Target));
        } finally {
            // Both link and target are uniquely owned beneath this test root.
            if (Directory.Exists(directoryLink)) Directory.Delete(directoryLink);
        }
        if (linkSkips != 0) Console.WriteLine($"SKIP: {linkSkips} linked-state controls need existing symlink support; no permissions changed.");

        var childPath = Scope(); var childClock = new Clock(); var parentPacer = childClock.Pacer(childPath);
        parentPacer.Reserve(Target, new[] { Address });
        using (var first = StartChild(childPath)) using (var second = StartChild(childPath)) {
            var outcomes = new[] { FinishChild(first), FinishChild(second) };
            Require(outcomes.Count(item => item == "GRANTED") == 1 && outcomes.Count(item => item == "WAIT") == 1,
                "Separate processes both obtained a request slot");
        }
        using (var held = new FileStream(Path.Combine(childPath, "requests.lock"), FileMode.Open, FileAccess.ReadWrite, FileShare.None))
            using (var blocked = StartChild(childPath)) Require(FinishChild(blocked) == "WAIT", "Existing process lock was bypassed");

        var wirePath = Scope(); var wireClock = new Clock(); var wirePacer = wireClock.Pacer(wirePath);
        var attempts = 0; var writes = 0;
        var alternative = IPAddress.Parse("192.64.119.81");
        var verified = await ByondStatus.Query(Target, _ => Task.FromResult(new[] { Address, alternative }),
            (ip, _, beforeWrite, _) => {
                attempts++;
                if (ip.Equals(alternative)) throw new System.Net.Sockets.SocketException((int)System.Net.Sockets.SocketError.ConnectionRefused);
                beforeWrite(); writes++; return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet());
            }, () => wireClock.Utc, pacer: wirePacer);
        Require(attempts == 2 && writes == 1 && verified.Status.Target == Target, "Pre-write connect failure did not safely fail over");
        var dns = 0;
        try {
            await ByondStatus.Query(Target, _ => { dns++; return Task.FromResult(new[] { Address }); },
                (_, _, beforeWrite, _) => { beforeWrite(); writes++; return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet()); },
                () => wireClock.Utc, pacer: wirePacer);
            throw new Exception("Early recheck ran");
        } catch (TopicWaitException) { Require(dns == 0 && writes == 1, "Deferred recheck reached DNS or wire"); }
        wireClock.Advance(137);
        var fresh = await ByondStatus.Query(Target, _ => { dns++; return Task.FromResult(new[] { Address }); },
            (_, _, beforeWrite, _) => { beforeWrite(); writes++; return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet()); },
            () => wireClock.Utc, expected: verified.Status, pacer: wirePacer);
        Require(dns == 1 && writes == 2 && fresh.Status.CheckedAt == wireClock.Utc, "Eligible prejoin reused old status/DNS");
        var badClock = new Clock(); var badPacer = badClock.Pacer(Scope()); var badWrites = 0;
        try {
            await ByondStatus.Query(Target, _ => Task.FromResult(new[] { Address, alternative }),
                (_, _, beforeWrite, _) => { beforeWrite(); badWrites++; return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet("{}")); },
                () => badClock.Utc, pacer: badPacer);
            throw new Exception("Malformed status accepted");
        } catch (TopicWaitException) { Require(badWrites == 1, "Written malformed response caused another Topic write"); }
        using (var cancellation = new CancellationTokenSource()) {
            cancellation.Cancel(); var cancelledDns = 0;
            try {
                await ByondStatus.Query(Target, _ => { cancelledDns++; return Task.FromResult(new[] { Address }); },
                    (_, _, beforeWrite, _) => { beforeWrite(); throw new Exception("Cancelled write"); },
                    () => badClock.Utc, cancellationToken: cancellation.Token, pacer: badPacer);
                throw new Exception("Cancelled probe ran");
            } catch (IOException) { Require(cancelledDns == 0, "Cancellation opened DNS/work"); }
        }

        var checks = 0; var launches = 0;
        var ui = new DiscoveryFixture(_ => Task.FromResult(new ServerSnapshot(new[] { verified.Status }, 0)), _ => {
            checks++; throw new TopicWaitException(TimeSpan.FromSeconds(130));
        });
        using var output = new StringWriter();
        await ServerBrowser.Run("ValZarGaming", ui, new StringReader("1\nJ\nB\n"), output, _ => { launches++; return Task.CompletedTask; });
        Require(checks == 2 && launches == 0 && output.ToString().Contains("Wait 130 seconds") && output.ToString().Contains("B to cancel") &&
            output.ToString().Contains("No automatic check"), "Waiting UI hid delay, lost cancellation, or auto-launched");
        await Task.Delay(10); Require(checks == 2 && launches == 0, "Back left a deferred callback running");
        var paused = await new ServerDiscovery(_ => throw new TopicPacingException("injected local state failure")).Fetch("ValZarGaming");
        using (var pausedOutput = new StringWriter()) {
            ServerBrowser.WriteServers(pausedOutput, "ValZarGaming", paused);
            Require(paused.PacingPaused && paused.Unverified == 0 && pausedOutput.ToString().Contains("local timing state needs review") &&
                !pausedOutput.ToString().Contains("unreachable"), "Local pacing failure was mislabeled remote offline");
        }
        var deferred = await new ServerDiscovery(_ => throw new TopicWaitException(TimeSpan.FromSeconds(137))).Fetch("ValZarGaming");
        Require(deferred.Deferred?.Count == 2 && deferred.Unverified == 0 && !deferred.PacingPaused,
            "Locally deferred candidates were mislabeled unreachable");
        var inputCount = 0; var freshDns = 0; var dispatched = "";
        var changingInput = new SteppedInput(() => {
            inputCount++;
            if (inputCount == 1) return "1";
            if (inputCount == 2) { wireClock.Advance(137); return "J"; }
            return "B";
        });
        var resumed = new DiscoveryFixture(_ => Task.FromResult(new ServerSnapshot(new[] { verified.Status }, 0)), selected =>
            ByondStatus.Query(selected.Target, _ => { freshDns++; return Task.FromResult(new[] { IPAddress.Parse("8.8.8.8") }); },
                (_, _, beforeWrite, _) => { beforeWrite(); return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet()); },
                () => wireClock.Utc, expected: selected, pacer: wirePacer));
        await ServerBrowser.Run("ValZarGaming", resumed, changingInput, TextWriter.Null, checkedServer => {
            dispatched = ServerCatalog.NativeStart(checkedServer, root, Civ13.Launcher.Program.RequiredByond(), _ => true, wireClock.Utc).ArgumentList.Single();
            return Task.CompletedTask;
        });
        Require(inputCount == 2 && freshDns == 1 && dispatched == "byond://8.8.8.8:1714",
            "Resumed J selection did not require fresh DNS/status/literal and unchanged port");
        Console.WriteLine($"PASS: {assertions} shared Topic pacing, process, clock, corruption, wire and cancellation controls.");
        return assertions;
    }
}
internal sealed class SteppedInput(Func<string?> read) : TextReader {
    public override string? ReadLine() => read();
}
