namespace Civ13.Launcher.Social;

// SDK-independent presence adapter. Production startup does not construct this.
// The future launcher/companion owner must call PumpOnce on one worker thread,
// independent of console/UI input, and keep pumping until StopAsync settles.
public sealed class PumpedSocialClient : ISocialClient {
    private readonly object gate = new();
    private readonly Func<IDiscordPresenceTransport> createTransport;
    private readonly TimeProvider clock;
    private readonly TimeSpan callbackTimeout;
    private IDiscordPresenceTransport? transport;
    private Request? pending, inFlight;
    private PresenceFrame? applied;
    private TaskCompletionSource? clearCompletion;
    private readonly TaskCompletionSource stopped = new(TaskCreationOptions.RunContinuationsAsynchronously);
    private long generation, revision;
    private bool terminalClear, clearNeeded, mayHavePresence, stopRequested, unavailable, disposed;
    private int pumpThread, pumping;
    private PresenceAdapterState state;
    private PresenceAdapterFailure failure;

    private sealed class Request(PresenceFrame frame, CancellationToken cancellation) {
        internal readonly PresenceFrame Frame = frame;
        internal readonly CancellationToken Cancellation = cancellation;
        internal readonly TaskCompletionSource Completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
        internal long StartedAt;
        private int result;
        internal PresenceTransportResult? Result {
            get { var value = Volatile.Read(ref result); return value == 0 ? null : (PresenceTransportResult)value; }
        }
        // Captures only this bounded request, never the adapter/native client.
        internal void Complete(PresenceTransportResult value) => Interlocked.CompareExchange(ref result,
            Enum.IsDefined(value) ? (int)value : (int)PresenceTransportResult.Failed, 0);
        internal void Settle() => Completion.TrySetResult();
    }

    public PumpedSocialClient(Func<IDiscordPresenceTransport> createTransport, TimeProvider clock, TimeSpan? callbackTimeout = null) {
        ArgumentNullException.ThrowIfNull(createTransport);
        ArgumentNullException.ThrowIfNull(clock);
        this.createTransport = createTransport; this.clock = clock;
        this.callbackTimeout = callbackTimeout ?? TimeSpan.FromSeconds(5);
        if (this.callbackTimeout <= TimeSpan.Zero || this.callbackTimeout > TimeSpan.FromSeconds(30))
            throw new ArgumentOutOfRangeException(nameof(callbackTimeout));
    }
    public PresenceAdapterSnapshot Snapshot {
        get { lock (gate) return new(state, failure, generation, revision, pending != null, inFlight != null); }
    }
    // Presence-only milestone. No invite event is synthesized from a transport.
    public event Action<JoinIntentEnvelope>? JoinRequested { add { } remove { } }

    public void AdvanceGeneration(long value) {
        lock (gate) {
            if (value <= generation) throw new ArgumentOutOfRangeException(nameof(value));
            generation = value; revision = 0; terminalClear = false;
            pending?.Settle(); pending = null;
            inFlight?.Settle();
            clearCompletion?.TrySetResult(); clearCompletion = null;
            clearNeeded |= mayHavePresence || inFlight != null;
            applied = null;
            if (!unavailable && !disposed && !stopRequested) state = PresenceAdapterState.Idle;
        }
    }
    // Task completion means settled (including coalesced/obsolete/degraded), not
    // that Discord applied the update. Snapshot distinguishes local outcomes.
    public Task UpdateAsync(PresenceFrame frame, CancellationToken ct) {
        ArgumentNullException.ThrowIfNull(frame);
        lock (gate) {
            if (unavailable || disposed || stopRequested || generation == 0 || terminalClear ||
                frame.Generation != generation || frame.Revision <= revision || ct.IsCancellationRequested || !frame.IsFresh)
                return Task.CompletedTask;
            revision = frame.Revision;
            pending?.Settle();
            pending = new(frame, ct);
            return pending.Completion.Task;
        }
    }
    // Opt-out is not made cancellable. The task settles once cleanup is issued,
    // superseded by a new generation, or the transport is quarantined.
    public Task ClearAsync(long value, CancellationToken ct) {
        lock (gate) {
            if (value != generation || generation == 0 || disposed) return Task.CompletedTask;
            terminalClear = true;
            pending?.Settle(); pending = null;
            inFlight?.Settle(); applied = null;
            if (unavailable) return Task.CompletedTask;
            clearNeeded = true;
            clearCompletion ??= new(TaskCreationOptions.RunContinuationsAsynchronously);
            return clearCompletion.Task;
        }
    }
    public Task StopAsync() {
        lock (gate) {
            stopRequested = true; terminalClear = true;
            pending?.Settle(); pending = null;
            inFlight?.Settle(); applied = null;
            clearNeeded |= mayHavePresence || inFlight != null;
            return stopped.Task;
        }
    }

    // No timer/thread is started by construction. All external calls, including
    // lazy creation, clear and disposal, happen here, outside the admission lock.
    public void PumpOnce() {
        var thread = Environment.CurrentManagedThreadId;
        var owner = Interlocked.CompareExchange(ref pumpThread, thread, 0);
        if (owner != 0 && owner != thread) throw new InvalidOperationException("Presence pump changed threads.");
        if (Interlocked.Exchange(ref pumping, 1) != 0) throw new InvalidOperationException("Presence pump is reentrant.");
        var cleanupAttempted = false;
        try {
            lock (gate) { if (disposed || (unavailable && !stopRequested) || (generation == 0 && !stopRequested)) return; }
            if (transport != null) transport.RunCallbacks();
            if (!ObserveCompletion()) return;

            bool clear, close;
            lock (gate) {
                if (applied is { IsFresh: false }) { applied = null; clearNeeded = true; }
                clear = clearNeeded;
                close = stopRequested || terminalClear;
            }
            if (clear) {
                // An old publish has settled before this request. Never send a
                // newer publish while an older native callback is outstanding.
                if (transport != null && mayHavePresence) { cleanupAttempted = true; transport.Clear(); }
                lock (gate) {
                    mayHavePresence = false; applied = null; clearNeeded = false;
                    clearCompletion?.TrySetResult(); clearCompletion = null;
                    if (!unavailable) state = PresenceAdapterState.ClearIssued;
                    close = stopRequested || terminalClear;
                }
            }
            if (close) {
                CloseTransport();
                lock (gate) {
                    if (stopRequested) { disposed = true; state = PresenceAdapterState.Disposed; stopped.TrySetResult(); }
                }
                return;
            }

            Request? request;
            lock (gate) {
                request = pending;
                if (request == null) return;
                pending = null;
                if (!Current(request)) { request.Settle(); return; }
                inFlight = request;
                state = PresenceAdapterState.Publishing;
            }
            transport ??= createTransport() ?? throw new InvalidOperationException("Presence transport missing.");
            lock (gate) {
                if (!Current(request)) { inFlight = null; request.Settle(); return; }
                request.StartedAt = clock.GetTimestamp();
                // The invocation is now an in-flight operation even if a producer
                // invalidates it immediately. Clear/stop waits for its settlement.
                mayHavePresence = true;
            }
            transport.Publish(new(request.Frame.Details, request.Frame.State), request.Complete);
        } catch (Exception error) when (error is not OutOfMemoryException) {
            Quarantine(error is FileNotFoundException or DllNotFoundException or BadImageFormatException or PlatformNotSupportedException
                ? PresenceAdapterFailure.TransportUnavailable : PresenceAdapterFailure.TransportFailed, !cleanupAttempted);
        } finally { Volatile.Write(ref pumping, 0); }
    }
    private bool Current(Request request) => !stopRequested && !terminalClear && request.Frame.Generation == generation &&
        request.Frame.Revision == revision && request.Frame.IsFresh && !request.Cancellation.IsCancellationRequested;

    private bool ObserveCompletion() {
        PresenceAdapterFailure problem = PresenceAdapterFailure.None;
        lock (gate) {
            if (inFlight == null) return true;
            var request = inFlight;
            if (!Current(request)) request.Settle();
            var elapsed = clock.GetElapsedTime(request.StartedAt);
            if (elapsed < TimeSpan.Zero) problem = PresenceAdapterFailure.ClockReversed;
            else if (elapsed >= callbackTimeout) problem = PresenceAdapterFailure.CallbackTimeout;
            else if (request.Result is { } result) {
                inFlight = null; request.Settle();
                if (result == PresenceTransportResult.Unavailable) problem = PresenceAdapterFailure.TransportUnavailable;
                else if (result != PresenceTransportResult.Accepted) problem = PresenceAdapterFailure.TransportFailed;
                else if (Current(request)) { applied = request.Frame; state = PresenceAdapterState.Accepted; }
                else clearNeeded = true;
            } else {
                return false;
            }
        }
        if (problem == PresenceAdapterFailure.None) return true;
        Quarantine(problem);
        return false;
    }
    private void CloseTransport() {
        var previous = transport; transport = null;
        previous?.Dispose();
    }
    private void Quarantine(PresenceAdapterFailure reason, bool attemptClear = true) {
        lock (gate) {
            unavailable = true; failure = reason; state = PresenceAdapterState.Unavailable;
            pending?.Settle(); pending = null;
            inFlight?.Settle(); inFlight = null;
            clearCompletion?.TrySetResult(); clearCompletion = null;
            applied = null; clearNeeded = false;
        }
        // Best effort only: a void clear or timed-out native operation cannot
        // establish remote presence removal. No automatic retry or new client.
        try { if (attemptClear && transport != null && mayHavePresence) transport.Clear(); } catch (Exception e) when (e is not OutOfMemoryException) { }
        try { CloseTransport(); } catch (Exception e) when (e is not OutOfMemoryException) { }
        lock (gate) {
            mayHavePresence = false;
            if (stopRequested) { disposed = true; state = PresenceAdapterState.Disposed; stopped.TrySetResult(); }
        }
    }
}
