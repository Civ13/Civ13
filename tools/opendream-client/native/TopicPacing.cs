using System.Net;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Civ13.Launcher;

public class TopicPacingException(string message) : IOException(message);
public sealed class TopicWaitException(TimeSpan remaining, CachedStatus? cached = null) : TopicPacingException("Public status request spacing is still active.") {
    public int Seconds { get; } = Math.Max(1, (int)Math.Ceiling(remaining.TotalSeconds));
    public CachedStatus? Cached { get; } = cached;
}

// Cooperative, per-Windows-account spacing, independent of --root. Not a ban reset.
public sealed class TopicPacer {
    public const int SpacingSeconds = 130;
    // A reservation precedes a write inside the 3s IO budget. Clock drift can
    // move from -2s to +2s between reservations, so reserve the full 4s swing.
    public const int ReservationSeconds = SpacingSeconds + 3 + 4;
    public const int StartupGuardSeconds = SpacingSeconds + 3;
    private static readonly Lazy<TopicPacer> shared = new(() => new TopicPacer(Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Civ13", "status-requests")));
    public static TopicPacer Shared => shared.Value;
    private readonly string directory;
    private readonly Func<DateTimeOffset> utc;
    private readonly Func<long> monotonic;
    private readonly DateTimeOffset startedUtc;
    private readonly long startedTick;
    private readonly object gate = new();
    private readonly Dictionary<GameTarget, RecentGameStatus> recent = new();
    private static readonly JsonSerializerOptions json = new() {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow, MaxDepth = 8
    };
    private sealed record Result(string? Json, DateTimeOffset CheckedAt);
    private sealed record Entry(string Provider, int Port, string[] Addresses, DateTimeOffset ReservedAt, DateTimeOffset NotBefore,
        long? ReservedTick = null, Guid? RequestId = null, Result? Result = null);
    private sealed record State(int Schema, Entry[] Entries);

    public TopicPacer(string directory, Func<DateTimeOffset>? utc = null, Func<long>? monotonic = null) {
        try {
            if (!Path.IsPathFullyQualified(directory) || directory.StartsWith("\\\\", StringComparison.Ordinal))
                throw new IOException("Request spacing needs an absolute local directory.");
            this.directory = Path.GetFullPath(directory);
            if (OperatingSystem.IsWindows() && new DriveInfo(Path.GetPathRoot(this.directory)!).DriveType == DriveType.Network)
                throw new IOException("Request spacing needs local storage.");
        } catch (Exception error) when (error is IOException or UnauthorizedAccessException or ArgumentException) {
            throw new TopicPacingException("Local request-spacing storage is unavailable. Public checks paused.");
        }
        this.utc = utc ?? (() => DateTimeOffset.UtcNow);
        this.monotonic = monotonic ?? (() => Environment.TickCount64);
        startedUtc = this.utc(); startedTick = this.monotonic();
    }

    public void Check(GameTarget target) => Access(target, null);
    public Guid Reserve(GameTarget target, IReadOnlyList<IPAddress> addresses) {
        if (addresses.Count is < 1 or > 32 || addresses.Any(ip => !Connection.IsPublicIPv4(ip)))
            throw new IOException("Unsafe request-spacing address set.");
        return Access(target, addresses.Select(ip => ip.ToString()).Distinct(StringComparer.Ordinal).ToArray())!.Value;
    }

    private Guid? Access(GameTarget target, string[]? addresses) {
        target.Validate();
        return Locked((state, statePath) => {
            var now = Clock();
            var tick = monotonic();
            var remaining = TimeSpan.Zero;
            foreach (var entry in state.Entries) {
                var sameTarget = entry.Provider == target.Provider && entry.Port == target.Port;
                var sameAddress = addresses != null && entry.Port == target.Port && entry.Addresses.Intersect(addresses, StringComparer.Ordinal).Any();
                if (!sameTarget && !sameAddress) continue;
                TimeSpan delay;
                if (entry.ReservedTick is { } reservedTick && tick >= reservedTick) {
                    // TickCount64 is system-wide across processes. After a reboot, a
                    // positive difference is conservative: new uptime alone exceeds it.
                    delay = TimeSpan.FromMilliseconds(Math.Max(0, ReservationSeconds * 1000L - (tick - reservedTick)));
                } else {
                    // A lower uptime means a new boot; waiting for its first 133s
                    // is enough, without restarting the wait on every launcher open.
                    delay = TimeSpan.FromMilliseconds(Math.Max(0, StartupGuardSeconds * 1000L - tick));
                    if (entry.ReservedTick == null) {
                        // 1.0.5 stored only wall time. Preserve one conservative
                        // migration guard until this target receives an uptime anchor.
                        delay = TimeSpan.FromMilliseconds(Math.Max(0, StartupGuardSeconds * 1000L - (tick - startedTick)));
                        var wallDelay = entry.NotBefore - now;
                        if (wallDelay > TimeSpan.FromSeconds(ReservationSeconds + 2))
                            throw new IOException("Stored request timing is ahead of the clock. Checks paused.");
                        if (wallDelay > delay) delay = wallDelay;
                    }
                }
                if (delay > remaining) remaining = delay;
            }
            if (remaining > TimeSpan.Zero) {
                var entry = state.Entries.SingleOrDefault(item => item.Provider == target.Provider && item.Port == target.Port);
                throw new TopicWaitException(remaining, Cached(entry, now));
            }
            if (addresses == null) return (Guid?)null;
            // Persist BEFORE Topic bytes, including attempts whose response later fails.
            var requestId = Guid.NewGuid();
            var next = state.Entries.Where(entry => entry.Provider != target.Provider || entry.Port != target.Port).ToList();
            next.Add(new Entry(target.Provider, target.Port, addresses, now, now.AddSeconds(ReservationSeconds), tick, requestId));
            Write(statePath, new State(2, next.ToArray()));
            return requestId;
        });
    }

    internal RecentGameStatus Remember(Guid requestId, GameServer status, IPAddress address) {
        status.Target.Validate();
        if (!Connection.IsPublicIPv4(address)) throw new IOException("Unsafe status respondent.");
        lock (gate) {
            var proof = new RecentGameStatus(requestId, status, address, monotonic);
            recent[status.Target] = proof; // At most the four configured targets; never persisted.
            return proof;
        }
    }

    public void Record(GameTarget target, Guid requestId, GameServer? status) {
        target.Validate();
        if (status != null && status.Target != target) throw new IOException("Cached status target changed.");
        if (status == null) lock (gate) {
            if (recent.TryGetValue(target, out var proof) && proof.RequestId == requestId) recent.Remove(target);
        }
        Locked((state, statePath) => {
            var now = Clock();
            var entry = state.Entries.SingleOrDefault(item => item.Provider == target.Provider && item.Port == target.Port);
            // A late completion cannot replace a newer request or its result.
            if (entry == null || entry.RequestId != requestId) return false;
            var result = new Result(status == null ? null : ByondStatus.CacheJson(status), status?.CheckedAt ?? now);
            var updated = entry with { Result = result };
            ValidateResult(updated);
            Write(statePath, new State(2, state.Entries.Select(item => item == entry ? updated : item).ToArray()));
            return true;
        });
    }

    private CachedStatus? Cached(Entry? entry, DateTimeOffset now) {
        if (entry == null) return null;
        var target = new GameTarget(entry.Provider, entry.Port);
        recent.TryGetValue(target, out var proof);
        if (proof != null && (proof.RequestId != entry.RequestId || !entry.Addresses.Contains(proof.Address.ToString(), StringComparer.Ordinal) ||
            (entry.Result != null && (entry.Result.CheckedAt != proof.Status.CheckedAt || entry.Result.Json != ByondStatus.CacheJson(proof.Status)))))
            proof = null;
        // A fresh in-process successful response remains usable if display-cache writing
        // contended. A recorded failure/replacement cannot inherit that response proof.
        var checkedAt = entry.Result?.CheckedAt ?? proof?.Status.CheckedAt;
        if (checkedAt == null) return null;
        var age = now - checkedAt.Value;
        if (age < TimeSpan.Zero || age > TimeSpan.FromMinutes(10)) return null;
        var server = entry.Result == null ? proof?.Status : entry.Result.Json == null ? null :
            ByondStatus.ParseJson(System.Text.Encoding.UTF8.GetBytes(entry.Result.Json), target, checkedAt.Value);
        return new CachedStatus(server, checkedAt.Value, (int)Math.Ceiling(age.TotalSeconds)) {
            Recent = proof?.IsFresh(now) == true ? proof : null
        };
    }

    private T Locked<T>(Func<State, string, T> action) {
        lock (gate) {
            try {
                CheckPaths();
                Directory.CreateDirectory(directory);
                CheckPaths();
                var lockPath = Path.Combine(directory, "requests.lock");
                var statePath = Path.Combine(directory, "requests.json");
                if (File.Exists(statePath) && !File.Exists(lockPath))
                    throw new IOException("Request-spacing lock is missing. Checks paused.");
                FileStream owner;
                var created = false;
                try { owner = new FileStream(lockPath, FileMode.CreateNew, FileAccess.ReadWrite, FileShare.None); created = true; }
                catch (IOException) when (File.Exists(lockPath)) {
                    try { owner = new FileStream(lockPath, FileMode.Open, FileAccess.ReadWrite, FileShare.None); }
                    catch (IOException error) when ((error.HResult & 0xffff) is 32 or 33) {
                        throw new TopicWaitException(TimeSpan.FromSeconds(1));
                    }
                }
                using (owner) {
                    CheckPaths();
                    if (created) {
                        if (File.Exists(statePath)) throw new IOException("Request-spacing state needs review.");
                        Write(statePath, new State(2, []));
                    }
                    if (!File.Exists(statePath)) throw new IOException("Request-spacing state is missing. Checks paused.");
                    return action(Read(statePath), statePath);
                }
            } catch (TopicPacingException) { throw; }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or ArgumentException) {
                throw new TopicPacingException("Shared request-spacing state is unavailable or invalid. Public checks paused.");
            }
        }
    }

    private DateTimeOffset Clock() {
        // Keep this anchor fixed: rebaselining on early checks could absorb many
        // small wall-clock advances and prematurely expire a persisted reservation.
        var now = utc();
        var elapsed = monotonic() - startedTick;
        if (now.Offset != TimeSpan.Zero || monotonic() < 0 || elapsed < 0 || Math.Abs((now - startedUtc).TotalMilliseconds - elapsed) > 2000)
            throw new IOException("Clock changed. Public checks paused.");
        return now;
    }
    private static State Read(string path) {
        if (new FileInfo(path).Length is < 1 or > 32768) throw new IOException("Invalid spacing state size.");
        var bytes = File.ReadAllBytes(path);
        using var document = JsonDocument.Parse(bytes, new JsonDocumentOptions { MaxDepth = 8 });
        ByondStatus.RejectDuplicateProperties(document.RootElement);
        var state = JsonSerializer.Deserialize<State>(bytes, json) ?? throw new IOException("Invalid spacing state.");
        if (state.Schema is not (1 or 2) || state.Entries == null || state.Entries.Length > 4) throw new IOException("Invalid spacing state.");
        var seen = new HashSet<GameTarget>();
        foreach (var entry in state.Entries) {
            if (entry == null) throw new IOException("Invalid spacing entry.");
            var target = new GameTarget(entry.Provider, entry.Port); target.Validate();
            if (!seen.Add(target) || entry.Addresses == null || entry.Addresses.Length is < 1 or > 32 ||
                entry.Addresses.Distinct(StringComparer.Ordinal).Count() != entry.Addresses.Length ||
                entry.Addresses.Any(ip => !IPAddress.TryParse(ip, out var address) || !Connection.IsPublicIPv4(address) || address.ToString() != ip) ||
                entry.ReservedAt.Offset != TimeSpan.Zero || entry.NotBefore.Offset != TimeSpan.Zero ||
                entry.ReservedAt < DateTimeOffset.UnixEpoch || entry.NotBefore - entry.ReservedAt != TimeSpan.FromSeconds(ReservationSeconds))
                throw new IOException("Invalid spacing entry.");
            if ((entry.ReservedTick == null) != (entry.RequestId == null) || entry.ReservedTick < 0 || entry.RequestId == Guid.Empty ||
                (state.Schema == 1 && (entry.ReservedTick != null || entry.Result != null)))
                throw new IOException("Invalid monotonic request anchor.");
            ValidateResult(entry);
        }
        return state;
    }
    private static void ValidateResult(Entry entry) {
        if (entry.Result is not { } result) return;
        if (entry.RequestId == null || result.CheckedAt.Offset != TimeSpan.Zero || result.CheckedAt < entry.ReservedAt ||
            result.CheckedAt > entry.NotBefore || result.Json?.Length > 4096)
            throw new IOException("Invalid cached result.");
        if (result.Json != null) _ = ByondStatus.ParseJson(System.Text.Encoding.UTF8.GetBytes(result.Json),
            new GameTarget(entry.Provider, entry.Port), result.CheckedAt);
    }
    private void Write(string path, State state) {
        var temporary = Path.Combine(directory, "requests-" + Guid.NewGuid().ToString("N") + ".tmp");
        try {
            var bytes = JsonSerializer.SerializeToUtf8Bytes(state, json);
            using (var file = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None)) {
                file.Write(bytes); file.Flush(true);
            }
            File.Move(temporary, path, true);
        } finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
    private void CheckPaths() {
        for (DirectoryInfo? item = new(directory); item != null; item = item.Parent)
            if (IsLink(item.FullName))
                throw new IOException("Linked request-spacing paths are not allowed.");
        foreach (var name in new[] { "requests.lock", "requests.json" }) {
            var path = Path.Combine(directory, name);
            if (IsLink(path))
                throw new IOException("Linked request-spacing files are not allowed.");
        }
    }
    private static bool IsLink(string path) {
        try { return (File.GetAttributes(path) & FileAttributes.ReparsePoint) != 0; }
        catch (FileNotFoundException) { return false; }
        catch (DirectoryNotFoundException) { return false; }
    }
}
