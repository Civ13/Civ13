namespace Civ13.Launcher.Social;

// Proposed application contract, not a Discord SDK binding. Implementations must
// fence synchronously on AdvanceGeneration, admit revisions in call order, and
// recheck generation/revision/freshness before applying asynchronous completions.
// Clear is terminal for its generation. No adapter may extend a frame's lifetime.
public interface ISocialClient {
    void AdvanceGeneration(long generation);
    Task UpdateAsync(PresenceFrame frame, CancellationToken ct);
    Task ClearAsync(long generation, CancellationToken ct);
    event Action<JoinIntentEnvelope>? JoinRequested;
}

public sealed class NoopSocialClient : ISocialClient {
    public void AdvanceGeneration(long generation) { }
    public Task UpdateAsync(PresenceFrame frame, CancellationToken ct) => Task.CompletedTask;
    public Task ClearAsync(long generation, CancellationToken ct) => Task.CompletedTask;
    public event Action<JoinIntentEnvelope>? JoinRequested { add { } remove { } }
}

// Default-disabled, timer-free adapter exerciser. A future native adapter owns
// expiry/clear scheduling; this slice does not start a callback pump or service.
public sealed class SocialSession(ISocialClient client, TimeProvider clock) {
    private readonly object gate = new();
    private long generation, revision;
    private bool enabled;
    public long Generation { get { lock (gate) return generation; } }
    public long Enable() {
        lock (gate) {
            enabled = true;
            generation = checked(generation + 1);
            revision = 0;
            client.AdvanceGeneration(generation);
            return generation;
        }
    }
    public Task SetPresenceAsync(LauncherPhase phase, CancellationToken ct = default) {
        lock (gate) {
            if (!enabled || ct.IsCancellationRequested) return Task.CompletedTask;
            var frame = PresenceProjection.Project(true, generation, checked(++revision), phase, clock)!;
            return client.UpdateAsync(frame, ct);
        }
    }
    public Task DisableAsync() {
        lock (gate) {
            enabled = false;
            generation = checked(generation + 1);
            revision = 0;
            client.AdvanceGeneration(generation);
            return client.ClearAsync(generation, CancellationToken.None);
        }
    }
}
