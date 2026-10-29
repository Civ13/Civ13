namespace Civ13.Launcher.Social;

// Application boundary, not a native ABI or an official managed SDK binding.
// A future approved binding translates these two fields to Activity, starts
// UpdateRichPresence, invokes ClearRichPresence and pumps RunCallbacks.
public sealed record LauncherPresence(string Details, string State);
public enum PresenceTransportResult { Accepted = 1, Unavailable = 2, Failed = 3 }

// Construct and call a transport only on the adapter's one pump thread. Publish
// must return promptly; its completion may arrive on any thread, at most once.
// Clear corresponds to a void SDK request, not a remote clear acknowledgement.
// No authentication, friends, voice, accounts or game-server operations here.
public interface IDiscordPresenceTransport : IDisposable {
    void Publish(LauncherPresence activity, Action<PresenceTransportResult> completion);
    void Clear();
    void RunCallbacks();
}

public enum PresenceAdapterState { Disabled, Idle, Publishing, Accepted, ClearIssued, Unavailable, Disposed }
public enum PresenceAdapterFailure { None, TransportUnavailable, TransportFailed, CallbackTimeout, ClockReversed }
public sealed record PresenceAdapterSnapshot(PresenceAdapterState State, PresenceAdapterFailure Failure,
    long Generation, long Revision, bool Pending, bool InFlight);
