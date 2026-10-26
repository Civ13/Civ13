using System.Buffers.Binary;
using System.Text;
using Civ13.Launcher;
using Civ13.Launcher.Social;

internal static class CompanionTransportTests {
    private static int assertions;
    private static void Check(bool value, string message) { assertions++; if (!value) throw new Exception(message); }
    private static void Refused(Action action) {
        assertions++;
        try { action(); } catch (Exception e) when (e is ArgumentException or FormatException or IOException or InvalidOperationException) { return; }
        throw new Exception("Invalid companion input was accepted.");
    }
    private sealed class Clock : TimeProvider {
        internal long Milliseconds;
        public override long TimestampFrequency => 1000;
        public override long GetTimestamp() => Milliseconds;
        public override DateTimeOffset GetUtcNow() => DateTimeOffset.UnixEpoch.AddMilliseconds(Milliseconds);
    }
    private sealed class Channel : ICompanionPresenceChannel {
        internal readonly Queue<byte> Incoming = new();
        internal readonly List<CompanionFrame> Sent = [];
        internal Action<CompanionFrame>? Receive;
        internal Action? Eof;
        internal bool Open = true, RefuseWrite, ThrowRead, InvalidRead;
        internal int Chunk = 276, Reads, Disposals;
        public bool IsOpen => Open;
        public bool TryWrite(ReadOnlySpan<byte> bytes) {
            if (RefuseWrite || !Open) return false;
            var h = CompanionWire.Header(bytes);
            Check(bytes.Length == 20 + h.PayloadBytes, "Outbound frame size differed.");
            var frame = new CompanionFrame(h.Op, h.Id, bytes[20..].ToArray());
            Sent.Add(frame); Receive?.Invoke(frame); return true;
        }
        public int Read(Span<byte> destination) {
            Reads++;
            if (ThrowRead) throw new IOException("offline read failure");
            if (InvalidRead) return destination.Length + 1;
            var count = Math.Min(Math.Min(destination.Length, Chunk), Incoming.Count);
            for (var i = 0; i < count; i++) destination[i] = Incoming.Dequeue();
            return count;
        }
        internal void Reply(CompanionOp op, ulong id, byte[] payload) {
            foreach (var value in CompanionWire.Encode(op, id, payload)) Incoming.Enqueue(value);
        }
        public void Dispose() { if (!Open) return; Disposals++; Open = false; Eof?.Invoke(); }
    }
    // A protocol peer specification with synthetic native effects. It does not
    // bind Discord, create a process/pipe or establish real SDK cleanup evidence.
    private sealed class Peer {
        private readonly Channel channel;
        private readonly Clock clock;
        internal bool Ready = true, ReplyImmediately = true, Disposed;
        internal int Creates, Publications, Clears, Drops;
        internal long Lease;
        internal ulong Pending;
        internal Peer(Channel channel, Clock clock) {
            this.channel = channel; this.clock = clock;
            channel.Receive = Receive; channel.Eof = Cleanup;
        }
        private void Receive(CompanionFrame frame) {
            if (Disposed) return;
            switch (frame.Op) {
                case CompanionOp.Hello:
                    Creates++; Lease = clock.Milliseconds;
                    if (Ready) channel.Reply(CompanionOp.Ready, frame.Id, frame.Payload);
                    break;
                case CompanionOp.Publish:
                    Publications++; Pending = frame.Id;
                    if (ReplyImmediately) Complete(0);
                    break;
                case CompanionOp.Clear: Clears++; break;
                case CompanionOp.Pulse: Lease = clock.Milliseconds; break;
                case CompanionOp.Stop: Cleanup(); break;
                default: throw new Exception("Client sent an inbound-only operation.");
            }
        }
        internal void Complete(byte result) {
            if (Disposed || Pending == 0) return;
            channel.Reply(CompanionOp.Result, Pending, [result]); Pending = 0;
        }
        internal void Tick() { if (Creates > 0 && clock.Milliseconds - Lease >= 5000) { Cleanup(); channel.Open = false; } }
        private void Cleanup() {
            if (Disposed) return;
            Disposed = true; Pending = 0; if (Creates > 0) { Clears++; Drops++; }
        }
    }
    private static CompanionProfile Profile() => new(new("ValZarGaming", 1714), "1562126764849897544");
    private static LauncherPresence Activity() => new("Browsing Civ13 servers", "Launcher");
    private static void Drain(CompanionPresenceTransport transport, Func<bool> done) {
        for (var i = 0; i < 100 && !done(); i++) transport.RunCallbacks();
        Check(done(), "Bounded fragmented conversation did not settle.");
    }
    private static void ProfilesAndWire() {
        Check(Profile().ApplicationId == "1562126764849897544", "Application ID lost precision.");
        Check(Profile().Target.Provider == "ValZarGaming", "Profile lost provider binding.");
        foreach (var id in new[] { "", "0", "01", "+1", " 1", "1 ", "1e3", "18446744073709551616", new string('1', 21), "١٢" })
            Refused(() => new CompanionProfile(new("ValZarGaming", 1714), id));
        Refused(() => new CompanionProfile(new("Unknown", 1714), "1"));
        Refused(() => new CompanionProfile(new("Civ13.com", 1716), "1"));
        var other = new CompanionProfile(new("Civ13.com", 1714), "42");
        Check(other.ApplicationId == "42", "Independent host acquired the VZG application.");
        var golden = CompanionWire.Encode(CompanionOp.Stop, 1, []);
        Check(Convert.ToHexString(golden) == "4331335301070000010000000000000000000000", "Version-one golden vector changed.");
        foreach (var index in new[] { 0, 1, 2, 3, 4, 5, 6, 7 }) {
            var malformed = golden.ToArray(); malformed[index] = 255;
            Refused(() => CompanionWire.Header(malformed));
        }
        var zeroId = golden.ToArray(); zeroId[8] = 0; Refused(() => CompanionWire.Header(zeroId));
        var oversized = golden.ToArray(); BinaryPrimitives.WriteUInt32LittleEndian(oversized.AsSpan(16), uint.MaxValue);
        Refused(() => CompanionWire.Header(oversized));
        Refused(() => CompanionWire.Encode(CompanionOp.Publish, 1, new byte[257]));
        foreach (var text in new[] { "", "hello\0", new string('x', 97), new string('é', 49), "\ud800" })
            Refused(() => CompanionWire.Presence(new(text, "state")));
        Check(CompanionWire.Presence(new(new string('é', 48), "state")).Length == 103, "UTF-8 bounds used character counts.");
    }
    private static void FragmentationAndCleanup() {
        var channel = new Channel { Chunk = 1 }; var clock = new Clock(); var peer = new Peer(channel, clock);
        var transport = new CompanionPresenceTransport(Profile(), channel, clock); var calls = 0;
        Check(channel.Sent.Count == 0 && peer.Creates == 0, "Construction performed I/O.");
        transport.Publish(Activity(), result => { calls++; Check(result == PresenceTransportResult.Accepted, "Accepted result changed."); });
        Check(channel.Sent.Count == 1 && peer.Publications == 0, "Published before negotiated profile.");
        var hello = channel.Sent[0];
        Check(Encoding.ASCII.GetString(hello.Payload).EndsWith("ValZarGaming1562126764849897544", StringComparison.Ordinal), "Profile was not exact wire data.");
        Drain(transport, () => calls == 1);
        var publication = channel.Sent.Single(f => f.Op == CompanionOp.Publish);
        channel.Reply(CompanionOp.Result, publication.Id, [0]);
        Drain(transport, () => channel.Incoming.Count == 0);
        Check(calls == 1, "Duplicate completion called twice.");
        clock.Milliseconds = 1000; transport.RunCallbacks();
        Check(channel.Sent.Count(f => f.Op == CompanionOp.Pulse) == 1, "Heartbeat was absent.");
        transport.Clear(); transport.Dispose(); transport.Dispose();
        Check(channel.Sent.Count(f => f.Op == CompanionOp.Clear) == 1, "Clear was retried on normal disposal.");
        Check(channel.Sent.Count(f => f.Op == CompanionOp.Stop) == 1 && channel.Disposals == 1, "Stop/close was not once-only.");
        Check(peer.Disposed && peer.Drops == 1, "Mock peer left its owned client alive.");
    }
    private static void FaultsAndBounds() {
        foreach (var mode in new[] { "profile", "future", "status", "opcode", "magic", "length", "read", "count", "eof", "write" }) {
            var channel = new Channel(); var clock = new Clock(); var peer = new Peer(channel, clock) { Ready = false };
            var transport = new CompanionPresenceTransport(Profile(), channel, clock); var calls = 0;
            transport.Publish(Activity(), _ => calls++);
            var hello = channel.Sent[0];
            if (mode == "profile") { var wrong = hello.Payload.ToArray(); wrong[^1] ^= 1; channel.Reply(CompanionOp.Ready, hello.Id, wrong); }
            else if (mode == "future") channel.Reply(CompanionOp.Result, 99, [0]);
            else if (mode == "status") channel.Reply(CompanionOp.Result, hello.Id, [3]);
            else if (mode == "opcode") channel.Reply(CompanionOp.Clear, hello.Id, []);
            else if (mode == "magic") { var bad = CompanionWire.Encode(CompanionOp.Ready, hello.Id, []); bad[0] = 0; foreach (var b in bad) channel.Incoming.Enqueue(b); }
            else if (mode == "length") { var bad = CompanionWire.Encode(CompanionOp.Ready, hello.Id, []); BinaryPrimitives.WriteUInt32LittleEndian(bad.AsSpan(16), uint.MaxValue); foreach (var b in bad) channel.Incoming.Enqueue(b); }
            else if (mode == "read") channel.ThrowRead = true;
            else if (mode == "count") channel.InvalidRead = true;
            else if (mode == "eof") { channel.Open = false; channel.Eof!(); }
            else { channel.RefuseWrite = true; channel.Reply(CompanionOp.Ready, hello.Id, hello.Payload); }
            transport.RunCallbacks(); transport.RunCallbacks(); transport.Dispose();
            Check(calls == 1 && !channel.Open && peer.Drops == 1, "Fault did not settle/close: " + mode);
            transport.Publish(Activity(), r => { calls++; Check(r == PresenceTransportResult.Unavailable, "Closed transport reopened."); });
            Check(calls == 2 && peer.Creates == 1, "Fault triggered automatic reconnect.");
        }
        foreach (var at in new[] { 3000L, -1L }) {
            var channel = new Channel(); var clock = new Clock(); var peer = new Peer(channel, clock);
            var transport = new CompanionPresenceTransport(Profile(), channel, clock); var calls = 0;
            transport.Publish(Activity(), r => { calls++; Check(r == PresenceTransportResult.Failed, "Deadline/clock reversal accepted success."); });
            clock.Milliseconds = at; transport.RunCallbacks();
            Check(calls == 1 && peer.Publications == 0, "Late queued Ready was used.");
        }
        var bounded = new Channel(); var boundedClock = new Clock(); var boundedPeer = new Peer(bounded, boundedClock);
        using var limited = new CompanionPresenceTransport(Profile(), bounded, boundedClock);
        limited.Publish(Activity(), _ => { }); limited.RunCallbacks();
        for (var i = 0; i < 1000; i++) bounded.Reply(CompanionOp.Result, 1, [0]);
        var before = bounded.Reads; limited.RunCallbacks();
        Check(bounded.Reads - before <= 16, "Hostile peer caused unbounded pump work.");
    }
    private static void PendingAndPeerLease() {
        foreach (var code in new byte[] { 0, 1, 2 }) {
            var channel = new Channel(); var clock = new Clock(); var peer = new Peer(channel, clock) { ReplyImmediately = false };
            using var transport = new CompanionPresenceTransport(Profile(), channel, clock); var calls = 0;
            transport.Publish(Activity(), r => { calls++; Check((int)r == code + 1, "SDK-independent result mapping changed."); });
            transport.RunCallbacks(); Refused(() => transport.Publish(Activity(), _ => { }));
            peer.Complete(code); transport.RunCallbacks(); Check(calls == 1, "Native result did not settle once.");
            var old = channel.Sent.Single(f => f.Op == CompanionOp.Publish).Id;
            var nextCalls = 0;
            transport.Publish(Activity(), _ => nextCalls++);
            channel.Reply(CompanionOp.Result, old, [0]); transport.RunCallbacks();
            Check(nextCalls == 0, "Old result completed a new publication.");
            peer.Complete(code); transport.RunCallbacks(); Check(nextCalls == 1, "New publication lost its callback.");
        }
        var abandoned = new Channel(); var time = new Clock(); var worker = new Peer(abandoned, time) { ReplyImmediately = false };
        var client = new CompanionPresenceTransport(Profile(), abandoned, time); var completed = 0;
        client.Publish(Activity(), _ => completed++); client.RunCallbacks();
        time.Milliseconds = 5000; worker.Tick(); worker.Complete(0); client.RunCallbacks(); client.Dispose();
        Check(worker.Drops == 1 && worker.Disposed && completed == 1, "Mock peer lease failed cleanup or released late callback.");
        var stoppingChannel = new Channel(); var stoppingClock = new Clock(); var stoppingPeer = new Peer(stoppingChannel, stoppingClock) { ReplyImmediately = false };
        var stopping = new CompanionPresenceTransport(Profile(), stoppingChannel, stoppingClock); var settled = 0;
        stopping.Publish(Activity(), r => { settled++; Check(r == PresenceTransportResult.Unavailable, "Dispose accepted pending native work."); });
        stopping.RunCallbacks(); stopping.Dispose(); stoppingPeer.Complete(0); stopping.Dispose();
        Check(settled == 1 && stoppingPeer.Pending == 0 && stoppingPeer.Drops == 1, "Stop retained a late callback or destroyed twice.");
        Check(stoppingChannel.Sent.Count(f => f.Op == CompanionOp.Clear) == 1 && stoppingChannel.Sent.Count(f => f.Op == CompanionOp.Stop) == 1, "Stop did not bound cleanup requests.");
        var refused = new Channel { RefuseWrite = true }; var refusedClock = new Clock(); var refusedPeer = new Peer(refused, refusedClock);
        using var noQueue = new CompanionPresenceTransport(Profile(), refused, refusedClock); var unavailable = 0;
        noQueue.Publish(Activity(), r => { if (r == PresenceTransportResult.Unavailable) unavailable++; }); noQueue.RunCallbacks();
        Check(unavailable == 1 && refusedPeer.Creates == 0 && refused.Disposals == 1, "Initial backpressure queued/retried Hello.");
        var ownerChannel = new Channel(); var ownerClock = new Clock(); var owner = new CompanionPresenceTransport(Profile(), ownerChannel, ownerClock);
        Exception? failure = null;
        var other = new Thread(() => { try { owner.RunCallbacks(); } catch (Exception e) { failure = e; } }); other.Start(); other.Join();
        Check(failure is InvalidOperationException && ownerChannel.Sent.Count == 0, "Transport owner changed threads."); owner.Dispose();
        var reentrantChannel = new Channel(); var reentrantClock = new Clock(); _ = new Peer(reentrantChannel, reentrantClock);
        using var reentrant = new CompanionPresenceTransport(Profile(), reentrantChannel, reentrantClock);
        var rejected = false;
        reentrant.Publish(Activity(), _ => { try { reentrant.RunCallbacks(); } catch (InvalidOperationException) { rejected = true; } });
        reentrant.RunCallbacks(); Check(rejected, "Completion reentered the transport pump.");
    }
    private static void ExistingPumpIntegration() {
        var channel = new Channel(); var clock = new Clock(); var peer = new Peer(channel, clock);
        var pump = new PumpedSocialClient(() => new CompanionPresenceTransport(Profile(), channel, clock), clock);
        var session = new SocialSession(pump, clock);
        Check(session.SetPresenceAsync(LauncherPhase.Browsing).IsCompleted && peer.Creates == 0, "Default-disabled path did work.");
        session.Enable(); var update = session.SetPresenceAsync(LauncherPhase.Browsing);
        pump.PumpOnce(); pump.PumpOnce();
        Check(update.IsCompleted && pump.Snapshot.State == PresenceAdapterState.Accepted, "Existing pump did not consume the injected transport.");
        var disable = session.DisableAsync(); pump.PumpOnce();
        Check(disable.IsCompleted && peer.Disposed && peer.Drops == 1, "Existing generation cleanup did not close the peer.");
        var stop = pump.StopAsync(); pump.PumpOnce(); Check(stop.IsCompleted, "Existing Stop did not settle.");
    }
    private static void ClearFencesPublicTransport() {
        var channel = new Channel(); var clock = new Clock(); var peer = new Peer(channel, clock) { Ready = false };
        using var transport = new CompanionPresenceTransport(Profile(), channel, clock); var oldCalls = 0;
        transport.Publish(Activity(), r => { oldCalls++; Check(r == PresenceTransportResult.Unavailable, "Clear accepted the cancelled activity."); });
        var hello = channel.Sent.Single(f => f.Op == CompanionOp.Hello);
        transport.Clear();
        Check(oldCalls == 1, "Clear during negotiation left the old callback pending.");
        channel.Reply(CompanionOp.Ready, hello.Id, hello.Payload);
        channel.Reply(CompanionOp.Result, hello.Id, [0]); transport.RunCallbacks();
        Check(peer.Publications == 0 && oldCalls == 1, "Late Ready published cancelled negotiation activity.");
        var freshCalls = 0;
        transport.Publish(new("Fresh launcher activity", "Launcher"), _ => freshCalls++); transport.RunCallbacks();
        Check(freshCalls == 1 && peer.Publications == 1 && oldCalls == 1, "Explicit fresh activity after negotiated Clear failed.");

        var pendingChannel = new Channel(); var pendingClock = new Clock(); var pendingPeer = new Peer(pendingChannel, pendingClock) { ReplyImmediately = false };
        var pending = new CompanionPresenceTransport(Profile(), pendingChannel, pendingClock); var cancelled = 0;
        pending.Publish(Activity(), r => { cancelled++; Check(r == PresenceTransportResult.Unavailable, "Clear accepted an in-flight activity."); });
        pending.RunCallbacks();
        var publication = pendingChannel.Sent.Single(f => f.Op == CompanionOp.Publish);
        var pendingHello = pendingChannel.Sent.Single(f => f.Op == CompanionOp.Hello);
        pending.Clear();
        Check(cancelled == 1 && pendingPeer.Disposed && pendingPeer.Pending == 0, "In-flight Clear did not close the physical session.");
        pendingChannel.Reply(CompanionOp.Result, publication.Id, [0]);
        pendingChannel.Reply(CompanionOp.Ready, pendingHello.Id, pendingHello.Payload);
        pendingPeer.Complete(0); pending.RunCallbacks(); pending.Clear(); pending.Dispose();
        Check(cancelled == 1 && pendingPeer.Publications == 1 && pendingPeer.Drops == 1, "Late Result/Ready escaped the Clear fence.");
        var sent = pendingChannel.Sent.Count;
        pending.Publish(Activity(), r => Check(r == PresenceTransportResult.Unavailable, "Cleared physical session reopened."));
        Check(pendingChannel.Sent.Count == sent && pendingChannel.Disposals == 1, "Cleared physical session retried I/O.");
    }
    internal static int Run() {
        assertions = 0; ProfilesAndWire(); FragmentationAndCleanup(); FaultsAndBounds(); PendingAndPeerLease(); ExistingPumpIntegration(); ClearFencesPublicTransport();
        return assertions;
    }
}
