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
    public static async Task<PublicEndpoint> Select(GameServer server, Func<string, Task<IPAddress[]>>? resolver,
        Func<IPAddress, int, CancellationToken, Task<ReadOnlyMemory<byte>>>? probe, Func<DateTimeOffset> clock,
        TimeSpan? timeout = null, CancellationToken cancellationToken = default) {
        server.Validate(clock());
        var budget = timeout ?? TotalTimeout;
        if (budget <= TimeSpan.Zero || budget > TotalTimeout) throw new IOException("Invalid public status deadline.");
        using var deadline = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        deadline.CancelAfter(budget);
        var started = Stopwatch.GetTimestamp();
        try {
            // Validate the ENTIRE answer set before any game socket is opened.
            var addresses = await Connection.ResolveAddresses(server.Host, resolver, deadline.Token);
            var endpoints = addresses.Select(address => new PublicEndpoint(server.Host, address, () => Environment.TickCount64)).ToArray();
            for (var index = 0; index < addresses.Length; index++) {
                var remaining = budget - Stopwatch.GetElapsedTime(started);
                if (remaining <= TimeSpan.Zero || deadline.IsCancellationRequested) break;
                using var attempt = CancellationTokenSource.CreateLinkedTokenSource(deadline.Token);
                // Sequential fair slices keep one active socket and leave time for later A records.
                attempt.CancelAfter(remaining / (addresses.Length - index));
                try {
                    // Production Fetch honors cancellation and disposes its socket before
                    // this task settles; await settlement before starting the next address.
                    var packet = await (probe ?? Fetch)(addresses[index], server.Port, attempt.Token);
                    ValidatePacket(packet, server);
                    attempt.Token.ThrowIfCancellationRequested();
                } catch (Exception error) when (error is IOException or SocketException or OperationCanceledException) {
                    continue;
                }
                deadline.Token.ThrowIfCancellationRequested();
                server.Validate(clock());
                endpoints[index].Validate(server.Host);
                return endpoints[index];
            }
        } catch (OperationCanceledException error) {
            throw new IOException("Public server verification timed out or was cancelled.", error);
        }
        throw new IOException("No public address returned complete matching BYOND status. Refresh and try again.");
    }

    private static async Task<ReadOnlyMemory<byte>> Fetch(IPAddress address, int port, CancellationToken token) {
        if (!Connection.IsPublicIPv4(address) || port is < 1 or > 65535) throw new IOException("Invalid public status endpoint.");
        using var client = new TcpClient(AddressFamily.InterNetwork);
        // Literal-only connection: no second DNS lookup or directory-supplied IP.
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
        if (header[0] != 0 || header[1] != 0x83 || length < 4 || length + 4 > ServerDirectory.MaxBytes)
            throw new IOException("Invalid bounded BYOND status frame.");
        var packet = new byte[length + 4];
        header.CopyTo(packet, 0);
        await stream.ReadExactlyAsync(packet.AsMemory(4), token);
        return packet;
    }

    public static void ValidatePacket(ReadOnlyMemory<byte> packet, GameServer expected) {
        var bytes = packet.Span;
        if (bytes.Length is < 8 or > ServerDirectory.MaxBytes || bytes[0] != 0 || bytes[1] != 0x83 ||
            ((bytes[2] << 8) | bytes[3]) + 4 != bytes.Length || bytes[4] != 0x06 || bytes[^1] != 0)
            throw new IOException("Invalid BYOND status packet.");
        try {
            var json = packet.Slice(5, packet.Length - 6);
            new UTF8Encoding(false, true).GetCharCount(json.Span);
            using var document = JsonDocument.Parse(json, new JsonDocumentOptions { MaxDepth = 16 });
            var root = document.RootElement;
            ServerDirectory.RejectDuplicateProperties(root);
            ServerDirectory.Number(root, "players", 0, 10000);
            var map = ServerDirectory.Text(root, "map_name", 128);
            var mode = ServerDirectory.Text(root, "map_gamemode", 80);
            if (!root.TryGetProperty("round_duration_in_ticks", out var ticks) || !ticks.TryGetDouble(out var elapsed) ||
                !double.IsFinite(elapsed) || elapsed < 0 || elapsed > int.MaxValue)
                throw new IOException("Incomplete BYOND round status.");
            var round = "";
            if (root.TryGetProperty("game_id", out var id)) {
                if (id.ValueKind == JsonValueKind.Number && id.TryGetInt64(out var number)) round = number.ToString(CultureInfo.InvariantCulture);
                else round = ServerDirectory.Text(root, "game_id", 80, allowEmpty: true);
            }
            if (map != expected.Map || mode != expected.Mode || (expected.RoundId.Length != 0 && round != expected.RoundId))
                throw new IOException("BYOND status differs from the selected directory record.");
        } catch (Exception error) when (error is JsonException or DecoderFallbackException or InvalidOperationException) {
            throw new IOException("Invalid BYOND status JSON.", error);
        }
    }
}
