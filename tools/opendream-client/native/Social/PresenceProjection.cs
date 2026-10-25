namespace Civ13.Launcher.Social;

public enum LauncherPhase { Browsing, Dispatching }

// Only launcher observations: dispatch is never a connected-game assertion.
public sealed record PresenceFrame {
    public long Generation { get; }
    public long Revision { get; }
    public LauncherPhase Phase { get; }
    public string Details => "Civ13 launcher";
    public string State => Phase == LauncherPhase.Browsing ? "Browsing Civ13 servers" : "Opening BYOND";
    public TimeSpan? Lifetime => Phase == LauncherPhase.Dispatching ? TimeSpan.FromSeconds(15) : null;
    private readonly TimeProvider clock;
    private readonly long observedAt;
    internal PresenceFrame(long generation, long revision, LauncherPhase phase, TimeProvider clock) {
        if (generation <= 0 || revision <= 0 || !Enum.IsDefined(phase)) throw new ArgumentOutOfRangeException(nameof(phase));
        Generation = generation; Revision = revision; Phase = phase; this.clock = clock;
        observedAt = clock.GetTimestamp();
    }
    public bool IsFresh {
        get {
            var elapsed = clock.GetElapsedTime(observedAt);
            return elapsed >= TimeSpan.Zero && (Lifetime is not { } lifetime || elapsed < lifetime);
        }
    }
}

public static class PresenceProjection {
    public static PresenceFrame? Project(bool enabled, long generation, long revision, LauncherPhase phase, TimeProvider clock) =>
        enabled ? new PresenceFrame(generation, revision, phase, clock) : null;
}
