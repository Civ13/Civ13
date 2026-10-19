using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;

namespace Civ13.Launcher;

// Only the validated directory parser constructs entries. No mutable catalog or port fallback.
public sealed class GameServer {
    public string Provider { get; }
    public string Id { get; }
    public string Name { get; }
    public string Host { get; }
    public int Port { get; }
    public string Engine => "BYOND";
    public int Players { get; }
    public string Map { get; }
    public string Mode { get; }
    public string Epoch { get; }
    public string RoundId { get; }
    public string RoundState { get; }
    public int RoundDurationSeconds { get; }
    public DateTimeOffset CheckedAt { get; }
    public DateTimeOffset ExpiresAt { get; }
    internal GameServer(string provider, string id, string name, string host, int port, int players,
        string map, string mode, string epoch, string roundId, string roundState, int duration,
        DateTimeOffset checkedAt, DateTimeOffset expiresAt) {
        Provider = provider; Id = id; Name = name; Host = host; Port = port; Players = players;
        Map = map; Mode = mode; Epoch = epoch; RoundId = roundId; RoundState = roundState;
        RoundDurationSeconds = duration; CheckedAt = checkedAt; ExpiresAt = expiresAt;
    }
    public void Validate(DateTimeOffset now) {
        if (Host != ServerCatalog.Host(Provider) || Port is < 1 or > 65535 ||
            now >= ExpiresAt || CheckedAt > now.AddSeconds(5) || now - CheckedAt > TimeSpan.FromSeconds(120))
            throw new IOException("Server information expired or failed endpoint validation. Refresh the directory.");
    }
    public bool SameTarget(GameServer other) => Provider == other.Provider && Id == other.Id &&
        Host == other.Host && Port == other.Port && Engine == other.Engine;
}

public sealed class ServerDirectory {
    public const int MaxBytes = 65536;
    public const int MaxServers = 32;
    public DateTimeOffset GeneratedAt { get; }
    public DateTimeOffset ExpiresAt { get; }
    public IReadOnlyList<GameServer> Servers { get; }
    private ServerDirectory(DateTimeOffset generatedAt, DateTimeOffset expiresAt, List<GameServer> servers) {
        GeneratedAt = generatedAt; ExpiresAt = expiresAt; Servers = servers.AsReadOnly();
    }
    public static ServerDirectory Read(string provider, ReadOnlyMemory<byte> json, DateTimeOffset now) {
        var host = ServerCatalog.Host(provider);
        if (json.Length > MaxBytes) throw new IOException("Server directory is too large.");
        try {
            using var document = JsonDocument.Parse(json, new JsonDocumentOptions { MaxDepth = 8 });
            var root = document.RootElement;
            RejectDuplicateProperties(root);
            if (Number(root, "schema", 1, 1) != 1) throw new IOException("Unsupported server directory schema.");
            var generated = Timestamp(root, "generated_at");
            var expires = Timestamp(root, "expires_at");
            if (generated > now.AddSeconds(5) || generated <= now.AddSeconds(-120) ||
                expires <= now || expires <= generated || expires - generated > TimeSpan.FromSeconds(120))
                throw new IOException("Server directory is stale or has invalid freshness information.");
            var entries = Property(root, "servers");
            if (entries.ValueKind != JsonValueKind.Array || entries.GetArrayLength() > MaxServers)
                throw new IOException("Invalid server directory entries.");
            var servers = new List<GameServer>();
            var ids = new HashSet<string>(StringComparer.Ordinal);
            var targets = new HashSet<int>();
            foreach (var item in entries.EnumerateArray()) {
                GameServer server;
                try {
                    if (Property(item, "online").ValueKind != JsonValueKind.True) continue;
                    var checkedAt = Timestamp(item, "checked_at");
                    if (checkedAt > generated || checkedAt < generated.AddSeconds(-60) ||
                        checkedAt > now.AddSeconds(5) || now - checkedAt > TimeSpan.FromSeconds(120)) continue;
                    var id = Text(item, "id", 64);
                    if (!id.All(c => char.IsAsciiLetterOrDigit(c) || c is '-' or '_' or '.')) continue;
                    if (Text(item, "host", 253) != host || Text(item, "engine", 16) != "BYOND") continue;
                    var round = Property(item, "round");
                    var validUntil = expires < checkedAt.AddSeconds(120) ? expires : checkedAt.AddSeconds(120);
                    server = new GameServer(provider, id, Text(item, "name", 120), host,
                        Number(item, "port", 1, 65535), Number(item, "players", 0, 10000),
                        Text(item, "map", 160), Text(item, "mode", 80), OptionalText(item, "epoch", 32),
                        Text(round, "id", 80, allowEmpty: true), OptionalText(round, "state", 40),
                        Number(round, "duration_seconds", 0, int.MaxValue), checkedAt, validUntil);
                    server.Validate(now);
                } catch (IOException) { continue; } // Incomplete/invalid records never become selectable.
                if (!ids.Add(server.Id) || !targets.Add(server.Port))
                    throw new IOException("Ambiguous duplicate server identity or endpoint.");
                servers.Add(server);
            }
            return new ServerDirectory(generated, expires, servers);
        } catch (JsonException e) { throw new IOException("Invalid server directory JSON.", e); }
    }
    private static JsonElement Property(JsonElement item, string name) {
        if (item.ValueKind != JsonValueKind.Object || !item.TryGetProperty(name, out var value))
            throw new IOException("Required directory field missing.");
        return value;
    }
    private static int Number(JsonElement item, string name, int minimum, int maximum) {
        var value = Property(item, name);
        if (value.ValueKind != JsonValueKind.Number || !value.TryGetInt32(out var number) || number < minimum || number > maximum)
            throw new IOException("Invalid directory number.");
        return number;
    }
    private static string OptionalText(JsonElement item, string name, int maximum) =>
        item.ValueKind == JsonValueKind.Object && item.TryGetProperty(name, out _) ? Text(item, name, maximum, true) : "";
    private static string Text(JsonElement item, string name, int maximum, bool allowEmpty = false) {
        var value = Property(item, name);
        if (value.ValueKind != JsonValueKind.String) throw new IOException("Invalid directory text.");
        var text = value.GetString()!;
        if (text.Length > maximum || (!allowEmpty && string.IsNullOrWhiteSpace(text)) ||
            text.Any(c => char.IsControl(c) || (char.GetUnicodeCategory(c) is UnicodeCategory.Format or UnicodeCategory.LineSeparator or UnicodeCategory.ParagraphSeparator) || char.IsSurrogate(c)))
            throw new IOException("Invalid directory display text.");
        return text;
    }
    private static DateTimeOffset Timestamp(JsonElement item, string name) {
        var value = Text(item, name, 20);
        if (!DateTimeOffset.TryParseExact(value, "yyyy-MM-dd'T'HH:mm:ss'Z'", CultureInfo.InvariantCulture,
            DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal, out var timestamp))
            throw new IOException("Invalid directory timestamp.");
        return timestamp;
    }
    private static void RejectDuplicateProperties(JsonElement item) {
        if (item.ValueKind == JsonValueKind.Object) {
            var names = new HashSet<string>(StringComparer.Ordinal);
            foreach (var property in item.EnumerateObject()) {
                if (!names.Add(property.Name)) throw new IOException("Duplicate directory property.");
                RejectDuplicateProperties(property.Value);
            }
        } else if (item.ValueKind == JsonValueKind.Array)
            foreach (var child in item.EnumerateArray()) RejectDuplicateProperties(child);
    }
}

public interface IServerDirectoryTransport {
    Task<ReadOnlyMemory<byte>> Fetch(string provider, CancellationToken cancellationToken = default);
}

public sealed class ServerDirectoryTransport : IServerDirectoryTransport, IDisposable {
    public static readonly TimeSpan RequestTimeout = TimeSpan.FromSeconds(8);
    private readonly HttpClient client;
    private readonly TimeSpan timeout;
    public ServerDirectoryTransport(HttpMessageHandler? handler = null, TimeSpan? requestTimeout = null) {
        // The production handler never follows redirects or sends cookies/credentials.
        client = new HttpClient(handler ?? new HttpClientHandler { AllowAutoRedirect = false, UseCookies = false }) {
            Timeout = Timeout.InfiniteTimeSpan
        };
        timeout = requestTimeout ?? RequestTimeout;
    }
    public async Task<ReadOnlyMemory<byte>> Fetch(string provider, CancellationToken cancellationToken = default) {
        var uri = ServerCatalog.DirectoryUrl(provider);
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        deadline.CancelAfter(timeout);
        try {
            using var request = new HttpRequestMessage(HttpMethod.Get, uri);
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            request.Headers.CacheControl = new CacheControlHeaderValue { NoCache = true, NoStore = true };
            using var response = await client.SendAsync(request, HttpCompletionOption.ResponseHeadersRead, deadline.Token);
            if (response.RequestMessage?.RequestUri != uri || response.StatusCode != HttpStatusCode.OK)
                throw new IOException("Directory unavailable: expected a direct HTTPS 200 response.");
            if (response.Content.Headers.ContentType?.MediaType != "application/json")
                throw new IOException("Directory unavailable: expected JSON content.");
            if (response.Content.Headers.ContentLength > ServerDirectory.MaxBytes)
                throw new IOException("Server directory is too large.");
            await using var stream = await response.Content.ReadAsStreamAsync(deadline.Token);
            using var output = new MemoryStream();
            var buffer = new byte[4096];
            while (true) {
                var count = await stream.ReadAsync(buffer, deadline.Token);
                if (count == 0) break;
                if (output.Length + count > ServerDirectory.MaxBytes) throw new IOException("Server directory is too large.");
                output.Write(buffer, 0, count);
            }
            return output.ToArray();
        } catch (OperationCanceledException e) { throw new IOException("Server directory request timed out or was cancelled. Try Refresh.", e); }
          catch (HttpRequestException e) { throw new IOException("Server directory HTTPS request failed. Try Refresh.", e); }
    }
    public void Dispose() => client.Dispose();
}
