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
// Dormant: instances the host's doorman reports asleep or waking. They were not
// queried directly, so browsing does not wake them.
public sealed record ServerSnapshot(IReadOnlyList<GameServer> Servers, int Unverified, IReadOnlyList<DeferredTarget>? Deferred = null,
    bool PacingPaused = false, IReadOnlyList<DormantServer>? Dormant = null);

public interface IServerDiscovery {
    Task<ServerSnapshot> Fetch(string provider);
    Task<VerifiedGameServer> Recheck(GameServer selected);
    // Thaw a dormant instance through its host, wait until it reports awake, then
    // verify the game port directly exactly as a normal refresh would.
    Task<VerifiedGameServer> WakeAndVerify(DormantServer server, Action<string> progress, CancellationToken token = default) =>
        throw new IOException("This server list cannot wake servers.");
}

public sealed class ServerDiscovery : IServerDiscovery {
    private readonly Func<GameTarget, Task<VerifiedGameServer>> query;
    private readonly Func<string, Task<IReadOnlyDictionary<GameTarget, DormantServer>>>? doorman;
    private readonly Func<GameTarget, Task<string>> wake;
    private readonly Func<TimeSpan, CancellationToken, Task> delay;
    private readonly Func<TimeSpan> elapsed;
    // Production asks each host's doorman first; an injected query alone keeps the direct-only behavior.
    public ServerDiscovery(Func<GameTarget, Task<VerifiedGameServer>>? query = null,
        Func<string, Task<IReadOnlyDictionary<GameTarget, DormantServer>>>? doorman = null,
        Func<GameTarget, Task<string>>? wake = null, Func<TimeSpan, CancellationToken, Task>? delay = null,
        Func<TimeSpan>? elapsed = null) {
        this.query = query ?? (target => ByondStatus.Query(target));
        this.doorman = doorman ?? (query == null ? provider => HostStatus.Query(provider) : null);
        this.wake = wake ?? (target => HostStatus.Wake(target));
        this.delay = delay ?? Task.Delay;
        var started = System.Diagnostics.Stopwatch.StartNew();
        this.elapsed = elapsed ?? (() => started.Elapsed);
    }
    public async Task<ServerSnapshot> Fetch(string provider) {
        // A missing or failing doorman just means every candidate is checked directly.
        IReadOnlyDictionary<GameTarget, DormantServer> hosted = new Dictionary<GameTarget, DormantServer>();
        if (doorman != null) {
            try { hosted = await doorman(provider); }
            catch (IOException) { }
        }
        var dormant = hosted.Values.Where(server => server.State is "asleep" or "waking").OrderBy(server => server.Target.Port).ToArray();
        // Exactly two configured endpoints per provider, at most two active sockets.
        var results = await Task.WhenAll(ServerCatalog.Candidates(provider)
            .Where(target => !dormant.Any(server => server.Target == target)).Select(async target => {
            try { return (Server: (GameServer?)(await query(target)).Status, Wait: (DeferredTarget?)null, Paused: false); }
            catch (TopicWaitException wait) { return (Server: wait.Cached?.Server, Wait: (DeferredTarget?)new DeferredTarget(target, wait.Seconds, wait.Cached), Paused: false); }
            catch (TopicPacingException) { return (Server: (GameServer?)null, Wait: (DeferredTarget?)null, Paused: true); }
            catch (IOException) { return (Server: (GameServer?)null, Wait: (DeferredTarget?)null, Paused: false); }
        }));
        return new ServerSnapshot(Array.AsReadOnly(results.Select(item => item.Server).OfType<GameServer>().ToArray()),
            results.Count(item => item.Server == null && item.Wait == null && !item.Paused),
            Array.AsReadOnly(results.Select(item => item.Wait).OfType<DeferredTarget>().ToArray()), results.Any(item => item.Paused),
            Array.AsReadOnly(dormant));
    }
    public Task<VerifiedGameServer> Recheck(GameServer selected) => ServerCatalog.NativeEndpoint(selected);
    public async Task<VerifiedGameServer> WakeAndVerify(DormantServer server, Action<string> progress, CancellationToken token = default) {
        server.Target.Validate();
        if (doorman == null) throw new IOException("This server list cannot wake servers.");
        // A host that lost power starts the world from its last save, which takes minutes, not seconds.
        var limit = TimeSpan.FromSeconds(Math.Max(HostStatus.WakeLimit.TotalSeconds, server.WakeEstimateSeconds + 60));
        var verb = server.WakeEstimateSeconds > HostStatus.WakeLimit.TotalSeconds ? "Starting" : "Waking";
        progress($"{verb} {server.Name}...");
        var started = elapsed();
        var state = await wake(server.Target);
        while (state != "awake") {
            if (state == "stopped") throw new IOException(server.Name + " is not running. Refresh later.");
            var waited = elapsed() - started;
            if (waited > limit) throw new IOException(server.Name + " did not wake in time. Refresh and try again.");
            progress($"{verb} {server.Name}... {(int)waited.TotalSeconds}s of about {server.WakeEstimateSeconds}s");
            await delay(HostStatus.PollInterval, token);
            var current = await doorman(server.Provider);
            state = current.TryGetValue(server.Target, out var latest) ? latest.State : "stopped";
        }
        progress($"Verifying {server.Name}...");
        return await query(server.Target);
    }
}
