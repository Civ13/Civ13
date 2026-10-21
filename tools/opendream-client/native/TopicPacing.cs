using System.Net;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Civ13.Launcher;

public class TopicPacingException(string message) : IOException(message);
public sealed class TopicWaitException(TimeSpan remaining) : TopicPacingException("Public status request spacing is still active.") {
    public int Seconds { get; } = Math.Max(1, (int)Math.Ceiling(remaining.TotalSeconds));
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
    private bool initialized;
    private bool startupGuard;
    private static readonly JsonSerializerOptions json = new() {
        UnmappedMemberHandling = JsonUnmappedMemberHandling.Disallow, MaxDepth = 8
    };
    private sealed record Entry(string Provider, int Port, string[] Addresses, DateTimeOffset ReservedAt, DateTimeOffset NotBefore);
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
    public void Reserve(GameTarget target, IReadOnlyList<IPAddress> addresses) {
        if (addresses.Count is < 1 or > 32 || addresses.Any(ip => !Connection.IsPublicIPv4(ip)))
            throw new IOException("Unsafe request-spacing address set.");
        Access(target, addresses.Select(ip => ip.ToString()).Distinct(StringComparer.Ordinal).ToArray());
    }

    private void Access(GameTarget target, string[]? addresses) {
        target.Validate();
        lock (gate) {
            try {
                CheckPaths();
                Directory.CreateDirectory(directory);
                CheckPaths();
                var lockPath = Path.Combine(directory, "requests.lock");
                var statePath = Path.Combine(directory, "requests.json");
                if (File.Exists(statePath) && !File.Exists(lockPath))
                    throw new IOException("Request-spacing lock is missing. Checks paused.");
                var created = false;
                FileStream owner;
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
                        // Missing lock beside old state is inconsistent, not permission to reset.
                        if (File.Exists(statePath)) throw new IOException("Request-spacing state needs review.");
                        Write(statePath, new State(1, []));
                    }
                    if (!File.Exists(statePath)) throw new IOException("Request-spacing state is missing. Checks paused.");
                    var state = Read(statePath);
                    if (!initialized) { startupGuard = !created && state.Entries.Length != 0; initialized = true; }
                    var now = Clock();
                    var remaining = startupGuard
                        ? TimeSpan.FromMilliseconds(Math.Max(0, StartupGuardSeconds * 1000L - (monotonic() - startedTick))) : TimeSpan.Zero;
                    foreach (var entry in state.Entries) {
                        var sameTarget = entry.Provider == target.Provider && entry.Port == target.Port;
                        var sameAddress = addresses != null && entry.Port == target.Port && entry.Addresses.Intersect(addresses, StringComparer.Ordinal).Any();
                        if (!sameTarget && !sameAddress) continue;
                        var delay = entry.NotBefore - now;
                        if (delay > TimeSpan.FromSeconds(ReservationSeconds + 2))
                            throw new IOException("Stored request timing is ahead of the clock. Checks paused.");
                        if (delay > remaining) remaining = delay;
                    }
                    if (remaining > TimeSpan.Zero) throw new TopicWaitException(remaining);
                    if (addresses == null) return;
                    // Persist BEFORE Topic bytes, including attempts whose response later fails.
                    var next = state.Entries.Where(entry => entry.Provider != target.Provider || entry.Port != target.Port).ToList();
                    next.Add(new Entry(target.Provider, target.Port, addresses, now, now.AddSeconds(ReservationSeconds)));
                    Write(statePath, new State(1, next.ToArray()));
                }
            } catch (TopicPacingException) { throw; }
            catch (Exception error) when (error is IOException or UnauthorizedAccessException or JsonException or ArgumentException) {
                throw new TopicPacingException("Shared request-spacing state is unavailable or invalid. Public checks paused.");
            }
        }
    }

    private DateTimeOffset Clock() {
        var now = utc();
        var elapsed = monotonic() - startedTick;
        if (now.Offset != TimeSpan.Zero || elapsed < 0 || Math.Abs((now - startedUtc).TotalMilliseconds - elapsed) > 2000)
            throw new IOException("Clock changed. Public checks paused.");
        return now;
    }
    private static State Read(string path) {
        if (new FileInfo(path).Length is < 1 or > 32768) throw new IOException("Invalid spacing state size.");
        var bytes = File.ReadAllBytes(path);
        using var document = JsonDocument.Parse(bytes, new JsonDocumentOptions { MaxDepth = 8 });
        ByondStatus.RejectDuplicateProperties(document.RootElement);
        var state = JsonSerializer.Deserialize<State>(bytes, json) ?? throw new IOException("Invalid spacing state.");
        if (state.Schema != 1 || state.Entries == null || state.Entries.Length > 4) throw new IOException("Invalid spacing state.");
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
        }
        return state;
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
