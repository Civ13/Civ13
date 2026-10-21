using System.Net;
using System.Text;
using Civ13.Launcher;

internal static class ByondStatusTests {
    public static byte[] Packet(string? json = null) {
        var body = Encoding.UTF8.GetBytes(json ?? "{\"players\":0,\"map_name\":\"Europe\",\"map_gamemode\":\"Nomads\",\"game_id\":\"round-27\",\"round_duration_in_ticks\":0}");
        var packet = new byte[body.Length + 6];
        packet[1] = 0x83; packet[2] = (byte)((body.Length + 2) >> 8); packet[3] = (byte)(body.Length + 2); packet[4] = 0x06;
        body.CopyTo(packet, 5);
        return packet;
    }
    public static async Task<int> Run(GameServer server, DateTimeOffset now) {
        var assertions = 0;
        void Require(bool ok, string why) { assertions++; if (!ok) throw new Exception(why); }
        async Task Reject(Func<Task> action, string why) {
            try { await action(); } catch (IOException) { assertions++; return; }
            throw new Exception("Status negative control accepted: " + why);
        }
        Task<ReadOnlyMemory<byte>> Valid(IPAddress _, int port, CancellationToken token) {
            Require(port == server.Port && !token.IsCancellationRequested, "Unbound port or cancelled query");
            return Task.FromResult<ReadOnlyMemory<byte>>(Packet());
        }
        var desired = IPAddress.Parse("72.218.249.221"); var other = IPAddress.Parse("192.64.119.81");
        foreach (var addresses in new[] { new[] { desired, other }, new[] { other, desired } }) {
            foreach (var failure in new[] { "silent", "malformed", "incomplete", "wrong-world" }) {
                var calls = new List<string>(); var dnsCalls = 0; var active = 0; var peak = 0;
                async Task<ReadOnlyMemory<byte>> Probe(IPAddress ip, int port, CancellationToken token) {
                    calls.Add(ip.ToString()); active++; peak = Math.Max(peak, active);
                    try {
                        Require(port == server.Port, "Changed candidate port");
                        if (ip.Equals(desired)) return Packet();
                        if (failure == "silent") { await Task.Delay(Timeout.Infinite, token); throw new Exception("Silent probe not cancelled"); }
                        return failure switch { "malformed" => Encoding.ASCII.GetBytes("HTTP/1.1 200 OK"),
                            "incomplete" => Packet("{}"), _ => Packet("{\"players\":0,\"map_name\":\"Other\",\"map_gamemode\":\"Nomads\",\"round_duration_in_ticks\":0}") };
                    } finally { active--; }
                }
                var selected = await ServerCatalog.NativeEndpoint(server, _ => { dnsCalls++; return Task.FromResult(addresses); }, now,
                    Probe, timeout: TimeSpan.FromMilliseconds(200));
                Require(selected.Address == desired.ToString() && calls.SequenceEqual(new[] { other.ToString(), desired.ToString() }), "Healthy alternative was not selected");
                Require(dnsCalls == 1 && peak == 1 && active == 0, "Re-resolution, socket overlap, or retained socket");
                var start = ServerCatalog.NativeStart(server, ".", selected, Civ13.Launcher.Program.RequiredByond(), _ => true, now);
                Require(start.ArgumentList.Single() == $"byond://{desired}:{server.Port}" && dnsCalls == 1, "Selected literal changed at dispatch");
            }
        }
        foreach (var answers in new[] { Array.Empty<IPAddress>(), Enumerable.Repeat(desired, 33).ToArray(),
            new[] { desired, IPAddress.Loopback }, new[] { IPAddress.Parse("192.0.2.1"), desired } }) {
            var calls = 0;
            await Reject(() => ServerCatalog.NativeEndpoint(server, _ => Task.FromResult(answers), now,
                (_, _, _) => { calls++; throw new Exception("Unsafe DNS reached status probe"); }), "whole-set bounds/safety");
            Require(calls == 0, "Unsafe member filtered instead of rejecting full set");
        }
        var duplicateCalls = 0;
        await ServerCatalog.NativeEndpoint(server, _ => Task.FromResult(new[] { desired, desired }), now,
            (_, _, _) => { duplicateCalls++; return Task.FromResult<ReadOnlyMemory<byte>>(Packet()); });
        Require(duplicateCalls == 1, "Duplicate address retried");
        var remainingCalls = 0;
        await ServerCatalog.NativeEndpoint(server, _ => Task.FromResult(new[] { IPAddress.Parse("1.1.1.1"), desired }), now,
            (_, _, _) => { remainingCalls++; return Task.FromResult<ReadOnlyMemory<byte>>(Packet()); });
        Require(remainingCalls == 1, "Successful first candidate did not stop attempts");
        var elapsed = System.Diagnostics.Stopwatch.StartNew(); var failures = 0;
        await Reject(() => ServerCatalog.NativeEndpoint(server, _ => Task.FromResult(new[] { desired, other }), now,
            async (_, _, token) => { failures++; await Task.Delay(Timeout.Infinite, token); return Packet(); }, timeout: TimeSpan.FromMilliseconds(100)), "all silent candidates");
        Require(failures == 2 && elapsed.Elapsed < TimeSpan.FromSeconds(1), "Per-address budgets multiplied total deadline");
        var expired = now;
        await Reject(() => ServerCatalog.NativeEndpoint(server, _ => Task.FromResult(new[] { desired }), statusProbe: (_, _, _) => {
            expired = now.AddMinutes(2); return Task.FromResult<ReadOnlyMemory<byte>>(Packet());
        }, clock: () => expired), "directory expired during probe");
        var afterDnsCalls = 0;
        await Reject(() => ServerCatalog.NativeEndpoint(server, async _ => { await Task.Delay(100); return new[] { desired }; }, now,
            (_, _, _) => { afterDnsCalls++; return Task.FromResult<ReadOnlyMemory<byte>>(Packet()); }, timeout: TimeSpan.FromMilliseconds(20)), "DNS shares deadline");
        await Task.Delay(110);
        Require(afterDnsCalls == 0, "Late DNS callback opened a game socket");
        using (var cancelled = new CancellationTokenSource()) {
            cancelled.Cancel();
            await Reject(() => ServerCatalog.NativeEndpoint(server, _ => Task.FromResult(new[] { desired }), now, Valid, cancellationToken: cancelled.Token), "caller cancellation");
        }
        foreach (var json in new[] { "{}", "[]", "{\"players\":0,\"players\":1}", "{\"players\":-1}",
            "{\"players\":0,\"map_name\":\"Europe\",\"map_gamemode\":\"Nomads\",\"game_id\":\"wrong\",\"round_duration_in_ticks\":0}",
            "{\"players\":0,\"map_name\":\"Europe\",\"map_gamemode\":\"Nomads\",\"round_duration_in_ticks\":-1}" })
            await Reject(() => Task.Run(() => ByondStatus.ValidatePacket(Packet(json), server)), "incomplete/malformed/mismatched metadata");
        foreach (var bytes in new[] { Packet()[..^1], Packet().Concat(new byte[] { 0 }).ToArray(), new byte[65537], Encoding.ASCII.GetBytes("not BYOND") })
            await Reject(() => Task.Run(() => ByondStatus.ValidatePacket(bytes, server)), "frame bounds/protocol");
        var valid = Packet(); ByondStatus.ValidatePacket(valid, server); assertions++;
        using (var stream = new OneByteStatusStream(valid)) {
            var read = await ByondStatus.ReadResponse(stream, CancellationToken.None);
            Require(read.Span.SequenceEqual(valid), "Partial header/body reads changed packet");
        }
        await Reject(async () => { using var stream = new MemoryStream(valid[..^2]); await ByondStatus.ReadResponse(stream, CancellationToken.None); }, "truncated body");
        await Reject(async () => { using var stream = new MemoryStream(new byte[] { 0, 0x83, 0xff, 0xff }); await ByondStatus.ReadResponse(stream, CancellationToken.None); }, "oversized declared frame before allocation");
        using (var timer = new CancellationTokenSource(20)) {
            try { await ByondStatus.ReadResponse(new BlockingStream(), timer.Token); throw new Exception("Read deadline ignored"); }
            catch (OperationCanceledException) { assertions++; }
        }
        Console.WriteLine($"PASS: {assertions} bounded BYOND status and multi-address controls.");
        return assertions;
    }
}
internal sealed class OneByteStatusStream(byte[] bytes) : MemoryStream(bytes) {
    public override ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken token = default) => base.ReadAsync(buffer[..Math.Min(1, buffer.Length)], token);
}
