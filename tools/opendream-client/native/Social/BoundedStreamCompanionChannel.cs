namespace Civ13.Launcher.Social;

// Owned, vetted asynchronous private streams only. No streams/pipes are opened
// here. A blocking Stream override cannot be made nonblocking by this wrapper.
public sealed class BoundedStreamCompanionChannel : ICompanionPresenceChannel {
    private readonly object gate = new();
    private readonly Stream input, output;
    private readonly TimeProvider clock;
    private readonly CancellationTokenSource cancellation = new();
    private readonly byte[] incoming = new byte[CompanionWire.MaxFrame], outgoing = new byte[CompanionWire.MaxFrame];
    private Task<int>? reading;
    private Task? writing;
    private int offset, remaining;
    private long previous, writeBegan;
    private bool open = true, tokenDisposed, closeFailed;
    public BoundedStreamCompanionChannel(Stream input, Stream output, TimeProvider clock) {
        ArgumentNullException.ThrowIfNull(input); ArgumentNullException.ThrowIfNull(output); ArgumentNullException.ThrowIfNull(clock);
        if (ReferenceEquals(input, output) || !input.CanRead || !output.CanWrite) throw new ArgumentException("Separate owned asynchronous streams required.");
        this.input = input; this.output = output; this.clock = clock; previous = clock.GetTimestamp();
    }
    private static void Observe(Task task) => _ = task.ContinueWith(t => { _ = t.Exception; }, CancellationToken.None,
        TaskContinuationOptions.OnlyOnFaulted | TaskContinuationOptions.ExecuteSynchronously, TaskScheduler.Default);
    private bool Settled => (reading == null || reading.IsCompleted) && (writing == null || writing.IsCompleted);
    // Quiescence is distinct from closed. A late operation retains its old
    // buffer; its streams/session must never be reused for a reconnect.
    public bool IsSettled { get { lock (gate) { ReleaseToken(); return Settled && !closeFailed; } } }
    public bool IsOpen { get { lock (gate) { Refresh(); return open; } } }
    private void ReleaseToken() {
        if (!open && Settled && !tokenDisposed) { tokenDisposed = true; cancellation.Dispose(); }
    }
    private void Refresh() {
        if (!open) { ReleaseToken(); return; }
        var now = clock.GetTimestamp();
        if (now < previous) { Close(); return; } previous = now;
        if (writing != null) {
            if (clock.GetElapsedTime(writeBegan, now) >= TimeSpan.FromMilliseconds(250)) { Close(); return; }
            if (writing.IsCompleted) {
                try { writing.GetAwaiter().GetResult(); writing = null; }
                catch (Exception e) when (e is not OutOfMemoryException) { Close(); }
            }
        }
    }
    public bool TryWrite(ReadOnlySpan<byte> frame) {
        lock (gate) {
            Refresh(); if (!open || writing != null) return false;
            if (frame.Length is < CompanionWire.HeaderBytes or > CompanionWire.MaxFrame) throw new FormatException("Frame bounds.");
            var header = CompanionWire.Header(frame);
            if (frame.Length != CompanionWire.HeaderBytes + header.PayloadBytes) throw new FormatException("Incomplete frame.");
            frame.CopyTo(outgoing); writeBegan = clock.GetTimestamp();
            // True is full-frame admission, not delivery. Once I/O was attempted,
            // errors close the channel and must never be reported as retryable.
            try { writing = output.WriteAsync(outgoing.AsMemory(0, frame.Length), cancellation.Token).AsTask(); Observe(writing); }
            catch (Exception e) when (e is not OutOfMemoryException) { Close(); }
            return true;
        }
    }
    public int Read(Span<byte> destination) {
        lock (gate) {
            Refresh(); if (!open || destination.IsEmpty) return 0;
            try {
                if (remaining == 0) {
                    if (reading == null) { reading = input.ReadAsync(incoming, cancellation.Token).AsTask(); Observe(reading); }
                    if (!reading.IsCompleted) return 0;
                    remaining = reading.GetAwaiter().GetResult(); reading = null; offset = 0;
                    if (remaining is <= 0 or > CompanionWire.MaxFrame) { Close(); return 0; }
                }
                var count = Math.Min(destination.Length, remaining);
                incoming.AsSpan(offset, count).CopyTo(destination); offset += count; remaining -= count; return count;
            } catch (Exception e) when (e is not OutOfMemoryException) { Close(); return 0; }
        }
    }
    private void Close() {
        if (open) {
            open = false;
            try { cancellation.Cancel(); } catch (Exception e) when (e is not OutOfMemoryException) { closeFailed = true; }
            try { input.Dispose(); } catch (Exception e) when (e is not OutOfMemoryException) { closeFailed = true; }
            try { output.Dispose(); } catch (Exception e) when (e is not OutOfMemoryException) { closeFailed = true; }
        }
        ReleaseToken();
    }
    public void Dispose() { lock (gate) Close(); }
}
