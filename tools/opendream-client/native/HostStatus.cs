using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace Civ13.Launcher;

public delegate Task<ReadOnlyMemory<byte>> DoormanProbe(IPAddress address, int port, string query, CancellationToken token);

// A host can freeze an idle server (scripts/gaia-host serve). Its doorman reports
// each instance's state and last cached status. This is display data and a wake
// target only: it never becomes a GameServer, supplies no address and grants no
// join. Joining still needs a fresh direct status from the configured game port.
// Routed: the world sits behind the host's routing relay (scripts/gaia-host/relay.py);
// its port is closed to players, who join through the gate world instead.
public sealed record DormantServer(GameTarget Target, string State, int Players, string Map, string Mode,
    int? CachedAgeSeconds, int WakeEstimateSeconds, bool Routed = false) {
    public string Name => Target.Name;
    public string Provider => Target.Provider;
}

public static class HostStatus {
    // One reviewed doorman port per approved host, next to the game candidates.
    public const int DoormanPort = 1713;
    public static readonly TimeSpan Timeout = TimeSpan.FromSeconds(2);
    public static readonly TimeSpan WakeLimit = TimeSpan.FromSeconds(60);
    public static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(2);
    public const int MaxBytes = 8192;
    private static readonly string[] States = ["awake", "asleep", "waking", "stopped"];
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);

    // Every configured candidate the doorman reported, by target.
    public static async Task<IReadOnlyDictionary<GameTarget, DormantServer>> Query(string provider,
        Func<string, Task<IPAddress[]>>? resolver = null, DoormanProbe? probe = null, CancellationToken token = default) {
        var root = await Ask(provider, "?host_status=1", resolver, probe, token);
        return ParseInstances(root, provider);
    }

    // Asks the doorman to thaw one configured instance; returns its state.
    public static async Task<string> Wake(GameTarget target, Func<string, Task<IPAddress[]>>? resolver = null,
        DoormanProbe? probe = null, CancellationToken token = default) {
        target.Validate();
        var json = await Ask(target.Provider, "?wake=1&port=" + target.Port, resolver, probe, token);
        return ParseWake(json, target);
    }

    private static async Task<ReadOnlyMemory<byte>> Ask(string provider, string query,
        Func<string, Task<IPAddress[]>>? resolver, DoormanProbe? probe, CancellationToken cancellationToken) {
        var host = ServerCatalog.Host(provider);
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        deadline.CancelAfter(Timeout);
        try {
            var addresses = await Connection.ResolveAddresses(host, resolver, deadline.Token);
            foreach (var address in addresses) {
                try {
                    return Unframe(await (probe ?? Fetch)(address, DoormanPort, query, deadline.Token));
                } catch (SocketException) {
                    continue; // refused or unreachable; the next A record may answer
                }
            }
        } catch (OperationCanceledException error) {
            throw new IOException("The host's server status service did not answer.", error);
        } catch (SocketException error) {
            throw new IOException("The host's server status service is unavailable.", error);
        }
        throw new IOException("The host's server status service is unavailable.");
    }

    private static async Task<ReadOnlyMemory<byte>> Fetch(IPAddress address, int port, string query, CancellationToken token) {
        if (!Connection.IsPublicIPv4(address)) throw new IOException("Invalid public status endpoint.");
        using var client = new TcpClient(AddressFamily.InterNetwork);
        await client.ConnectAsync(address, port, token);
        await using var stream = client.GetStream();
        var bytes = Encoding.ASCII.GetBytes(query + "\0");
        var request = new byte[9 + bytes.Length];
        request[1] = 0x83;
        var length = bytes.Length + 5;
        request[2] = (byte)(length >> 8); request[3] = (byte)length;
        bytes.CopyTo(request, 9);
        await stream.WriteAsync(request, token);
        return await ByondStatus.ReadResponse(stream, token);
    }

    private static ReadOnlyMemory<byte> Unframe(ReadOnlyMemory<byte> packet) {
        var bytes = packet.Span;
        if (bytes.Length is < 8 or > MaxBytes || bytes[0] != 0 || bytes[1] != 0x83 ||
            ((bytes[2] << 8) | bytes[3]) + 4 != bytes.Length || bytes[4] != 0x06 || bytes[^1] != 0)
            throw new IOException("Invalid host status packet.");
        return packet.Slice(5, packet.Length - 6);
    }

    internal static IReadOnlyDictionary<GameTarget, DormantServer> ParseInstances(ReadOnlyMemory<byte> json, string provider) {
        var configured = ServerCatalog.Candidates(provider);
        var result = new Dictionary<GameTarget, DormantServer>();
        Parse(json, root => {
            if (!root.TryGetProperty("schema", out var schema) || !schema.TryGetInt32(out var version) || version != 1 ||
                !root.TryGetProperty("instances", out var list) || list.ValueKind != JsonValueKind.Array || list.GetArrayLength() > 16)
                throw new IOException("Unsupported host status.");
            foreach (var item in list.EnumerateArray()) {
                if (item.ValueKind != JsonValueKind.Object) throw new IOException("Invalid host status entry.");
                var port = Int(item, "port", 1, 65535) ?? throw new IOException("Host status entry has no port.");
                var target = configured.FirstOrDefault(candidate => candidate.Port == port);
                if (target == null) continue; // an instance this launcher does not offer
                var state = State(item, "state");
                var entry = new DormantServer(target, state, Int(item, "players", 0, 10000) ?? 0,
                    ByondStatus.OptionalText(item, "map_name", 128), ByondStatus.OptionalText(item, "map_gamemode", 80),
                    Int(item, "cached_age", 0, int.MaxValue), Int(item, "wake_estimate", 0, 600) ?? 0,
                    item.TryGetProperty("routed", out var routed) && routed.ValueKind == JsonValueKind.True);
                if (!result.TryAdd(target, entry)) throw new IOException("Duplicate host status entry.");
            }
        });
        return result;
    }

    internal static string ParseWake(ReadOnlyMemory<byte> json, GameTarget target) {
        string state = "";
        Parse(json, root => {
            if (root.TryGetProperty("schema", out var refusedSchema) && refusedSchema.TryGetInt32(out var refusedVersion) && refusedVersion == 1 &&
                root.TryGetProperty("ok", out var refused) && refused.ValueKind == JsonValueKind.False &&
                root.TryGetProperty("error", out var signedOut) && signedOut.ValueKind == JsonValueKind.String && signedOut.GetString() == "byond signed out")
                throw new IOException(target.Name + " cannot start right now: its host is still signing in to BYOND. Try again in a minute.");
            if (root.TryGetProperty("schema", out refusedSchema) && refusedSchema.TryGetInt32(out refusedVersion) && refusedVersion == 1 &&
                root.TryGetProperty("ok", out refused) && refused.ValueKind == JsonValueKind.False &&
                root.TryGetProperty("error", out var error) && error.ValueKind == JsonValueKind.String && error.GetString() == "low memory") {
                // The host keeps a server asleep rather than wake it without memory headroom.
                var free = Int(root, "free_mb", 0, int.MaxValue);
                var need = Int(root, "need_mb", 0, int.MaxValue);
                throw new IOException(target.Name + " cannot wake right now: its host is low on free memory" +
                    (free is { } have && need is { } wanted ? $" ({have} MB free, {wanted} MB needed)" : "") + ". Try again later.");
            }
            if (!root.TryGetProperty("schema", out var schema) || !schema.TryGetInt32(out var version) || version != 1 ||
                !root.TryGetProperty("ok", out var ok) || ok.ValueKind != JsonValueKind.True ||
                Int(root, "port", 1, 65535) != target.Port)
                throw new IOException("The host refused to wake " + target.Name + ".");
            state = State(root, "state");
        });
        return state;
    }

    private static void Parse(ReadOnlyMemory<byte> json, Action<JsonElement> read) {
        if (json.Length is < 2 or > MaxBytes) throw new IOException("Invalid bounded host status.");
        try {
            StrictUtf8.GetCharCount(json.Span);
            using var document = JsonDocument.Parse(json, new JsonDocumentOptions { MaxDepth = 8 });
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object) throw new IOException("Host status must be an object.");
            ByondStatus.RejectDuplicateProperties(root);
            read(root);
        } catch (Exception error) when (error is JsonException or DecoderFallbackException or InvalidOperationException) {
            throw new IOException("Invalid host status JSON.", error);
        }
    }

    private static int? Int(JsonElement item, string name, int minimum, int maximum) {
        if (!item.TryGetProperty(name, out var value)) return null;
        if (!value.TryGetInt32(out var number) || number < minimum || number > maximum)
            throw new IOException("Invalid host status " + name + ".");
        return number;
    }

    private static string State(JsonElement item, string name) {
        if (!item.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String ||
            Array.IndexOf(States, value.GetString()) < 0)
            throw new IOException("Invalid host status state.");
        return value.GetString()!;
    }
}
