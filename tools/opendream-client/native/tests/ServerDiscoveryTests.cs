using Civ13.Launcher;
using System.Net;
using System.Text;
using System.Text.Json;

internal static class ServerDiscoveryTests {
    public static async Task<int> Run(string root) {
        var assertions = 0;
        var now = DateTimeOffset.Parse("2026-10-21T04:00:00Z");
        var target = ServerCatalog.Candidates("ValZarGaming")[0];
        var ip = IPAddress.Parse("72.218.249.221");
        void Require(bool ok, string why) { assertions++; if (!ok) throw new Exception(why); }
        async Task Reject(Func<Task> action, string why) {
            try { await action(); } catch (IOException) { assertions++; return; }
            throw new Exception("Direct discovery negative control accepted: " + why);
        }
        GameServer Parse(string json) => ByondStatus.ParsePacket(ByondStatusTests.Packet(json), target, now);
        Task<VerifiedGameServer> Query(GameTarget candidate, string? json = null, GameServer? expected = null,
            Func<DateTimeOffset>? clock = null) => ByondStatus.Query(candidate, _ => Task.FromResult(new[] { ip }),
                (_, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet(json)), clock ?? (() => now), expected: expected);
        var server = Parse("{\"players\":0,\"map_name\":\"Europe\",\"map_gamemode\":\"Nomads\",\"game_id\":\"round-27\",\"round_duration_in_ticks\":0}");
        foreach (var provider in new[] { "Civ13.com", "ValZarGaming" }) {
            var configured = ServerCatalog.Candidates(provider);
            Require(configured.Select(item => item.Port).SequenceEqual(new[] { 1714, 1715 }), "Known ports changed or a range was introduced");
            Require(configured.All(item => item.Host == ServerCatalog.Host(provider)), "Provider host mismatch");
            foreach (var candidate in configured) candidate.Validate();
        }
        foreach (var bad in new[] { new GameTarget("ValZarGaming", 80), new GameTarget("ValZarGaming", 1716),
            new GameTarget("Civ13.com", 65535), new GameTarget("unknown", 1714) }) {
            var calls = 0;
            await Reject(() => ByondStatus.Query(bad, _ => { calls++; return Task.FromResult(new[] { ip }); }), "unconfigured target");
            Require(calls == 0, "Unconfigured target reached DNS");
        }
        var minimal = Parse("{\"players\":0}");
        Require(minimal.Players == 0 && minimal.Map == "" && minimal.Mode == "" && minimal.RoundId == "" && minimal.RoundDurationSeconds == null,
            "Valid empty world or missing optional metadata mislabeled offline");
        var unicode = Parse("{\"players\":12,\"map_name\":\"Gaia 世界\",\"map_gamemode\":\"Event\",\"map_age\":1200,\"game_id\":42,\"round_duration_in_ticks\":12345.6}");
        Require(unicode.Map == "Gaia 世界" && unicode.Epoch == "1200" && unicode.RoundId == "42" && unicode.RoundDurationSeconds == 1234,
            "Unicode/scalar metadata projection changed");
        foreach (var field in new[] { "map_name", "map_gamemode", "map_age", "game_id", "round_duration_in_ticks" })
            foreach (var invalid in new[] { "null", "true", "[]", "{}" })
                await Reject(() => Task.Run(() => Parse("{\"players\":0,\"" + field + "\":" + invalid + "}")), "present malformed optional field");
        foreach (var bad in new[] { "{}", "[]", "{\"players\":null}", "{\"players\":\"0\"}", "{\"players\":1.5}", "{\"players\":10001}",
            "{\"players\":0,\"players\":0}", "{\"players\":0,\"map_name\":\"Europe\",\"map_name\":\"Other\"}",
            "{\"players\":0,\"game_id\":1.5}", "{\"players\":0,\"map_age\":1.5}", "{\"players\":0,\"round_duration_in_ticks\":1e300}",
            "{\"players\":0,\"map_name\":\"escape\\u001b[31m\"}", "{\"players\":0,\"map_name\":\"bad\\u202e\"}",
            "{\"players\":0,\"map_name\":\"bad\\ud800\"}", "{\"players\":0,\"map_name\":\"" + new string('a',129) + "\"}" })
            await Reject(() => Task.Run(() => Parse(bad)), "invalid protocol metadata/Unicode");
        var invalidUtf8 = ByondStatusTests.Packet("{\"players\":0,\"map_name\":\"x\"}");
        invalidUtf8[Array.IndexOf(invalidUtf8, (byte)'x')] = 0xff;
        await Reject(() => Task.Run(() => ByondStatus.ParsePacket(invalidUtf8, target, now)), "invalid wire UTF8");
        foreach (var changed in new[] { "{\"players\":0}",
            "{\"players\":0,\"map_name\":\"Other\",\"map_gamemode\":\"Nomads\",\"game_id\":\"round-27\"}",
            "{\"players\":0,\"map_name\":\"Europe\",\"map_gamemode\":\"Other\",\"game_id\":\"round-27\"}",
            "{\"players\":0,\"map_name\":\"Europe\",\"map_gamemode\":\"Nomads\",\"game_id\":\"new-round\"}" })
            await Reject(() => Query(target, changed, server), "prejoin identity changed/disappeared");
        var newer = await Query(target, "{\"players\":2,\"map_name\":\"Europe\",\"map_gamemode\":\"Nomads\",\"game_id\":\"round-27\",\"round_duration_in_ticks\":100}", server);
        Require(newer.Status.Players == 2, "Natural player/time changes blocked recheck");
        var start = ServerCatalog.NativeStart(newer, root, Civ13.Launcher.Program.RequiredByond(), _ => true, now);
        Require(start.ArgumentList.Single() == "byond://72.218.249.221:1714" && !start.UseShellExecute, "Rechecked literal/port lost at dispatch");
        await Reject(() => Task.Run(() => ServerCatalog.NativeStart(newer, root, Civ13.Launcher.Program.RequiredByond(), _ => false, now)), "unverified client");
        await Reject(() => Task.Run(() => ServerCatalog.NativeStart(newer, root, Civ13.Launcher.Program.RequiredByond(), _ => true, now.AddSeconds(61))), "expired probe dispatch");
        await Reject(() => Query(target with { Port = 1715 }, expected: server), "status token moved to other allowed port");
        var seen = new List<GameTarget>(); var active = 0; var peak = 0;
        var discovery = new ServerDiscovery(async candidate => {
            seen.Add(candidate); active++; peak = Math.Max(peak, active);
            try { await Task.Delay(10); if (candidate.Port == 1715) throw new IOException("not a game"); return await Query(candidate, "{\"players\":0}"); }
            finally { active--; }
        });
        var snapshot = await discovery.Fetch("ValZarGaming");
        Require(snapshot.Servers.Count == 1 && snapshot.Servers[0].Players == 0 && snapshot.Unverified == 1, "Failed service equated to valid zero players");
        Require(seen.Count == 2 && seen.All(item => item.Provider == "ValZarGaming") && peak == 2 && active == 0, "Refresh scanned another provider/range or leaked work");
        using var display = new StringWriter(); ServerBrowser.WriteServers(display, "ValZarGaming", snapshot);
        Require(display.ToString().Contains("Players: 0") && display.ToString().Contains("unreachable or not returning valid") && display.ToString().Contains("unavailable"), "Menu conflated offline with empty or invented metadata");
        async Task<(string Output, int Launches, int Checks)> Browse(string input, bool fails = false, bool empty = false) {
            var checks = 0; var launches = 0;
            var fake = new DiscoveryFixture(_ => Task.FromResult(new ServerSnapshot(empty ? Array.Empty<GameServer>() : new[] { server }, empty ? 2 : 1)), async selected => {
                checks++; if (fails) throw new IOException("went offline"); return await Query(selected.Target, expected: selected);
            });
            using var output = new StringWriter();
            await ServerBrowser.Run("ValZarGaming", fake, new StringReader(input), output, _ => { launches++; return Task.CompletedTask; });
            return (output.ToString(), launches, checks);
        }
        var chosen = await Browse("1\n"); Require(chosen.Launches == 1 && chosen.Checks == 1, "Menu omitted prejoin direct probe");
        var gone = await Browse("1\nB\n", fails: true); Require(gone.Launches == 0 && gone.Checks == 1 && gone.Output.Contains("could not be verified"), "Offline prejoin launched");
        var empty = await Browse("1\nB\n", empty: true); Require(empty.Launches == 0 && empty.Checks == 0 && empty.Output.Contains("No verified online"), "No responders launched fallback");
        foreach (var input in new[] { "B\n", "", "-1\n0\n999\n2;calc\nB\n" }) {
            var back = await Browse(input); Require(back.Launches == 0 && back.Checks == 0, "Back/EOF/invalid choice launched");
        }
        var refreshed = await Browse("R\n1\n"); Require(refreshed.Launches == 1 && refreshed.Checks == 1, "Refresh prevented valid selection");
        var failedFetches = 0; var failedChecks = 0;
        var failedDiscovery = new DiscoveryFixture(_ => {
            failedFetches++;
            return Task.FromResult(new ServerSnapshot(new[] { server }, 1));
        }, _ => { failedChecks++; throw new IOException("query refused"); });
        using (var failureOutput = new StringWriter()) {
            await ServerBrowser.Run("ValZarGaming", failedDiscovery, new StringReader("1\n1\nB\n"), failureOutput,
                _ => throw new Exception("Failed status launched"));
            Require(failedFetches == 1 && failedChecks == 1 && failureOutput.ToString().Contains("No automatic retry"),
                "Failed prejoin silently swept again or reused the failed selectable status");
        }
        failedFetches = 0; failedChecks = 0;
        await ServerBrowser.Run("ValZarGaming", failedDiscovery, new StringReader("1\nR\nB\n"), TextWriter.Null,
            _ => throw new Exception("Failed status launched"));
        Require(failedFetches == 2 && failedChecks == 1, "Explicit Refresh no longer controls the next sweep");
        assertions += await ByondStatusTests.Run(server, now);
        Console.WriteLine($"PASS: {assertions} direct BYOND discovery, metadata, DNS, prejoin and selection controls.");
        return assertions;
    }
}
internal sealed class DiscoveryFixture(Func<string, Task<ServerSnapshot>> fetch, Func<GameServer, Task<VerifiedGameServer>> check) : IServerDiscovery {
    public Task<ServerSnapshot> Fetch(string provider) => fetch(provider);
    public Task<VerifiedGameServer> Recheck(GameServer selected) => check(selected);
}
internal sealed class BlockingStream : MemoryStream {
    public override async ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default) {
        await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken); return 0;
    }
}
