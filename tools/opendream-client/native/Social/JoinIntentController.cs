using System.Diagnostics;

namespace Civ13.Launcher.Social;

public enum JoinOutcome { Disabled, NoPending, Busy, Cancelled, Deferred, Paused, Unavailable, Failed, Dispatched }
public sealed record JoinAcceptance(JoinOutcome Outcome, int? WaitSeconds = null);

// No defaults for discovery, preparation or dispatch: this slice is only wired
// by offline tests. A future composition root must prepare with NativeStart.
public sealed class JoinIntentController(IServerDiscovery discovery,
    Func<VerifiedGameServer, ProcessStartInfo> prepare, Action<ProcessStartInfo> dispatch, TimeProvider clock) {
    private readonly object gate = new();
    private long generation;
    private bool enabled;
    private JoinIntentEnvelope? pending;
    private Guid lastReceived;
    private Attempt? attempt;
    private sealed record Attempt(JoinIntentEnvelope Intent, CancellationTokenSource Cancellation);

    public void SetGeneration(long value, bool active) {
        CancellationTokenSource? cancel;
        lock (gate) {
            if (value <= generation) throw new ArgumentOutOfRangeException(nameof(value), "Generation must advance.");
            generation = value; enabled = active; pending = null; lastReceived = Guid.Empty;
            cancel = attempt?.Cancellation;
        }
        CancelSafely(cancel);
    }
    public bool Receive(JoinIntentEnvelope envelope) {
        CancellationTokenSource? cancel;
        lock (gate) {
            if (!enabled || envelope.Generation != generation || envelope.IntentId == Guid.Empty ||
                envelope.IntentId == lastReceived || envelope.Value == null) return false;
            pending = envelope; lastReceived = envelope.IntentId;
            cancel = attempt?.Cancellation;
        }
        CancelSafely(cancel);
        return true;
    }
    public void Cancel() {
        CancellationTokenSource? cancel;
        lock (gate) { pending = null; cancel = attempt?.Cancellation; }
        CancelSafely(cancel);
    }
    private static void CancelSafely(CancellationTokenSource? cancellation) {
        try { cancellation?.Cancel(); } catch (ObjectDisposedException) { }
    }
    private void Check(Attempt current) {
        if (!Active(current)) throw new OperationCanceledException();
    }
    private bool Active(Attempt current) => !current.Cancellation.IsCancellationRequested && enabled &&
        generation == current.Intent.Generation && ReferenceEquals(pending, current.Intent);
    public async Task<JoinAcceptance> AcceptAsync(CancellationToken ct = default) {
        Attempt current;
        lock (gate) {
            if (!enabled) return new(JoinOutcome.Disabled);
            if (pending == null) return new(JoinOutcome.NoPending);
            if (attempt != null) return new(JoinOutcome.Busy);
            if (ct.IsCancellationRequested) return new(JoinOutcome.Cancelled);
            current = new(pending, CancellationTokenSource.CreateLinkedTokenSource(ct));
            attempt = current;
        }
        var retainForExplicitRetry = false;
        try {
            Task<ServerSnapshot> fetch;
            lock (gate) { Check(current); fetch = discovery.Fetch(current.Intent.Value.Target.Provider); }
            // IServerDiscovery has no cancellation parameter. Await its settlement
            // before allowing another attempt; never abandon it and overlap work.
            var snapshot = await fetch.ConfigureAwait(false);
            Task<VerifiedGameServer> recheck;
            GameServer selected;
            lock (gate) {
                Check(current);
                if (snapshot.PacingPaused) return new(JoinOutcome.Paused);
                var matches = snapshot.Servers.Where(s => s.Target == current.Intent.Value.Target).ToArray();
                if (matches.Length != 1) {
                    var deferred = snapshot.Deferred?.SingleOrDefault(d => d.Target == current.Intent.Value.Target);
                    if (deferred != null) { retainForExplicitRetry = true; return new(JoinOutcome.Deferred, deferred.Seconds); }
                    return new(JoinOutcome.Unavailable);
                }
                selected = matches[0];
                selected.Validate(clock.GetUtcNow());
                if (!current.Intent.Value.Matches(selected)) return new(JoinOutcome.Unavailable);
                recheck = discovery.Recheck(selected);
            }
            var verified = await recheck.ConfigureAwait(false);
            lock (gate) {
                Check(current);
                verified.Status.Validate(clock.GetUtcNow());
                if (!selected.Matches(verified.Status) || !current.Intent.Value.Matches(verified.Status))
                    return new(JoinOutcome.Unavailable);
                var start = prepare(verified);
                Check(current); // Preparation may block or reenter cancellation.
                var now = clock.GetUtcNow();
                verified.Status.Validate(now);
                if (verified.Recent is { } recent && !recent.IsFresh(now))
                    throw new IOException("Recent status proof expired during preparation.");
                verified.Endpoint.Validate(verified.Status.Host);
                Check(current);
                pending = null; // Consume before invoking even a reentrant delegate.
                dispatch(start);
                return new(JoinOutcome.Dispatched); // Not proof of login/connection.
            }
        } catch (TopicWaitException wait) {
            lock (gate) {
                if (!Active(current)) return new(JoinOutcome.Cancelled);
                retainForExplicitRetry = true;
                return new(JoinOutcome.Deferred, wait.Seconds);
            }
        } catch (TopicPacingException) {
            lock (gate) return new(Active(current) ? JoinOutcome.Paused : JoinOutcome.Cancelled);
        }
        catch (OperationCanceledException) { return new(JoinOutcome.Cancelled); }
        catch (Exception error) when (error is IOException or InvalidOperationException or ArgumentException or System.ComponentModel.Win32Exception) {
            return new(JoinOutcome.Failed); // No retry; a throwing dispatcher may have acted.
        } finally {
            lock (gate) {
                if (ReferenceEquals(attempt, current)) attempt = null;
                if (!retainForExplicitRetry && ReferenceEquals(pending, current.Intent)) pending = null;
            }
            current.Cancellation.Dispose();
        }
    }
}
