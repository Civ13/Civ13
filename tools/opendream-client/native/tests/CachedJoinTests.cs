using Civ13.Launcher;
using System.Net;
using System.Net.Sockets;
using System.Text.Json.Nodes;

internal static class CachedJoinTests {
    private static readonly IPAddress Game = IPAddress.Parse("72.218.249.221");
    private static readonly IPAddress Other = IPAddress.Parse("192.64.119.81");
    private sealed class Scene {
        internal readonly GameTarget Target = ServerCatalog.Candidates("ValZarGaming")[0];
        internal readonly string Directory;
        internal DateTimeOffset Now = DateTimeOffset.Parse("2026-10-21T22:00:00Z");
        internal long Tick;
        internal int Writes, Dns, Attempts;
        internal Action? OnDns, OnUtc;
        internal IPAddress[] Answers = [Game, Other];
        internal TopicPacer Pacer;
        internal Scene(string root) {
            Directory = Path.Combine(root, "join-" + Guid.NewGuid().ToString("N"));
            Pacer = NewPacer();
        }
        internal TopicPacer NewPacer() => new(Directory, () => { OnUtc?.Invoke(); return Now; }, () => Tick);
        internal void Advance(int seconds) { Now = Now.AddSeconds(seconds); Tick += seconds * 1000L; }
        internal Task<VerifiedGameServer> Query(GameServer? expected = null) => ByondStatus.Query(Target,
            _ => { Dns++; OnDns?.Invoke(); return Task.FromResult(Answers); },
            (ip, _, beforeWrite, _) => {
                Attempts++;
                if (ip.Equals(Other)) throw new SocketException((int)SocketError.ConnectionRefused);
                beforeWrite(); Writes++;
                return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet());
            }, () => Now, expected: expected, pacer: Pacer);
        internal ServerDiscovery Discovery() => new(candidate => candidate == Target ? Query() : throw new IOException("inactive candidate"));
        internal void Mutate(Action<JsonObject> mutate) {
            var file = Path.Combine(Directory, "requests.json");
            var state = JsonNode.Parse(File.ReadAllText(file))!.AsObject();
            mutate(state["Entries"]![0]!.AsObject()); File.WriteAllText(file, state.ToJsonString());
        }
        internal string State => File.ReadAllText(Path.Combine(Directory, "requests.json"));
        internal string Start(VerifiedGameServer server) => ServerCatalog.NativeStart(server, Directory,
            Civ13.Launcher.Program.RequiredByond(), _ => true, Now).ArgumentList.Single();
    }
    public static async Task<int> Run(string root) {
        var assertions = 0;
        void Require(bool yes, string why) { assertions++; if (!yes) throw new Exception(why); }
        async Task Deny(Func<Task> action, string why, bool waiting = false) {
            try { await action(); } catch (TopicWaitException) when (waiting) { assertions++; return; }
            catch (IOException error) when (!waiting && error is not TopicWaitException) { assertions++; return; }
            throw new Exception("Cached join negative accepted: " + why);
        }
        async Task<int> Menu(Scene scene, TextReader input) {
            var launches = 0; var discovery = scene.Discovery();
            var menu = new DiscoveryFixture(discovery.Fetch, selected => scene.Query(selected));
            await ServerBrowser.Run("ValZarGaming", menu, input, TextWriter.Null, verified => {
                Require(scene.Start(verified) == "byond://72.218.249.221:1714", "Cached join changed actual respondent or configured port");
                launches++; return Task.CompletedTask;
            });
            return launches;
        }
        var first = new Scene(root);
        Require(await Menu(first, new StringReader("1\nB\n")) == 1 && first.Writes == 1 && first.Dns == 2 && first.Attempts == 2,
            "Fresh discovery did not join directly with one Topic and a fresh full DNS lookup");
        var original = first.State; first.Advance(5);
        using (var cachedOutput = new StringWriter()) {
            ServerBrowser.WriteServers(cachedOutput, "ValZarGaming", await first.Discovery().Fetch("ValZarGaming"));
            Require(cachedOutput.ToString().Contains("select it to join now") && cachedOutput.ToString().Contains("5 seconds old"),
                "Cached join UI described a usable recent proof as blocked");
        }
        Require(await Menu(first, new StringReader("1\nB\n")) == 1 && first.Writes == 1 && first.Dns == 3,
            "Validated cached discovery could not join without another Topic");
        first.Advance(5);
        var selected = (await first.Discovery().Fetch("ValZarGaming")).Servers.Single();
        var reused = await first.Query(selected);
        Require(first.Writes == 1 && first.State == original && reused.Status.CheckedAt == selected.CheckedAt,
            "Reuse renewed the reservation, cache timestamp or status age");
        Require(first.Start(reused) == "byond://72.218.249.221:1714", "Multi-address cached join picked first DNS answer");

        foreach (var answers in new[] { new[] { Game, IPAddress.Loopback }, new[] { Game, IPAddress.Parse("192.0.2.1") }, new[] { Other } }) {
            var scene = new Scene(root); var verified = await scene.Query(); scene.Answers = answers;
            await Deny(() => scene.Query(verified.Status), "Unsafe or removed DNS respondent");
            Require(scene.Writes == 1, "Rejected DNS sent another Topic");
        }
        foreach (var changed in new[] {
            "{\"players\":0,\"map_name\":\"Other\",\"map_gamemode\":\"Nomads\",\"game_id\":\"round-27\"}",
            "{\"players\":0,\"map_name\":\"Europe\",\"map_gamemode\":\"Other\",\"game_id\":\"round-27\"}",
            "{\"players\":0,\"map_name\":\"Europe\",\"map_gamemode\":\"Nomads\",\"game_id\":\"other-round\"}" }) {
            var scene = new Scene(root); await scene.Query();
            var selectedOther = ByondStatus.ParsePacket(ByondStatusTests.Packet(changed), scene.Target, scene.Now);
            await Deny(() => scene.Query(selectedOther), "Selected identity differs from recent proof");
            Require(scene.Writes == 1 && scene.Dns == 1, "Identity mismatch reached DNS or Topic");
        }
        var missing = new Scene(root);
        await ByondStatus.Query(missing.Target, _ => Task.FromResult(new[] { Game }),
            (_, _, beforeWrite, _) => { beforeWrite(); return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet("{\"players\":0}")); },
            () => missing.Now, pacer: missing.Pacer);
        var previouslyNamed = ByondStatus.ParsePacket(ByondStatusTests.Packet(), missing.Target, missing.Now);
        await Deny(() => missing.Query(previouslyNamed), "Recent proof lost selected identity fields");
        Require(missing.Dns == 0 && missing.Writes == 0, "Missing selected identity queried another service");
        var cancelled = new Scene(root); var cancelledStatus = await cancelled.Query();
        using (var cancel = new CancellationTokenSource()) {
            await Deny(() => ByondStatus.Query(cancelled.Target, _ => { cancel.Cancel(); return Task.FromResult(new[] { Game }); },
                (_, _, _, _) => throw new Exception("Cancelled cached join sent Topic"), () => cancelled.Now,
                cancellationToken: cancel.Token, expected: cancelledStatus.Status, pacer: cancelled.Pacer), "Cancellation during cached DNS");
        }

        foreach (var mutation in new Action<JsonObject>[] {
            entry => entry["RequestId"] = Guid.NewGuid().ToString(),
            entry => entry["Result"]!["Json"] = null,
            entry => entry["Result"]!["Json"] = "{\"players\":0,\"game_id\":\"changed\"}",
            entry => entry["Addresses"] = new JsonArray(Other.ToString()) }) {
            var scene = new Scene(root); var verified = await scene.Query();
            scene.OnDns = () => scene.Mutate(mutation);
            await Deny(() => scene.Query(verified.Status), "Shared proof replaced during DNS");
            Require(scene.Writes == 1, "Changed proof sent a replacement Topic");
        }
        var paused = new Scene(root); var pausedStatus = await paused.Query();
        File.WriteAllText(Path.Combine(paused.Directory, "requests.json"), "{");
        await Deny(() => paused.Query(pausedStatus.Status), "Memory proof bypassed invalid storage");
        Require(paused.Dns == 1 && paused.Writes == 1, "Invalid storage reached network work");

        foreach (var monotonicExpires in new[] { true, false }) {
            var scene = new Scene(root); var verified = await scene.Query(); scene.Advance(59);
            scene.OnDns = () => { scene.Now = scene.Now.AddSeconds(monotonicExpires ? 1 : 2); scene.Tick += monotonicExpires ? 2000 : 1000; };
            await Deny(() => scene.Query(verified.Status), "Status expired during DNS", waiting: true);
            Require(scene.Writes == 1, "Expired recent status attempted duplicate Topic");
        }
        var dispatch = new Scene(root); var dispatchStatus = await dispatch.Query(); dispatch.Advance(59);
        var dispatchToken = await dispatch.Query(dispatchStatus.Status);
        dispatch.Tick += 2000; dispatch.Now = dispatch.Now.AddSeconds(1); // UTC age60, monotonic age61.
        await Deny(() => Task.Run(() => dispatch.Start(dispatchToken)), "Fresh DNS token extended original monotonic status lifetime");

        var clientDelay = new Scene(root); var clientStatus = await clientDelay.Query(); clientDelay.Advance(59);
        var clientToken = await clientDelay.Query(clientStatus.Status);
        await Deny(() => Task.Run(() => ServerCatalog.NativeStart(clientToken, clientDelay.Directory,
            Civ13.Launcher.Program.RequiredByond(), _ => { clientDelay.Tick += 2000; clientDelay.Now = clientDelay.Now.AddSeconds(1); return true; },
            clientDelay.Now)), "Client-file verification crossed original monotonic freshness boundary");

        var stale = new Scene(root); var staleStatus = await stale.Query(); stale.Advance(61);
        await Deny(() => stale.Query(staleStatus.Status), "Stale proof bypassed real spacing", waiting: true);
        Require(stale.Dns == 1 && stale.Writes == 1, "Stale proof performed early DNS or Topic");
        stale.Advance(76); var rechecked = await stale.Query(staleStatus.Status);
        Require(stale.Writes == 2 && stale.Start(rechecked) == "byond://72.218.249.221:1714", "Eligible stale recheck failed to return directly to launch");

        var restarted = new Scene(root); await restarted.Query(); restarted.Advance(15); restarted.Pacer = restarted.NewPacer();
        var inputCount = 0;
        var input = new SteppedInput(() => { inputCount++; if (inputCount == 1) return "1";
            if (inputCount == 2) { restarted.Advance(122); return "J"; } return "B"; });
        Require(await Menu(restarted, input) == 1 && restarted.Writes == 2 && restarted.Dns == 2 && inputCount == 2,
            "Restarted display-only cache bypassed proof or created an endless refresh/prejoin delay");

        var contended = new Scene(root); FileStream? held = null; var clockCalls = 0;
        var contentionStatus = await ByondStatus.Query(contended.Target, _ => Task.FromResult(new[] { Game }),
            (_, _, beforeWrite, _) => { beforeWrite(); return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet()); },
            () => { clockCalls++; if (clockCalls == 2) held = new FileStream(Path.Combine(contended.Directory, "requests.lock"),
                FileMode.Open, FileAccess.ReadWrite, FileShare.None); return contended.Now; }, pacer: contended.Pacer);
        held!.Dispose();
        Require(contended.Start(await contended.Query(contentionStatus.Status)) == "byond://72.218.249.221:1714" && contended.Writes == 0,
            "Successful in-process proof was lost to display-cache contention");

        var slow = new Scene(root); var responseClockCalls = 0;
        var slowStatus = await ByondStatus.Query(slow.Target, _ => Task.FromResult(new[] { Game }),
            (_, _, beforeWrite, _) => { beforeWrite(); return Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet()); },
            () => { responseClockCalls++; if (responseClockCalls == 2) slow.OnUtc = () => {
                slow.OnUtc = null; slow.Tick += 61000; slow.Now = slow.Now.AddSeconds(59);
            }; return slow.Now; }, pacer: slow.Pacer);
        await Deny(() => Task.Run(() => slow.Start(slowStatus)), "Slow result persistence renewed response age");

        Console.WriteLine($"PASS: {assertions} fresh/cached join, pacing, DNS, identity, expiry and contention controls.");
        return assertions;
    }
}
