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
    public static int Child(string path, bool cached = false) {
        var clock = new Clock { Utc = Epoch.AddSeconds(137), Tick = 137000 };
        if (cached) { clock.Utc = Epoch.AddSeconds(15); clock.Tick = 15000; }
        var pacer = clock.Pacer(path);
        if (cached) {
            try { pacer.Check(Target); throw new Exception("Child did not retain cooldown"); }
            catch (TopicWaitException wait) { Console.WriteLine($"CACHED:{wait.Cached?.Server?.Players}:{wait.Cached?.AgeSeconds}:{wait.Seconds}"); return 0; }
        }
        try { pacer.Reserve(Target, new[] { Address }); Console.WriteLine("GRANTED"); return 0; }
        catch (TopicWaitException) { Console.WriteLine("WAIT"); return 0; }
    }
    private static Process StartChild(string path, bool cached = false) {
        var start = new ProcessStartInfo(Environment.ProcessPath!) {
            UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true
        };
        if (Path.GetFileNameWithoutExtension(start.FileName).Equals("dotnet", StringComparison.OrdinalIgnoreCase))
            start.ArgumentList.Add(Assembly.GetExecutingAssembly().Location);
        start.ArgumentList.Add(cached ? "--pacing-cache-child" : "--pacing-child"); start.ArgumentList.Add(path);
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
        restarted.Check(Target); assertions++;
        restarted.Reserve(Target, new[] { Address });
        var restartedAgain = clock.Pacer(path);
        Require(Wait(() => restartedAgain.Check(Target)) == 137, "Restart shortened an active reservation");
        clock.Advance(100);
        Require(Wait(() => clock.Pacer(path).Check(Target)) == 37, "Restart added a new full startup wait");
        clock.Advance(37); clock.Pacer(path).Check(Target); assertions++;
        var emptyPath = Scope(); new Clock().Pacer(emptyPath).Check(Target);
        new Clock().Pacer(emptyPath).Reserve(Target, new[] { Address }); assertions++;
        var unrelated = new Clock(); var unrelatedPacer = unrelated.Pacer(Scope());
        unrelatedPacer.Reserve(Target, new[] { Address });
        unrelatedPacer.Check(otherProvider); assertions++;
        var rebootPath = Scope(); var beforeReboot = new Clock { Tick = 900000 };
        beforeReboot.Pacer(rebootPath).Reserve(Target, new[] { Address });
        var afterReboot = new Clock { Utc = Epoch.AddSeconds(10), Tick = 1000 };
        var rebooted = afterReboot.Pacer(rebootPath);
        Require(Wait(() => rebooted.Check(Target)) == 132, "Lower post-reboot uptime skipped conservative fallback");
        afterReboot.Advance(100);
        Require(Wait(() => afterReboot.Pacer(rebootPath).Check(Target)) == 32, "Restart extended the boot recovery wait");
        afterReboot.Advance(32); afterReboot.Pacer(rebootPath).Check(Target); assertions++;
        var largerUptime = new Clock { Utc = Epoch.AddSeconds(2000), Tick = 2000000 };
        largerUptime.Pacer(rebootPath).Check(Target); assertions++;
        var legacyPath = Scope(); var legacyClock = new Clock(); var legacyPacer = legacyClock.Pacer(legacyPath);
        legacyPacer.Reserve(Target, new[] { Address });
        var legacyStatePath = Path.Combine(legacyPath, "requests.json");
        var legacyState = JsonNode.Parse(File.ReadAllText(legacyStatePath))!.AsObject(); legacyState["Schema"] = 1;
        foreach (var legacyEntry in legacyState["Entries"]!.AsArray()) {
            legacyEntry!.AsObject().Remove("ReservedTick"); legacyEntry.AsObject().Remove("RequestId"); legacyEntry.AsObject().Remove("Result");
        }
        File.WriteAllText(legacyStatePath, legacyState.ToJsonString());
        legacyClock.Advance(1000); var migrated = legacyClock.Pacer(legacyPath);
        Require(Wait(() => migrated.Check(Target)) == 133, "Legacy wall-only history bypassed migration guard");
        migrated.Check(otherProvider); assertions++;
        Require(Wait(() => migrated.Reserve(otherProvider, new[] { Address })) == 133, "DNS alias bypassed the legacy migration wait");
        migrated.Reserve(Target with { Port = 1715 }, new[] { Address });
        var mixedState = JsonNode.Parse(File.ReadAllText(legacyStatePath))!;
        Require(mixedState["Schema"]!.GetValue<int>() == 2 && mixedState["Entries"]!.AsArray().Any(item => item!["ReservedTick"] == null),
            "New unrelated request discarded legacy history during mixed-schema migration");
        Require(Wait(() => legacyClock.Pacer(legacyPath).Check(Target with { Port = 1715 })) == 137,
            "Mixed legacy history altered the anchored endpoint's real cooldown");
        legacyClock.Advance(133); migrated.Reserve(Target, new[] { Address });
        Require(JsonNode.Parse(File.ReadAllText(legacyStatePath))!["Schema"]!.GetValue<int>() == 2, "Legacy reservation was not migrated safely");
        var forwardRestartPath = Scope(); var restartClock = new Clock(); restartClock.Pacer(forwardRestartPath).Reserve(Target, new[] { Address });
        restartClock.Utc = Epoch.AddDays(1);
        Require(Wait(() => restartClock.Pacer(forwardRestartPath).Check(Target)) == 137, "Between-process wall step bypassed monotonic history");

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
        Require(Wait(() => drift.Check(Target)) == 5, "Clock drift consumed the wire-spacing margin");
        driftClock.Tick = 137000; driftClock.Utc = Epoch.AddSeconds(139); drift.Check(Target); assertions++;
        var cumulativePath = Scope(); var cumulativeClock = new Clock(); var cumulative = cumulativeClock.Pacer(cumulativePath);
        cumulative.Reserve(Target, new[] { Address });
        var cumulativeState = File.ReadAllText(Path.Combine(cumulativePath, "requests.json"));
        for (var step = 1; step <= 2; step++) {
            cumulativeClock.Utc = Epoch.AddSeconds(step);
            Require(Wait(() => cumulative.Check(Target)) >= 135, "Early check absorbed cumulative clock drift");
        }
        cumulativeClock.Utc = Epoch.AddSeconds(3); Refuse(() => cumulative.Check(Target));
        Require(File.ReadAllText(Path.Combine(cumulativePath, "requests.json")) == cumulativeState,
            "Clock drift pause changed the persisted reservation");

        foreach (var corrupt in new[] { "", "{", new string('x', 32769), "{\"Schema\":1,\"Schema\":1,\"Entries\":[]}",
            "{\"Schema\":1,\"Entries\":[],\"Other\":1}", "{\"Schema\":3,\"Entries\":[]}" }) {
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
            entry => entry["ReservedTick"] = -1,
            entry => entry["RequestId"] = null,
            entry => entry["Result"] = new JsonObject { ["CheckedAt"] = Epoch.ToString("O"), ["Json"] = "{\"players\":-1}" },
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
        foreach (var failure in new[] { "malformed", "identity", "read", "socket", "cancelled" }) {
            var failedPath = Scope(); var failedClock = new Clock(); var failedPacer = failedClock.Pacer(failedPath);
            var attemptsAfterFailure = 0; var writesAfterFailure = 0;
            try {
                await ByondStatus.Query(Target, _ => Task.FromResult(new[] { Address, alternative }),
                    (_, _, beforeWrite, _) => {
                        attemptsAfterFailure++; beforeWrite(); writesAfterFailure++;
                        if (failure == "read") throw new IOException("Injected read failure");
                        if (failure == "socket") throw new System.Net.Sockets.SocketException((int)System.Net.Sockets.SocketError.ConnectionReset);
                        if (failure == "cancelled") throw new OperationCanceledException();
                        return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet(failure == "malformed" ? "{}" :
                            "{\"players\":0,\"map_name\":\"Other\",\"map_gamemode\":\"Nomads\",\"game_id\":\"round-27\"}"));
                    }, () => failedClock.Utc, expected: verified.Status, pacer: failedPacer);
                throw new Exception("Failed response accepted: " + failure);
            } catch (IOException error) when (error is not TopicPacingException) {
                Require(attemptsAfterFailure == 1 && writesAfterFailure == 1, "Post-reservation failure dialed another address: " + failure);
            }
            Require(Wait(() => failedPacer.Check(Target)) == 137, "Failed response lost its durable reservation: " + failure);
        }
        var contentionPath = Scope(); var contentionClock = new Clock(); var contentionPacer = contentionClock.Pacer(contentionPath);
        FileStream? competingOwner = null; var contendedWrites = 0;
        var contendedUi = new DiscoveryFixture(_ => Task.FromResult(new ServerSnapshot(new[] { verified.Status }, 0)), selected =>
            ByondStatus.Query(selected.Target, _ => Task.FromResult(new[] { Address, alternative }),
                (_, _, beforeWrite, _) => {
                    beforeWrite(); contendedWrites++;
                    competingOwner = new FileStream(Path.Combine(contentionPath, "requests.lock"), FileMode.Open, FileAccess.ReadWrite, FileShare.None);
                    return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet("{}"));
                }, () => contentionClock.Utc, expected: selected, pacer: contentionPacer));
        try {
            using var contendedOutput = new StringWriter();
            await ServerBrowser.Run("ValZarGaming", contendedUi, new StringReader("1\nJ\n1\nB\n"), contendedOutput,
                _ => throw new Exception("Malformed contended result launched"));
            Require(contendedWrites == 1 && contendedOutput.ToString().Contains("could not be verified") &&
                !contendedOutput.ToString().Contains("Press J when ready"), "Failure cache contention hid verification failure or retained selection");
        } finally { competingOwner?.Dispose(); }
        Require(Wait(() => contentionPacer.Check(Target)) == 137, "Failure cache contention lost the durable reservation");

        var successPath = Scope(); var successClock = new Clock(); var successPacer = successClock.Pacer(successPath);
        FileStream? cacheOwner = null;
        try {
            var uncachedSuccess = await ByondStatus.Query(Target, _ => Task.FromResult(new[] { Address }),
                (_, _, beforeWrite, _) => {
                    beforeWrite();
                    cacheOwner = new FileStream(Path.Combine(successPath, "requests.lock"), FileMode.Open, FileAccess.ReadWrite, FileShare.None);
                    return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet());
                }, () => successClock.Utc, pacer: successPacer);
            Require(uncachedSuccess.Status.Players == 0, "Display cache contention invalidated a fresh successful verification");
        } finally { cacheOwner?.Dispose(); }
        Require(Wait(() => successPacer.Check(Target)) == 137, "Successful cache contention lost its reservation");

        var invalidClock = new Clock(); var invalidPacer = invalidClock.Pacer(Scope()); var invalidAttempts = 0;
        var invalidDiscovery = new ServerDiscovery(candidate => ByondStatus.Query(candidate,
            _ => Task.FromResult(new[] { Address, alternative }), (_, _, beforeWrite, _) => {
                invalidAttempts++; beforeWrite(); return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet("{}"));
            }, () => invalidClock.Utc, pacer: invalidPacer));
        var invalidSnapshot = await invalidDiscovery.Fetch("ValZarGaming");
        Require(invalidSnapshot.Unverified == 2 && invalidSnapshot.Deferred?.Count == 0 && !invalidSnapshot.PacingPaused &&
            invalidAttempts == 2, "Malformed responses were displayed as waiting or dialed a second address");
        var cachedInvalid = await invalidDiscovery.Fetch("ValZarGaming");
        Require(invalidAttempts == 2 && cachedInvalid.Deferred?.Count == 2 && cachedInvalid.Deferred.All(item => item.Cached is { Server: null }),
            "Failed query result was not retained without another request");
        var identityClock = new Clock(); var identityPacer = identityClock.Pacer(Scope()); var identityChecks = 0; var identityAttempts = 0;
        var changedIdentity = new DiscoveryFixture(_ => Task.FromResult(new ServerSnapshot(new[] { verified.Status }, 0)), selected => {
            identityChecks++;
            return ByondStatus.Query(selected.Target, _ => Task.FromResult(new[] { Address, alternative }),
                (_, _, beforeWrite, _) => {
                    identityAttempts++; beforeWrite();
                    return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet("{\"players\":0,\"game_id\":\"changed\"}"));
                }, () => identityClock.Utc, expected: selected, pacer: identityPacer);
        });
        using (var identityOutput = new StringWriter()) {
            await ServerBrowser.Run("ValZarGaming", changedIdentity, new StringReader("1\nJ\n1\nB\n"), identityOutput,
                _ => throw new Exception("Changed identity launched"));
            Require(identityChecks == 1 && identityAttempts == 1 && identityOutput.ToString().Contains("could not be verified") &&
                !identityOutput.ToString().Contains("Press J when ready"), "Changed identity retained a deferred/selectable prejoin");
        }
        var badClock = new Clock(); var badPacer = badClock.Pacer(Scope());
        using (var cancellation = new CancellationTokenSource()) {
            cancellation.Cancel(); var cancelledDns = 0;
            try {
                await ByondStatus.Query(Target, _ => { cancelledDns++; return Task.FromResult(new[] { Address }); },
                    (_, _, beforeWrite, _) => { beforeWrite(); throw new Exception("Cancelled write"); },
                    () => badClock.Utc, cancellationToken: cancellation.Token, pacer: badPacer);
                throw new Exception("Cancelled probe ran");
            } catch (IOException) { Require(cancelledDns == 0, "Cancellation opened DNS/work"); }
        }

        var metadataPath = Scope(); var metadataClock = new Clock(); var metadataPacer = metadataClock.Pacer(metadataPath);
        var maximumMap = new string('é', 64); var maximumMode = new string('m', 80);
        var metadataJson = System.Text.Json.JsonSerializer.Serialize(new { players = 10000, map_name = maximumMap,
            map_gamemode = maximumMode, map_age = new string('e', 32), game_id = new string('i', 80), round_duration_in_ticks = int.MaxValue });
        await ByondStatus.Query(Target, _ => Task.FromResult(new[] { Address }),
            (_, _, beforeWrite, _) => { beforeWrite(); return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet(metadataJson)); },
            () => metadataClock.Utc, pacer: metadataPacer);
        try { metadataClock.Pacer(metadataPath).Check(Target); } catch (TopicWaitException wait) {
            Require(wait.Cached?.Server is { Players: 10000, RoundDurationSeconds: 214748364 } maximum &&
                maximum.Map == maximumMap && maximum.Mode == maximumMode && maximum.Epoch.Length == 32 && maximum.RoundId.Length == 80,
                "Maximum valid metadata was lost or changed in cache serialization");
        }
        Require(new FileInfo(Path.Combine(metadataPath, "requests.json")).Length < 32768, "Cache exceeded bounded state size");

        // Actual restart: cached valid zero-player status is displayed without DNS or Topic.
        var cachePath = Scope(); var cacheClock = new Clock(); var cachePacer = cacheClock.Pacer(cachePath);
        var cacheWrites = 0; var cacheDns = 0;
        async Task<VerifiedGameServer> CachedQuery(TopicPacer pacing, GameTarget candidate, GameServer? expected = null, string? packetJson = null) =>
            await ByondStatus.Query(candidate, _ => { cacheDns++; return Task.FromResult(new[] { Address }); },
                (_, _, beforeWrite, _) => { beforeWrite(); cacheWrites++; return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet(packetJson)); },
                () => cacheClock.Utc, expected: expected, pacer: pacing);
        var cachedValid = await CachedQuery(cachePacer, Target);
        using (var cachedChild = StartChild(cachePath, cached: true))
            Require(FinishChild(cachedChild) == "CACHED:0:15:122", "Separate process could not reuse the persisted result and remaining cooldown");
        cacheClock.Advance(15);
        var newProcess = cacheClock.Pacer(cachePath);
        TopicWaitException cachedWait;
        try { newProcess.Check(Target); throw new Exception("Restart ignored cooldown"); }
        catch (TopicWaitException wait) { cachedWait = wait; }
        Require(cachedWait.Seconds == 122 && cachedWait.Cached?.Server?.Players == 0 && cachedWait.Cached.AgeSeconds == 15,
            "Restart did not retain exact cooldown and cached zero-player status/age");
        var cachedDiscovery = new ServerDiscovery(candidate => CachedQuery(newProcess, candidate));
        var cachedSnapshot = await cachedDiscovery.Fetch("ValZarGaming");
        Require(cachedSnapshot.Servers.Any(item => item.Target == Target && item.Players == 0) && cacheWrites == 2 && cacheDns == 2,
            "Cached restart performed another request on its cooling-down endpoint");
        using (var cacheOutput = new StringWriter()) {
            ServerBrowser.WriteServers(cacheOutput, "ValZarGaming", cachedSnapshot);
            Require(cacheOutput.ToString().Contains("Cached last verified status (15 seconds old)") && cacheOutput.ToString().Contains("Players: 0") &&
                cacheOutput.ToString().Contains("fresh verification required"), "Cache menu hid age or implied current verification");
        }
        cacheClock.Advance(122);
        var freshAfterCache = await CachedQuery(cacheClock.Pacer(cachePath), Target, cachedValid.Status);
        Require(freshAfterCache.Status.CheckedAt == cacheClock.Utc && cacheWrites == 3, "Expired cache cooldown added startup guard or reused old dispatch token");
        cacheClock.Advance(15);
        var staleRequestId = cachePacer.Reserve(Target with { Port = 1715 }, new[] { Address });
        cacheClock.Advance(137);
        var newestRequestId = cachePacer.Reserve(Target with { Port = 1715 }, new[] { Address });
        cachePacer.Record(Target with { Port = 1715 }, staleRequestId, null);
        try { cachePacer.Check(Target with { Port = 1715 }); } catch (TopicWaitException wait) {
            Require(wait.Cached == null, "Late prior completion overwrote a newer reservation");
        }
        cachePacer.Record(Target with { Port = 1715 }, newestRequestId, null);
        try { cacheClock.Pacer(cachePath).Check(Target with { Port = 1715 }); } catch (TopicWaitException wait) {
            Require(wait.Cached is { Server: null, AgeSeconds: 0 }, "Failed request did not retain bounded failure result");
        }
        // No cached address or VerifiedGameServer exists; fresh mismatched identity still fails closed.
        cacheClock.Advance(137);
        try {
            await CachedQuery(cacheClock.Pacer(cachePath), Target, cachedValid.Status, "{\"players\":0,\"game_id\":\"different\"}");
            throw new Exception("Cached identity bypassed prejoin");
        } catch (IOException error) when (error is not TopicPacingException) { assertions++; }
        cacheClock.Advance(601);
        // Legacy fallback can defer an old record, but stale results are never shown.
        var staleState = JsonNode.Parse(File.ReadAllText(Path.Combine(cachePath, "requests.json")))!.AsObject();
        foreach (var entry in staleState["Entries"]!.AsArray()) entry!["ReservedTick"] = cacheClock.Tick + 1000000;
        File.WriteAllText(Path.Combine(cachePath, "requests.json"), staleState.ToJsonString());
        try { cacheClock.Pacer(cachePath).Check(Target); } catch (TopicWaitException wait) {
            Require(wait.Cached == null, "Expired cached result was displayed");
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
                !pausedOutput.ToString().Contains("unreachable") && !pausedOutput.ToString().Contains("No verified online"), "Local pacing failure was mislabeled remote offline");
        }
        var deferred = await new ServerDiscovery(_ => throw new TopicWaitException(TimeSpan.FromSeconds(137))).Fetch("ValZarGaming");
        Require(deferred.Deferred?.Count == 2 && deferred.Unverified == 0 && !deferred.PacingPaused,
            "Locally deferred candidates were mislabeled unreachable");
        using (var deferredOutput = new StringWriter()) {
            ServerBrowser.WriteServers(deferredOutput, "ValZarGaming", deferred);
            Require(deferredOutput.ToString().Contains("Current status unknown; no cached result") &&
                !deferredOutput.ToString().Contains("No verified online") && !deferredOutput.ToString().Contains("unreachable"),
                "Deferred unknown endpoints were described as unavailable/offline");
        }
        var failedCache = new CachedStatus(null, Epoch, 12);
        var failedSnapshot = await new ServerDiscovery(_ => throw new TopicWaitException(TimeSpan.FromSeconds(125), failedCache)).Fetch("ValZarGaming");
        using (var failedOutput = new StringWriter()) {
            ServerBrowser.WriteServers(failedOutput, "ValZarGaming", failedSnapshot);
            Require(failedSnapshot.Servers.Count == 0 && failedSnapshot.Unverified == 0 && failedOutput.ToString().Contains("12 seconds ago") &&
                failedOutput.ToString().Contains("current status unknown"), "Cached failed check was shown as current offline or zero-player status");
        }
        var cachedJoins = 0; var cachedRechecks = 0;
        var cachedMenu = new DiscoveryFixture(_ => Task.FromResult(cachedSnapshot), _ => {
            cachedRechecks++; throw new TopicWaitException(TimeSpan.FromSeconds(122));
        });
        await ServerBrowser.Run("ValZarGaming", cachedMenu, new StringReader("1\nB\n"), TextWriter.Null,
            _ => { cachedJoins++; return Task.CompletedTask; });
        Require(cachedRechecks == 1 && cachedJoins == 0, "Cached selectable status bypassed the prejoin cooldown");
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
