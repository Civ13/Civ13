using System.Buffers.Binary;
using System.Collections.Concurrent;
using System.IO.Pipes;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Civ13.Launcher;

// "Playing Civ13" on the player's Discord profile, through the Discord desktop
// app's local RPC pipe (\\.\pipe\discord-ipc-N). It needs only a public
// application ID: no SDK download, login, OAuth scope or token. Nothing is sent
// when Discord is not running, the player turned it off, or no ID is set.
// Presence names the server, never the BYOND key, character or location.
public sealed record PresenceSettings(bool ShowActivity, string? ApplicationId) {
    public const string FileName = "discord.json";
    // VZGCivilizationBot's public application ID; discord.json can override it.
    public const string BuiltInApplicationId = "1562126764849897544";

    public static PresenceSettings Load(string root) {
        var id = ValidId(BuiltInApplicationId);
        var show = true;
        try {
            var path = Path.Combine(root, FileName);
            if (File.Exists(path)) {
                using var document = JsonDocument.Parse(File.ReadAllText(path));
                var json = document.RootElement;
                if (json.TryGetProperty("show_activity", out var value) && value.ValueKind is JsonValueKind.True or JsonValueKind.False) show = value.GetBoolean();
                if (json.TryGetProperty("application_id", out var app) && app.ValueKind == JsonValueKind.String) id = ValidId(app.GetString()) ?? id;
            }
        } catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException) { }
        return new PresenceSettings(show, id);
    }

    // Changes only show_activity: every other setting already in the file, such as
    // application_id or the Discord sign-in settings, is kept as it was.
    public static void SaveShowActivity(string root, bool show) {
        var path = Path.Combine(root, FileName);
        var json = new System.Text.Json.Nodes.JsonObject();
        try {
            if (File.Exists(path) && System.Text.Json.Nodes.JsonNode.Parse(File.ReadAllText(path)) is System.Text.Json.Nodes.JsonObject existing) json = existing;
        } catch (JsonException) { }
        json["show_activity"] = show;
        File.WriteAllText(path, json.ToJsonString());
    }

    public static string? ValidId(string? id) => id != null && Regex.IsMatch(id, "^[0-9]{17,20}$") ? id : null;
}

public sealed class DiscordPresence : IDisposable {
    private const int Handshake = 0, Frame = 1, Close = 2;
    private static readonly TimeSpan Timeout = TimeSpan.FromSeconds(2);
    private readonly string applicationId;
    private readonly Func<Stream?> open;
    private readonly int processId;
    private readonly BlockingCollection<object?> requests = new(new ConcurrentQueue<object?>(), 16);
    private readonly Thread worker;
    private Stream? pipe;
    public bool Connected => pipe != null;
    // Last result, for the launcher log: null until the first request settles.
    public string? LastResult { get; private set; }

    public DiscordPresence(string applicationId, Func<Stream?>? open = null, int? processId = null) {
        this.applicationId = PresenceSettings.ValidId(applicationId) ?? throw new ArgumentException("Invalid Discord application ID.", nameof(applicationId));
        this.open = open ?? OpenWindowsPipe;
        this.processId = processId ?? Environment.ProcessId;
        worker = new Thread(Work) { IsBackground = true, Name = "Discord presence" };
        worker.Start();
    }

    // "NOMADS_GAIA on civ13.com"; the map and the public host only.
    public static string ServerLine(GameServer server) => ServerLine(server.Map, server.Host);
    public static string ServerLine(string map, string host) => map.Length > 0 ? map + " on " + host : host;

    public void Browsing() => Post(Activity("In the launcher", "Choosing a server", null));
    public void Playing(string server, DateTimeOffset since) => Post(Activity("Playing Civ13", server, since));
    public void Clear() => Post(null);

    // A full queue drops the request rather than block the window.
    private void Post(object? activity) {
        if (!requests.IsAddingCompleted) requests.TryAdd(activity);
    }

    private static object Activity(string details, string state, DateTimeOffset? since) {
        static string Bound(string text) => text.Length <= 128 ? text : text[..128];
        return since is { } start
            ? new { details = Bound(details), state = Bound(state), timestamps = new { start = start.ToUnixTimeSeconds() } }
            : new { details = Bound(details), state = Bound(state) };
    }

    private void Work() {
        foreach (var activity in requests.GetConsumingEnumerable()) {
            try {
                pipe ??= Connect();
                if (pipe == null) { LastResult = "Discord is not running."; continue; }
                var nonce = Guid.NewGuid().ToString();
                Write(pipe, Frame, new { cmd = "SET_ACTIVITY", args = new { pid = processId, activity }, nonce });
                var (_, reply) = Read(pipe);
                LastResult = reply.Contains("\"evt\":\"ERROR\"") ? "Discord refused the activity." : activity == null ? "Cleared." : "Shown.";
            } catch (Exception e) when (e is IOException or ObjectDisposedException or OperationCanceledException or InvalidDataException or TimeoutException) {
                Drop();
                LastResult = "Discord connection lost.";
            }
        }
        if (pipe != null) {
            try { Write(pipe, Close, new { }); } catch (Exception e) when (e is IOException or ObjectDisposedException) { }
            Drop();
        }
    }

    private Stream? Connect() {
        var stream = open();
        if (stream == null) return null;
        try {
            Write(stream, Handshake, new { v = 1, client_id = applicationId });
            var (op, ready) = Read(stream);
            if (op != Frame || !ready.Contains("\"READY\"")) throw new InvalidDataException("Discord did not accept the handshake.");
            return stream;
        } catch {
            stream.Dispose();
            throw;
        }
    }

    private void Drop() {
        pipe?.Dispose();
        pipe = null;
    }

    internal static void Write(Stream stream, int op, object body) {
        var json = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(body));
        var frame = new byte[8 + json.Length];
        BinaryPrimitives.WriteInt32LittleEndian(frame, op);
        BinaryPrimitives.WriteInt32LittleEndian(frame.AsSpan(4), json.Length);
        json.CopyTo(frame, 8);
        using var timeout = new CancellationTokenSource(Timeout);
        stream.WriteAsync(frame, timeout.Token).AsTask().GetAwaiter().GetResult();
        stream.Flush();
    }

    internal static (int Op, string Json) Read(Stream stream) {
        var header = ReadExactly(stream, 8);
        var op = BinaryPrimitives.ReadInt32LittleEndian(header);
        var length = BinaryPrimitives.ReadInt32LittleEndian(header.AsSpan(4));
        if (length is < 0 or > 65536) throw new InvalidDataException("Oversized Discord frame.");
        return (op, Encoding.UTF8.GetString(ReadExactly(stream, length)));
    }

    private static byte[] ReadExactly(Stream stream, int count) {
        var buffer = new byte[count];
        using var timeout = new CancellationTokenSource(Timeout);
        stream.ReadExactlyAsync(buffer, timeout.Token).AsTask().GetAwaiter().GetResult();
        return buffer;
    }

    private static Stream? OpenWindowsPipe() {
        if (!OperatingSystem.IsWindows()) return null;
        for (var index = 0; index < 10; index++) {
            var client = new NamedPipeClientStream(".", "discord-ipc-" + index, PipeDirection.InOut, PipeOptions.Asynchronous);
            try { client.Connect(100); return client; }
            catch (Exception e) when (e is TimeoutException or IOException or UnauthorizedAccessException) { client.Dispose(); }
        }
        return null;
    }

    public void Dispose() {
        requests.CompleteAdding();
        worker.Join(TimeSpan.FromSeconds(3));
        requests.Dispose();
    }
}
