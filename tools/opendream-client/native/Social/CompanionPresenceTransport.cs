namespace Civ13.Launcher.Social;

// Source-only transport over an injected, bounded nonblocking channel. This does
// not start a helper, load a DLL, create pipes, authenticate or register a URI.
public sealed class CompanionPresenceTransport : IDiscordPresenceTransport {
    private readonly ICompanionPresenceChannel channel;
    private readonly TimeProvider clock;
    private readonly byte[] profile;
    private readonly CompanionFrameReader reader = new();
    private readonly int owner = Environment.CurrentManagedThreadId;
    private Action<PresenceTransportResult>? completion;
    private byte[]? activity;
    private ulong sequence, helloId, publishId;
    private long began, lastPulse;
    private bool started, negotiated, closed, cleared;
    private bool pumping;
    public CompanionPresenceTransport(CompanionProfile profile, ICompanionPresenceChannel channel, TimeProvider clock) {
        ArgumentNullException.ThrowIfNull(profile); ArgumentNullException.ThrowIfNull(channel);
        ArgumentNullException.ThrowIfNull(clock);
        this.profile = CompanionWire.Profile(profile); this.channel = channel; this.clock = clock;
    }
    private void Owner() {
        if (Environment.CurrentManagedThreadId != owner || pumping)
            throw new InvalidOperationException("Companion transport changed owner or reentered its pump.");
    }
    private ulong Next() => sequence = checked(sequence + 1);
    private bool Write(CompanionOp op, ulong id, ReadOnlySpan<byte> payload) =>
        channel.IsOpen && channel.TryWrite(CompanionWire.Encode(op, id, payload));
    public void Publish(LauncherPresence presence, Action<PresenceTransportResult> callback) {
        Owner(); ArgumentNullException.ThrowIfNull(presence); ArgumentNullException.ThrowIfNull(callback);
        if (closed) { callback(PresenceTransportResult.Unavailable); return; }
        if (completion != null) throw new InvalidOperationException("A companion publication is already pending.");
        activity = CompanionWire.Presence(presence); completion = callback; cleared = false;
        try {
            if (!started) {
                started = true; began = lastPulse = clock.GetTimestamp(); helloId = Next();
                if (!Write(CompanionOp.Hello, helloId, profile)) Close(PresenceTransportResult.Unavailable);
            } else if (negotiated) SendPublication();
        } catch (Exception e) when (e is not OutOfMemoryException) { Close(PresenceTransportResult.Failed); }
    }
    private void SendPublication() {
        if (activity == null) return;
        publishId = Next();
        if (!Write(CompanionOp.Publish, publishId, activity)) Close(PresenceTransportResult.Unavailable);
        activity = null;
    }
    public void RunCallbacks() {
        Owner(); if (closed || !started) return;
        pumping = true;
        try {
            if (!channel.IsOpen) { Close(PresenceTransportResult.Unavailable); return; }
            var elapsed = clock.GetElapsedTime(lastPulse);
            if (elapsed < TimeSpan.Zero || (!negotiated && clock.GetElapsedTime(began) >= TimeSpan.FromSeconds(3))) {
                Close(PresenceTransportResult.Failed); return;
            }
            // Both successful frames and fragmented reads have a strict work cap.
            for (var reads = 0; reads < 16 && !closed; reads++) {
                if (!reader.Read(channel, out var frame)) continue;
                if (frame!.Op == CompanionOp.Ready) {
                    if (frame.Id != helloId || !frame.Payload.AsSpan().SequenceEqual(profile))
                        throw new FormatException("Companion profile echo mismatch.");
                    if (!negotiated) { negotiated = true; SendPublication(); }
                } else if (frame.Op == CompanionOp.Result) {
                    if (frame.Payload.Length != 1 || frame.Payload[0] > 2 || frame.Id > sequence)
                        throw new FormatException("Invalid companion result.");
                    if (completion != null && publishId != 0 && frame.Id == publishId) {
                        var callback = completion; completion = null;
                        callback(frame.Payload[0] switch { 0 => PresenceTransportResult.Accepted,
                            1 => PresenceTransportResult.Unavailable, _ => PresenceTransportResult.Failed });
                    }
                } else throw new FormatException("Unexpected companion operation.");
            }
            if (!closed && negotiated && elapsed >= TimeSpan.FromSeconds(1)) {
                if (!Write(CompanionOp.Pulse, Next(), [])) Close(PresenceTransportResult.Unavailable);
                lastPulse = clock.GetTimestamp();
            }
        } catch (Exception e) when (e is not OutOfMemoryException) { Close(PresenceTransportResult.Failed); }
        finally { pumping = false; }
    }
    public void Clear() {
        Owner(); if (closed || !started) return;
        try {
            if (!Write(CompanionOp.Clear, Next(), [])) Close(PresenceTransportResult.Unavailable);
            else cleared = true;
        } catch (Exception e) when (e is not OutOfMemoryException) { Close(PresenceTransportResult.Failed); }
    }
    // Clear/Stop are requests only. EOF/lease cleanup is the peer's obligation;
    // closing this channel cannot acknowledge that remote/native cleanup happened.
    public void Dispose() { Owner(); Close(PresenceTransportResult.Unavailable); }
    private void Close(PresenceTransportResult result) {
        if (closed) return;
        closed = true;
        var callback = completion; completion = null; activity = null;
        try {
            if (started && channel.IsOpen) {
                if (!cleared) try { Write(CompanionOp.Clear, Next(), []); } catch (Exception e) when (e is not OutOfMemoryException) { }
                try { Write(CompanionOp.Stop, Next(), []); } catch (Exception e) when (e is not OutOfMemoryException) { }
            }
        } finally {
            try { channel.Dispose(); }
            finally { callback?.Invoke(result); }
        }
    }
}
