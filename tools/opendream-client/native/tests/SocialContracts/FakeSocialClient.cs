using Civ13.Launcher.Social;

// Test-only transport. Completions deliberately ignore cancellation so fences,
// rather than well-behaved mocks, must reject late or out-of-order work.
internal sealed class FakeSocialClient : ISocialClient {
    private readonly object gate = new();
    private long generation, revision;
    private bool cleared;
    private PresenceFrame? visible;
    internal int Advances, Updates, Clears;
    internal bool Defer;
    internal bool DeferClear;
    internal bool Fail;
    internal readonly List<TaskCompletionSource> Completions = [];
    internal readonly List<TaskCompletionSource> ClearCompletions = [];
    internal PresenceFrame? Visible { get { lock (gate) return visible is { IsFresh: true } ? visible : null; } }
    public event Action<JoinIntentEnvelope>? JoinRequested;
    public void Emit(JoinIntentEnvelope value) => JoinRequested?.Invoke(value);
    public void AdvanceGeneration(long value) {
        lock (gate) {
            if (value <= generation) throw new InvalidOperationException("Generation rollback.");
            generation = value; revision = 0; cleared = false; visible = null; Advances++;
        }
    }
    public async Task UpdateAsync(PresenceFrame frame, CancellationToken ct) {
        TaskCompletionSource? completion = null;
        lock (gate) {
            Updates++;
            if (frame.Generation != generation || cleared || frame.Revision <= revision) return;
            revision = frame.Revision;
            if (Defer) {
                completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
                Completions.Add(completion);
            }
        }
        if (completion != null) await completion.Task;
        lock (gate) {
            if (Fail) throw new IOException("Injected transport failure.");
            if (frame.Generation == generation && frame.Revision == revision && !cleared && frame.IsFresh && !ct.IsCancellationRequested)
                visible = frame;
        }
    }
    public async Task ClearAsync(long value, CancellationToken ct) {
        TaskCompletionSource? completion = null;
        lock (gate) {
            Clears++;
            if (value == generation) { cleared = true; visible = null; }
            if (DeferClear) {
                completion = new(TaskCreationOptions.RunContinuationsAsynchronously);
                ClearCompletions.Add(completion);
            }
        }
        if (completion != null) await completion.Task;
        lock (gate) { if (value == generation) visible = null; }
    }
}
