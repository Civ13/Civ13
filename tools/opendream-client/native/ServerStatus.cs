namespace Civ13.Launcher;

// Candidates are configuration, not an assertion that a game is running.
public sealed record GameTarget(string Provider, int Port) {
    public string Host => ServerCatalog.Host(Provider);
    public string Name => Host + ":" + Port;
    public void Validate() {
        if (!ServerCatalog.Candidates(Provider).Contains(this))
            throw new IOException("Game endpoint is outside the configured candidates.");
    }
}

// Only a valid direct BYOND response constructs selectable status.
public sealed class GameServer {
    public const int FreshSeconds = 60;
    public GameTarget Target { get; }
    public string Provider => Target.Provider;
    public string Host => Target.Host;
    public int Port => Target.Port;
    public string Name => Target.Name;
    public string Engine => "BYOND";
    public int Players { get; }
    public string Map { get; }
    public string Mode { get; }
    public string Epoch { get; }
    public string RoundId { get; }
    public int? RoundDurationSeconds { get; }
    public DateTimeOffset CheckedAt { get; }
    internal GameServer(GameTarget target, int players, string map, string mode, string epoch,
        string roundId, int? duration, DateTimeOffset checkedAt) {
        Target = target; Players = players; Map = map; Mode = mode; Epoch = epoch;
        RoundId = roundId; RoundDurationSeconds = duration; CheckedAt = checkedAt;
    }
    public void Validate(DateTimeOffset now) {
        Target.Validate();
        if (now < CheckedAt || now - CheckedAt > TimeSpan.FromSeconds(FreshSeconds))
            throw new IOException("Game status expired. Refresh and choose again.");
    }
    internal bool Matches(GameServer current) => Target == current.Target &&
        (Map.Length == 0 || Map == current.Map) && (Mode.Length == 0 || Mode == current.Mode) &&
        (RoundId.Length == 0 || RoundId == current.RoundId);
}

// Bind the status, literal and configured port to one successful probe.
public sealed class VerifiedGameServer {
    public GameServer Status { get; }
    internal PublicEndpoint Endpoint { get; }
    internal RecentGameStatus? Recent { get; }
    internal VerifiedGameServer(GameServer status, PublicEndpoint endpoint, RecentGameStatus? recent = null) {
        Status = status; Endpoint = endpoint; Recent = recent;
    }
}

// A process-local response proof cannot be reconstructed from persisted display metadata.
internal sealed class RecentGameStatus(Guid requestId, GameServer status, System.Net.IPAddress address, Func<long> monotonic) {
    internal Guid RequestId { get; } = requestId;
    internal GameServer Status { get; } = status;
    internal System.Net.IPAddress Address { get; } = address;
    private readonly long observedTick = monotonic();
    internal bool IsFresh(DateTimeOffset now) => now >= Status.CheckedAt && now - Status.CheckedAt <= TimeSpan.FromSeconds(GameServer.FreshSeconds) &&
        monotonic() - observedTick is >= 0 and <= GameServer.FreshSeconds * 1000L;
}

public sealed record CachedStatus(GameServer? Server, DateTimeOffset CheckedAt, int AgeSeconds) {
    internal RecentGameStatus? Recent { get; init; }
}
public sealed record DeferredTarget(GameTarget Target, int Seconds, CachedStatus? Cached = null);
public sealed record ServerSnapshot(IReadOnlyList<GameServer> Servers, int Unverified, IReadOnlyList<DeferredTarget>? Deferred = null, bool PacingPaused = false);

public interface IServerDiscovery {
    Task<ServerSnapshot> Fetch(string provider);
    Task<VerifiedGameServer> Recheck(GameServer selected);
}

public sealed class ServerDiscovery : IServerDiscovery {
    private readonly Func<GameTarget, Task<VerifiedGameServer>> query;
    public ServerDiscovery(Func<GameTarget, Task<VerifiedGameServer>>? query = null) {
        this.query = query ?? (target => ByondStatus.Query(target));
    }
    public async Task<ServerSnapshot> Fetch(string provider) {
        // Exactly two configured endpoints per provider, at most two active sockets.
        var results = await Task.WhenAll(ServerCatalog.Candidates(provider).Select(async target => {
            try { return (Server: (GameServer?)(await query(target)).Status, Wait: (DeferredTarget?)null, Paused: false); }
            catch (TopicWaitException wait) { return (Server: wait.Cached?.Server, Wait: (DeferredTarget?)new DeferredTarget(target, wait.Seconds, wait.Cached), Paused: false); }
            catch (TopicPacingException) { return (Server: (GameServer?)null, Wait: (DeferredTarget?)null, Paused: true); }
            catch (IOException) { return (Server: (GameServer?)null, Wait: (DeferredTarget?)null, Paused: false); }
        }));
        return new ServerSnapshot(Array.AsReadOnly(results.Select(item => item.Server).OfType<GameServer>().ToArray()),
            results.Count(item => item.Server == null && item.Wait == null && !item.Paused),
            Array.AsReadOnly(results.Select(item => item.Wait).OfType<DeferredTarget>().ToArray()), results.Any(item => item.Paused));
    }
    public Task<VerifiedGameServer> Recheck(GameServer selected) => ServerCatalog.NativeEndpoint(selected);
}
