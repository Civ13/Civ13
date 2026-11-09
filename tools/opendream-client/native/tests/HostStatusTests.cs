using Civ13.Launcher;
using System.Net;
using System.Text;

// The host doorman (scripts/gaia-host/doorman.py) and the launcher's reader of it.
internal static class HostStatusTests {
    // Frames produced by doorman.frame() for the replies below, so a change on
    // either side of the wire format fails here.
    private const string PythonStatusFrame = "008300c4067b22736368656d61223a312c22696e7374616e636573223a5b7b22706f7274223a313731342c227374617465223a2261736c656570222c2277616b655f657374696d617465223a352c22706c6179657273223a332c226d61705f6e616d65223a2247616961222c226d61705f67616d656d6f6465223a224e6f6d616473222c226361636865645f616765223a3432307d2c7b22706f7274223a313731362c227374617465223a226177616b65222c2277616b655f657374696d617465223a357d5d7d00";
    private const string PythonWakeFrame = "0083003d067b22736368656d61223a312c226f6b223a747275652c22706f7274223a313731342c227374617465223a2277616b696e67222c22657461223a357d00";

    public static byte[] Frame(string json) {
        var body = Encoding.UTF8.GetBytes(json);
        var packet = new byte[body.Length + 6];
        packet[1] = 0x83;
        var length = body.Length + 2;
        packet[2] = (byte)(length >> 8); packet[3] = (byte)length; packet[4] = 0x06;
        body.CopyTo(packet, 5);
        return packet;
    }

    public static async Task<int> Run(string root) {
        var assertions = 0;
        void Require(bool ok, string why) { assertions++; if (!ok) throw new Exception(why); }
        async Task Reject(Func<Task> action, string why) {
            try { await action(); } catch (IOException) { assertions++; return; }
            throw new Exception("Host status negative control accepted: " + why);
        }
        var ip = IPAddress.Parse("72.218.249.221");
        Func<string, Task<IPAddress[]>> resolver = _ => Task.FromResult(new[] { ip });
        var targets = ServerCatalog.Candidates("ValZarGaming");
        var gaia = targets[0];

        // Wire format matches the Python doorman byte for byte.
        var status = Frame("{\"schema\":1,\"instances\":[{\"port\":1714,\"state\":\"asleep\",\"wake_estimate\":5,\"players\":3,\"map_name\":\"Gaia\",\"map_gamemode\":\"Nomads\",\"cached_age\":420},{\"port\":1716,\"state\":\"awake\",\"wake_estimate\":5}]}");
        Require(Convert.ToHexString(status).Equals(PythonStatusFrame, StringComparison.OrdinalIgnoreCase), "Doorman status framing drifted");
        var wakeReply = Frame("{\"schema\":1,\"ok\":true,\"port\":1714,\"state\":\"waking\",\"eta\":5}");
        Require(Convert.ToHexString(wakeReply).Equals(PythonWakeFrame, StringComparison.OrdinalIgnoreCase), "Doorman wake framing drifted");

        var asked = new List<(int Port, string Query)>();
        var reported = await HostStatus.Query("ValZarGaming", resolver, (_, port, query, _) => {
            asked.Add((port, query));
            return Task.FromResult<ReadOnlyMemory<byte>>(status);
        });
        Require(asked.SequenceEqual(new[] { (HostStatus.DoormanPort, "?host_status=1") }), "Status asked the wrong port or query");
        // Port 1716 is not a configured candidate: it is ignored, never offered.
        var sleeping = reported.GetValueOrDefault(gaia) ?? throw new Exception("Asleep instance missing");
        Require(reported.Count == 1 && sleeping.State == "asleep" &&
            sleeping.Players == 3 && sleeping.Map == "Gaia" && sleeping.Mode == "Nomads" && sleeping.CachedAgeSeconds == 420 &&
            sleeping.WakeEstimateSeconds == 5, "Asleep instance misread");

        var state = await HostStatus.Wake(gaia, resolver, (_, port, query, _) => {
            asked.Add((port, query));
            return Task.FromResult<ReadOnlyMemory<byte>>(wakeReply);
        });
        Require(state == "waking" && asked[^1] == (HostStatus.DoormanPort, "?wake=1&port=1714"), "Wake request or reply misread");

        // The first refused address does not end the request.
        var tries = 0;
        await HostStatus.Query("ValZarGaming", _ => Task.FromResult(new[] { ip, IPAddress.Parse("72.218.249.222") }), (_, _, _, _) => {
            if (tries++ == 0) throw new System.Net.Sockets.SocketException(10061);
            return Task.FromResult<ReadOnlyMemory<byte>>(status);
        });
        Require(tries == 2, "Refused doorman address was not skipped");

        foreach (var bad in new[] { "[]", "{}", "{\"schema\":2,\"instances\":[]}", "{\"schema\":1}", "{\"schema\":1,\"instances\":{}}",
            "{\"schema\":1,\"instances\":[1]}", "{\"schema\":1,\"instances\":[{\"state\":\"asleep\"}]}",
            "{\"schema\":1,\"instances\":[{\"port\":1714,\"state\":\"dreaming\"}]}",
            "{\"schema\":1,\"instances\":[{\"port\":1714,\"state\":\"asleep\",\"players\":-1}]}",
            "{\"schema\":1,\"instances\":[{\"port\":1714,\"state\":\"asleep\",\"wake_estimate\":601}]}",
            "{\"schema\":1,\"instances\":[{\"port\":1714,\"state\":\"asleep\",\"map_name\":\"bad\\u202e\"}]}",
            "{\"schema\":1,\"instances\":[{\"port\":1714,\"state\":\"asleep\"},{\"port\":1714,\"state\":\"awake\"}]}",
            "{\"schema\":1,\"schema\":1,\"instances\":[]}" })
            await Reject(() => HostStatus.Query("ValZarGaming", resolver, (_, _, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(Frame(bad))), "bad status " + bad);
        var broken = (byte[])status.Clone();
        broken[4] = 0x2a;
        await Reject(() => HostStatus.Query("ValZarGaming", resolver, (_, _, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(broken)), "non-text reply");
        foreach (var bad in new[] { "{\"schema\":1,\"ok\":false,\"error\":\"unknown port\"}", "{\"schema\":1,\"ok\":true,\"port\":1715,\"state\":\"awake\"}",
            "{\"schema\":1,\"ok\":true,\"port\":1714}" })
            await Reject(() => HostStatus.Wake(gaia, resolver, (_, _, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(Frame(bad))), "bad wake " + bad);
        try {
            await HostStatus.Wake(gaia, resolver, (_, _, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(
                Frame("{\"schema\":1,\"ok\":false,\"error\":\"low memory\",\"port\":1714,\"free_mb\":700,\"need_mb\":1024}")));
            throw new Exception("Low-memory wake refusal accepted");
        } catch (IOException refusal) {
            Require(refusal.Message == gaia.Name + " cannot wake right now: its host is low on free memory (700 MB free, 1024 MB needed). Try again later.",
                "Low-memory refusal message changed: " + refusal.Message);
        }
        try {
            await HostStatus.Wake(gaia, resolver, (_, _, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(
                Frame("{\"schema\":1,\"ok\":false,\"error\":\"byond signed out\",\"port\":1714}")));
            throw new Exception("Signed-out wake refusal accepted");
        } catch (IOException refusal) {
            Require(refusal.Message == gaia.Name + " cannot start right now: its host is still signing in to BYOND. Try again in a minute.",
                "Signed-out refusal message changed: " + refusal.Message);
        }
        await Reject(() => HostStatus.Wake(new GameTarget("ValZarGaming", 1716), resolver,
            (_, _, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(wakeReply)), "unconfigured wake target");

        // Discovery: a sleeping target is listed from the doorman and never queried directly.
        var now = DateTimeOffset.Parse("2026-11-05T12:00:00Z");
        var queried = new List<GameTarget>();
        Task<VerifiedGameServer> Direct(GameTarget target) {
            queried.Add(target);
            return ByondStatus.Query(target, resolver, (_, _, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(
                ByondStatusTests.Packet("{\"players\":1,\"map_name\":\"Gaia\"}")), () => now);
        }
        var hostStates = new Dictionary<GameTarget, DormantServer> { [gaia] = sleeping };
        var snapshot = await new ServerDiscovery(Direct, _ => Task.FromResult<IReadOnlyDictionary<GameTarget, DormantServer>>(hostStates)).Fetch("ValZarGaming");
        Require(queried.SequenceEqual(new[] { targets[1] }) && snapshot.Servers.Count == 1 && snapshot.Dormant?.Single() == sleeping,
            "Browsing queried a sleeping server or dropped it");
        // A world behind the routing relay is joined through the gate only: not listed, not queried.
        queried.Clear();
        var routedFrame = Frame("{\"schema\":1,\"instances\":[{\"port\":1714,\"state\":\"asleep\",\"routed\":true},{\"port\":1715,\"state\":\"awake\"}]}");
        var routedStates = await HostStatus.Query("ValZarGaming", resolver, (_, _, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(routedFrame));
        Require(routedStates[gaia].Routed && !routedStates[targets[1]].Routed, "Routed flag misread");
        snapshot = await new ServerDiscovery(Direct, _ => Task.FromResult(routedStates)).Fetch("ValZarGaming");
        Require(queried.SequenceEqual(new[] { targets[1] }) && snapshot.Servers.Count == 1 && snapshot.Dormant?.Count == 0,
            "A routed world was listed or queried directly");
        queried.Clear();
        snapshot = await new ServerDiscovery(Direct, _ => throw new IOException("no doorman")).Fetch("ValZarGaming");
        Require(queried.SequenceEqual(new[] { gaia }) && snapshot.Servers.Count == 1 && snapshot.Dormant?.Count == 0,
            "A missing doorman blocked the gate or listed a routed world directly");
        queried.Clear();
        snapshot = await new ServerDiscovery(Direct, _ => throw new IOException("no doorman")).Fetch("Civ13.com");
        Require(queried.Count == 2 && snapshot.Servers.Count == 2, "A missing doorman blocked direct discovery on a host without a gate");
        queried.Clear();
        snapshot = await new ServerDiscovery(Direct).Fetch("ValZarGaming");
        Require(queried.Count == 2, "An injected query alone stopped checking every candidate");

        // Wake and join: wake, poll the doorman until awake, then one direct verification.
        var clock = TimeSpan.Zero;
        var polls = new Queue<string>(["waking", "waking", "awake"]);
        var progress = new List<string>();
        Task<IReadOnlyDictionary<GameTarget, DormantServer>> Poll(string _) =>
            Task.FromResult<IReadOnlyDictionary<GameTarget, DormantServer>>(new Dictionary<GameTarget, DormantServer> { [gaia] = sleeping with { State = polls.Dequeue() } });
        ServerDiscovery Waker(Func<string, Task<IReadOnlyDictionary<GameTarget, DormantServer>>> doorman, string first = "waking") =>
            new(Direct, doorman, _ => Task.FromResult(first), (wait, _) => { clock += wait; return Task.CompletedTask; }, () => clock);
        queried.Clear();
        var verified = await Waker(Poll).WakeAndVerify(sleeping, progress.Add);
        Require(verified.Status.Target == gaia && queried.SequenceEqual(new[] { gaia }) && polls.Count == 0 && clock == TimeSpan.FromSeconds(6),
            "Wake did not poll until awake before one direct verification");
        Require(progress[0] == $"Waking {gaia.Name}..." && progress[^1] == $"Verifying {gaia.Name}...", "Wake progress text changed: " + string.Join(" | ", progress));
        queried.Clear();
        await Reject(() => Waker(_ => Task.FromResult<IReadOnlyDictionary<GameTarget, DormantServer>>(
            new Dictionary<GameTarget, DormantServer> { [gaia] = sleeping with { State = "stopped" } })).WakeAndVerify(sleeping, _ => { }), "stopped while waking");
        await Reject(() => Waker(_ => Task.FromResult<IReadOnlyDictionary<GameTarget, DormantServer>>(
            new Dictionary<GameTarget, DormantServer> { [gaia] = sleeping with { State = "waking" } })).WakeAndVerify(sleeping, _ => { }), "never woke");
        Require(clock > HostStatus.WakeLimit && queried.Count == 0, "A server that never woke was queried or the limit was not enforced");
        await Reject(() => Waker(Poll, "stopped").WakeAndVerify(sleeping, _ => { }), "stopped on wake");
        // A cold host (powered down since the freeze) starts from its save and gets a longer limit.
        clock = TimeSpan.Zero;
        polls = new Queue<string>(Enumerable.Repeat("waking", 100).Append("awake"));
        progress.Clear();
        verified = await Waker(Poll).WakeAndVerify(sleeping with { WakeEstimateSeconds = 300 }, progress.Add);
        Require(verified.Status.Target == gaia && clock == TimeSpan.FromSeconds(202) && progress[0] == $"Starting {gaia.Name}...",
            "A cold start was cut off at the thaw limit or mislabeled");
        clock = TimeSpan.Zero;
        polls = new Queue<string>(Enumerable.Repeat("waking", 200));
        await Reject(() => Waker(Poll).WakeAndVerify(sleeping with { WakeEstimateSeconds = 300 }, _ => { }), "cold start never finished");
        Require(clock > TimeSpan.FromSeconds(360) && clock < TimeSpan.FromSeconds(370), "Cold start limit is not estimate + 60 s");
        queried.Clear();
        await Reject(() => new ServerDiscovery(Direct).WakeAndVerify(sleeping, _ => { }), "no doorman configured");
        Require(queried.Count == 0, "A failed wake reached the game port");
        // Console menu: the asleep server is listed after the live one and choosing it wakes it.
        clock = TimeSpan.Zero;
        polls = new Queue<string>(["awake"]);
        queried.Clear();
        var listed = false;
        var console = Waker(_ => {
            if (listed) return Poll("");
            listed = true;
            return Task.FromResult<IReadOnlyDictionary<GameTarget, DormantServer>>(hostStates);
        });
        var menu = new StringWriter();
        VerifiedGameServer? launched = null;
        await ServerBrowser.Run("ValZarGaming", console, new StringReader("2\n"), menu, game => { launched = game; return Task.CompletedTask; });
        var text = menu.ToString();
        Require(text.Contains("2: " + gaia.Name + " | Asleep") && text.Contains("Last seen: 3 players | Map: Gaia") && text.Contains("7m ago"),
            "Console menu did not list the asleep server: " + text);
        Require(launched?.Status.Target == gaia && queried.SequenceEqual(new[] { targets[1], gaia }), "Console Wake and join did not verify then launch");
        Console.WriteLine($"PASS: {assertions} host doorman status, wake and dormant discovery controls.");
        return assertions;
    }
}
