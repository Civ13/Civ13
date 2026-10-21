using System.Diagnostics;
using System.Globalization;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace Civ13.Launcher;

// BYOND-specific availability selection. OpenDream keeps its separate operator path.
public static class ByondStatus {
    public static readonly TimeSpan TotalTimeout = TimeSpan.FromSeconds(3);
    public const int MaxBytes = 65536;
    private static readonly UTF8Encoding StrictUtf8 = new(false, true);
    public static async Task<VerifiedGameServer> Query(GameTarget target, Func<string, Task<IPAddress[]>>? resolver = null,
        Func<IPAddress, int, CancellationToken, Task<ReadOnlyMemory<byte>>>? probe = null, Func<DateTimeOffset>? clock = null,
        TimeSpan? timeout = null, CancellationToken cancellationToken = default, GameServer? expected = null) {
        target.Validate();
        if (expected != null && expected.Target != target) throw new IOException("Selected game target changed.");
        clock ??= () => DateTimeOffset.UtcNow;
        var budget = timeout ?? TotalTimeout;
        if (budget <= TimeSpan.Zero || budget > TotalTimeout) throw new IOException("Invalid public status deadline.");
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        deadline.CancelAfter(budget);
        var started = Stopwatch.GetTimestamp();
        try {
            // Validate the ENTIRE answer set before any game socket is opened.
            var addresses = await Connection.ResolveAddresses(target.Host, resolver, deadline.Token);
            var endpoints = addresses.Select(address => new PublicEndpoint(target.Host, address, () => Environment.TickCount64)).ToArray();
            for (var index = 0; index < addresses.Length; index++) {
                var remaining = budget - Stopwatch.GetElapsedTime(started);
                if (remaining <= TimeSpan.Zero || deadline.IsCancellationRequested) break;
                using var attempt = CancellationTokenSource.CreateLinkedTokenSource(deadline.Token);
                // Sequential fair slices keep one active socket and leave time for later A records.
                attempt.CancelAfter(remaining / (addresses.Length - index));
                try {
                    // Production Fetch honors cancellation and disposes its socket before
                    // this task settles; await settlement before starting the next address.
                    var packet = await (probe ?? Fetch)(addresses[index], target.Port, attempt.Token);
                    var status = ParsePacket(packet, target, clock());
                    if (expected != null && !expected.Matches(status))
                        throw new IOException("Game identity changed. Refresh and choose again.");
                    attempt.Token.ThrowIfCancellationRequested();
                    deadline.Token.ThrowIfCancellationRequested();
                    status.Validate(clock());
                    endpoints[index].Validate(target.Host);
                    return new VerifiedGameServer(status, endpoints[index]);
                } catch (Exception error) when (error is IOException or SocketException or OperationCanceledException) {
                    continue;
                }
            }
        } catch (OperationCanceledException error) {
            throw new IOException("Public server verification timed out or was cancelled.", error);
        }
        throw new IOException("No public address returned valid matching BYOND status. Refresh and try again.");
    }

    private static async Task<ReadOnlyMemory<byte>> Fetch(IPAddress address, int port, CancellationToken token) {
        if (!Connection.IsPublicIPv4(address) || port is < 1 or > 65535) throw new IOException("Invalid public status endpoint.");
        using var client = new TcpClient(AddressFamily.InterNetwork);
        // Literal-only connection: no second DNS lookup.
        await client.ConnectAsync(address, port, token);
        await using var stream = client.GetStream();
        var query = Encoding.ASCII.GetBytes("?status=1&format=json\0");
        var request = new byte[9 + query.Length];
        request[1] = 0x83;
        var length = query.Length + 5;
        request[2] = (byte)(length >> 8); request[3] = (byte)length;
        query.CopyTo(request, 9);
        await stream.WriteAsync(request, token);
        return await ReadResponse(stream, token);
    }

    public static async Task<ReadOnlyMemory<byte>> ReadResponse(Stream stream, CancellationToken token) {
        var header = new byte[4];
        await stream.ReadExactlyAsync(header, token);
        var length = (header[2] << 8) | header[3];
        if (header[0] != 0 || header[1] != 0x83 || length < 4 || length + 4 > MaxBytes)
            throw new IOException("Invalid bounded BYOND status frame.");
        var packet = new byte[length + 4];
        header.CopyTo(packet, 0);
        await stream.ReadExactlyAsync(packet.AsMemory(4), token);
        return packet;
    }

    public static GameServer ParsePacket(ReadOnlyMemory<byte> packet, GameTarget target, DateTimeOffset checkedAt) {
        target.Validate();
        var bytes = packet.Span;
        if (bytes.Length is < 8 or > MaxBytes || bytes[0] != 0 || bytes[1] != 0x83 ||
            ((bytes[2] << 8) | bytes[3]) + 4 != bytes.Length || bytes[4] != 0x06 || bytes[^1] != 0)
            throw new IOException("Invalid BYOND status packet.");
        try {
            var json = packet.Slice(5, packet.Length - 6);
            StrictUtf8.GetCharCount(json.Span);
            using var document = JsonDocument.Parse(json, new JsonDocumentOptions { MaxDepth = 16 });
            var root = document.RootElement;
            if (root.ValueKind != JsonValueKind.Object) throw new IOException("BYOND status must be an object.");
            RejectDuplicateProperties(root);
            if (!root.TryGetProperty("players", out var players) || !players.TryGetInt32(out var count) || count is < 0 or > 10000)
                throw new IOException("Invalid BYOND player count.");
            var map = OptionalText(root, "map_name", 128);
            var mode = OptionalText(root, "map_gamemode", 80);
            int? duration = null;
            if (root.TryGetProperty("round_duration_in_ticks", out var ticks)) {
                if (!ticks.TryGetDouble(out var elapsed) || !double.IsFinite(elapsed) || elapsed < 0 || elapsed > int.MaxValue)
                    throw new IOException("Invalid BYOND round duration.");
                duration = (int)Math.Floor(elapsed / 10);
            }
            return new GameServer(target, count, map, mode, OptionalText(root, "map_age", 32, integer: true),
                OptionalText(root, "game_id", 80, integer: true), duration, checkedAt);
        } catch (Exception error) when (error is JsonException or DecoderFallbackException or EncoderFallbackException or InvalidOperationException) {
            throw new IOException("Invalid BYOND status JSON.", error);
        }
    }

    private static string OptionalText(JsonElement root, string name, int maximum, bool integer = false) {
        if (!root.TryGetProperty(name, out var value)) return "";
        if (integer && value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out var number))
            return number.ToString(CultureInfo.InvariantCulture);
        if (value.ValueKind != JsonValueKind.String) throw new IOException("Invalid BYOND status text.");
        var text = value.GetString()!;
        if (StrictUtf8.GetByteCount(text) > maximum) throw new IOException("Oversized BYOND status text.");
        foreach (var rune in text.EnumerateRunes()) {
            if (Rune.GetUnicodeCategory(rune) is UnicodeCategory.Control or UnicodeCategory.Format or
                UnicodeCategory.Surrogate or UnicodeCategory.LineSeparator or UnicodeCategory.ParagraphSeparator)
                throw new IOException("Nonprintable BYOND status text.");
        }
        return string.IsNullOrWhiteSpace(text) ? "" : text;
    }
    private static void RejectDuplicateProperties(JsonElement item) {
        if (item.ValueKind == JsonValueKind.Object) {
            var names = new HashSet<string>(StringComparer.Ordinal);
            foreach (var property in item.EnumerateObject()) {
                if (!names.Add(property.Name)) throw new IOException("Duplicate status property.");
                RejectDuplicateProperties(property.Value);
            }
        } else if (item.ValueKind == JsonValueKind.Array)
            foreach (var child in item.EnumerateArray()) RejectDuplicateProperties(child);
    }
}
