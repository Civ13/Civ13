using Civ13.Launcher;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;

internal static class ServerDirectoryTests {
    public static async Task<int> Run(string root) {
        var assertions = 0;
        var now = DateTimeOffset.Parse("2026-10-19T17:00:00Z");
        void Require(bool condition, string message) { assertions++; if (!condition) throw new Exception(message); }
        void Reject(Action action, string message) {
            try { action(); } catch (IOException) { assertions++; return; }
            throw new Exception("Directory negative control accepted: " + message);
        }
        async Task RejectAsync(Func<Task> action, string message) {
            try { await action(); } catch (IOException) { assertions++; return; }
            throw new Exception("Directory negative control accepted: " + message);
        }
        JsonObject Entry(string provider = "Civ13.com", int port = 24017, string id = "nomads-a") => new() {
            ["id"] = id, ["name"] = "Nomads Europe", ["host"] = ServerCatalog.Host(provider),
            ["port"] = port, ["engine"] = "BYOND", ["online"] = true,
            ["checked_at"] = "2026-10-19T16:59:58Z", ["players"] = 12,
            ["map"] = "Europe", ["mode"] = "Nomads", ["epoch"] = "Modern",
            ["round"] = new JsonObject { ["id"] = "round-27", ["duration_seconds"] = 7384 }
        };
        JsonObject Document(params JsonObject[] entries) => new() {
            ["schema"] = 1, ["generated_at"] = "2026-10-19T17:00:00Z",
            ["expires_at"] = "2026-10-19T17:01:00Z", ["servers"] = new JsonArray(entries.Select(e => (JsonNode)e).ToArray())
        };
        byte[] Bytes(JsonObject value) => Encoding.UTF8.GetBytes(value.ToJsonString());
        ServerDirectory Parse(JsonObject value, string provider = "Civ13.com", DateTimeOffset? time = null) =>
            ServerDirectory.Read(provider, Bytes(value), time ?? now);
        void Hidden(Action<JsonObject> mutate, string message) {
            var entry = Entry(); mutate(entry);
            Require(Parse(Document(entry)).Servers.Count == 0, "Invalid server shown: " + message);
        }
        using var sharedFixture = typeof(ServerDirectoryTests).Assembly.GetManifestResourceStream("server-directory-unicode.json")
            ?? throw new Exception("Shared Unicode contract fixture missing.");
        using var sharedBytes = new MemoryStream();
        sharedFixture.CopyTo(sharedBytes);
        var sharedDirectory = ServerDirectory.Read("Civ13.com", sharedBytes.ToArray(), now);
        Require(sharedDirectory.Servers.Count == 1, "shared Unicode fixture did not produce one selectable server");
        var sharedServer = sharedDirectory.Servers.Single();
        Require(sharedServer.Name == "Nomads 🌍" && sharedServer.Players == 0 && sharedServer.Map == "Gaia" &&
            sharedServer.Mode == "Nomads" && sharedServer.Epoch == "1200" && sharedServer.RoundId == "round-42" &&
            sharedServer.RoundDurationSeconds == 1234 && sharedServer.Port == 1715, "shared Unicode contract fixture changed");
        var directory = Parse(Document(Entry()));
        var server = directory.Servers.Single();
        Require(server.Name == "Nomads Europe" && server.Players == 12 && server.Map == "Europe" && server.Mode == "Nomads" &&
            server.RoundId == "round-27" && server.RoundDurationSeconds == 7384 && server.Epoch == "Modern", "status fields lost");
        Require(server.Port == 24017 && server.Host == "civ13.com", "directory port replaced by compiled default");
        using var display = new StringWriter();
        ServerBrowser.WriteServers(display, "Civ13.com", directory);
        foreach (var expected in new[] { "Nomads Europe", "Players: 12", "Map: Europe", "Mode: Nomads", "round-27", "2:03:04", "Modern", "civ13.com:24017", "R: Refresh", "B: Back" })
            Require(display.ToString().Contains(expected), "missing directory display: " + expected);
        foreach (var field in new[] { "id", "name", "host", "port", "engine", "online", "checked_at", "players", "map", "mode", "round" })
            Hidden(e => e.Remove(field), "missing " + field);
        foreach (var field in new[] { "id", "duration_seconds" }) Hidden(e => ((JsonObject)e["round"]!).Remove(field), "missing round " + field);
        Hidden(e => e["online"] = false, "offline");
        Hidden(e => e["online"] = "true", "truthy string");
        Hidden(e => e["checked_at"] = "2026-10-19T16:58:59Z", "stale probe");
        Hidden(e => e["checked_at"] = "2026-10-19T17:00:01Z", "probe newer than generation");
        Hidden(e => e["checked_at"] = "2026-10-19T17:00:00+00:00", "noncontract timestamp");
        foreach (var host in new[] { "127.0.0.1", "localhost", "72.218.249.221", "civ13.com.evil.test", "valzargaming.com", "https://civ13.com", "civ13.com:1714", "civ13.com;calc.exe", "CIV13.COM", "civ13.com." })
            Hidden(e => e["host"] = host, "substituted hostname");
        foreach (var engine in new[] { "OpenDream", "byond", "BYOND --arg", "", "DreamDaemon" }) Hidden(e => e["engine"] = engine, "engine");
        foreach (var port in new[] { 0, -1, 65536 }) Hidden(e => e["port"] = port, "out-of-range port");
        Hidden(e => e["port"] = "24017", "string port");
        Hidden(e => e["port"] = 1.5, "fractional port");
        foreach (var invalid in new[] { -1, 10001 }) Hidden(e => e["players"] = invalid, "player bound");
        Hidden(e => e["players"] = "12", "string players");
        Hidden(e => e["players"] = 1.5, "fractional players");
        Hidden(e => e["players"] = null, "unknown player count");
        Hidden(e => e["name"] = new string('a', 121), "name bound");
        foreach (var text in new[] { "bad\nname", "\u001b[31m", "bad\u202ename", "bad\u2028name", "\t", "" }) Hidden(e => e["name"] = text, "unsafe display");
        var unicode = Entry(); unicode["name"] = "Nomads 🌍";
        Require(Parse(Document(unicode)).Servers.Single().Name == "Nomads 🌍", "valid non-BMP display character rejected");
        foreach (var (text, expectedBytes) in new[] { (new string('é', 60), 120), (string.Concat(Enumerable.Repeat("🌍", 30)), 120) }) {
            Require(Encoding.UTF8.GetByteCount(text) == expectedBytes, "UTF-8 boundary fixture changed");
            var boundary = Entry(); boundary["name"] = text;
            Require(Parse(Document(boundary)).Servers.Single().Name == text, "UTF-8 byte boundary rejected");
            Hidden(e => e["name"] = text + "x", "UTF-8 name byte limit");
        }
        var mapBoundary = Entry(); mapBoundary["map"] = string.Concat(Enumerable.Repeat("🌍", 32));
        Require(Parse(Document(mapBoundary)).Servers.Count == 1, "128-byte non-BMP map rejected");
        Hidden(e => e["map"] = string.Concat(Enumerable.Repeat("🌍", 33)), "128-byte map limit");
        Hidden(e => e["name"] = "name\U000e0001", "non-BMP formatting character");
        var template = Encoding.UTF8.GetString(Bytes(Document(Entry())));
        foreach (var escaped in new[] { @"\ud800", @"\udfff", @"\ud800X", @"\ud800\ud800", @"\udfff\ud800", @"\ud800\n" }) {
            var malformed = Encoding.UTF8.GetBytes(template.Replace("Nomads Europe", escaped, StringComparison.Ordinal));
            Require(ServerDirectory.Read("Civ13.com", malformed, now).Servers.Count == 0, "malformed surrogate sequence shown: " + escaped);
        }
        var paired = Encoding.UTF8.GetBytes(template.Replace("Nomads Europe", @"Nomads \ud83c\udf0d", StringComparison.Ordinal));
        Require(ServerDirectory.Read("Civ13.com", paired, now).Servers.Single().Name == "Nomads 🌍", "valid escaped surrogate pair rejected");
        foreach (var invalidUtf8 in new[] { new byte[] { 0xed, 0xa0, 0x80 }, new byte[] { 0xed, 0xbf, 0xbf }, new byte[] { 0xf0, 0x9f }, new byte[] { 0xff } }) {
            var parts = template.Split("Nomads Europe", StringSplitOptions.None);
            var malformed = Encoding.UTF8.GetBytes(parts[0]).Concat(invalidUtf8).Concat(Encoding.UTF8.GetBytes(parts[1])).ToArray();
            Reject(() => ServerDirectory.Read("Civ13.com", malformed, now), "malformed wire UTF-8");
        }
        Hidden(e => e["id"] = "../../bad", "unsafe ID");
        Hidden(e => e["round"]!["duration_seconds"] = -1, "negative round duration");
        Hidden(e => e["round"]!["duration_seconds"] = 1.5, "fractional round duration");
        Hidden(e => e["round"]!["state"] = "playing\nINJECT", "unsafe round state");
        var zero = Entry(); zero["players"] = 0; zero["round"]!["duration_seconds"] = 0; zero["round"]!["id"] = "";
        Require(Parse(Document(zero)).Servers.Single().Players == 0, "empty server treated as offline");
        var offline = Entry(port: 30000, id: "offline"); offline["online"] = false;
        var stale = Entry(port: 30001, id: "stale"); stale["checked_at"] = "2026-10-19T16:00:00Z";
        Require(Parse(Document(Entry(), offline, stale)).Servers.Count == 1, "offline/stale entries leaked");
        Require(Parse(Document()).Servers.Count == 0, "empty fresh directory rejected");
        foreach (var field in new[] { "schema", "generated_at", "expires_at", "servers" }) {
            var doc = Document(Entry()); doc.Remove(field); Reject(() => Parse(doc), "missing envelope " + field);
        }
        foreach (var schema in new[] { 0, 2 }) { var doc = Document(); doc["schema"] = schema; Reject(() => Parse(doc), "schema"); }
        foreach (var expires in new[] { "2026-10-19T17:00:00Z", "2026-10-19T17:02:01Z", "2026-10-19T16:59:00Z" }) {
            var doc = Document(); doc["expires_at"] = expires; Reject(() => Parse(doc), "expiry");
        }
        var future = Document(); future["generated_at"] = "2026-10-19T17:00:06Z"; Reject(() => Parse(future), "future envelope");
        Reject(() => Parse(Document(Entry(), Entry(port: 30000))), "duplicate IDs");
        Reject(() => Parse(Document(Entry(), Entry(id: "other"))), "duplicate endpoints");
        Reject(() => Parse(Document(Enumerable.Range(0, 33).Select(i => Entry(port: 30000 + i, id: "n" + i)).ToArray())), "server bound");
        Reject(() => ServerDirectory.Read("Civ13.com", Encoding.UTF8.GetBytes("{\"schema\":1,\"schema\":1}"), now), "duplicate JSON fields");
        Reject(() => ServerDirectory.Read("Civ13.com", Encoding.UTF8.GetBytes("<html>error</html>"), now), "HTML");
        Reject(() => ServerDirectory.Read("Civ13.com", Encoding.UTF8.GetBytes("{\"\\ud800\":0}"), now), "malformed surrogate in property name");
        Reject(() => ServerDirectory.Read("Civ13.com", new byte[ServerDirectory.MaxBytes + 1], now), "byte bound");
        Reject(() => Parse(Document(), "attacker.test"), "unknown provider");
        Reject(() => server.Validate(now.AddMinutes(1)), "expired selected server");
        Reject(() => server.Validate(now.AddMinutes(-1)), "clock rollback");
        var endpoint = await ServerCatalog.NativeEndpoint(server, _ => throw new Exception("official used VZG resolver"), now);
        var start = ServerCatalog.NativeStart(server, root, endpoint, Civ13.Launcher.Program.RequiredByond(), _ => true, now);
        Require(start.ArgumentList.Single() == "byond://civ13.com:24017" && !start.UseShellExecute, "official fresh directory dispatch");
        foreach (var invalid in new[] { "72.218.249.221", "192.64.119.81", "civ13.com;calc.exe", "https://civ13.com", "valzargaming.com" })
            Reject(() => ServerCatalog.NativeStart(server, root, invalid, Civ13.Launcher.Program.RequiredByond(), _ => true, now), "unverified endpoint");
        Reject(() => ServerCatalog.NativeStart(server, root, endpoint, Civ13.Launcher.Program.RequiredByond(), _ => false, now), "client version");
        Reject(() => ServerCatalog.NativeStart(server, root, endpoint, Civ13.Launcher.Program.RequiredByond(), _ => true, now.AddMinutes(1)), "expired dispatch");
        var valzar = Parse(Document(Entry("ValZarGaming", 32009)), "ValZarGaming").Servers.Single();
        var calls = 0;
        var pinned = await ServerCatalog.NativeEndpoint(valzar, host => {
            calls++; Require(host == "valzargaming.com", "wrong DNS name");
            return Task.FromResult(new[] { IPAddress.Parse(Connection.ApprovedEndpoint), IPAddress.Parse(Connection.ExcludedEndpoint) });
        }, now);
        Require(pinned == Connection.ApprovedEndpoint && calls == 1, "VZG DNS pin changed");
        Require(ServerCatalog.NativeStart(valzar, root, pinned, Civ13.Launcher.Program.RequiredByond(), _ => true, now).ArgumentList.Single() ==
            "byond://72.218.249.221:32009", "VZG directory port ignored");
        await RejectAsync(() => ServerCatalog.NativeEndpoint(valzar, _ => Task.FromResult(new[] { IPAddress.Loopback }), now), "VZG unverified DNS");
        await RejectAsync(() => ServerCatalog.NativeEndpoint(valzar, _ => Task.FromResult(new[] { IPAddress.Parse(Connection.ExcludedEndpoint) }), now), "VZG excluded DNS");

        // Exercise production HTTP code with bounded offline response streams, never real ports.
        var httpCalls = 0;
        using (var transport = new ServerDirectoryTransport(new DirectoryHandler((request, _) => {
            httpCalls++;
            Require(request.RequestUri == new Uri("https://civ13.com/.well-known/civ13/servers.json"), "wrong discovery origin/path");
            Require(request.Headers.CacheControl is { NoCache: true, NoStore: true }, "directory cache bypass missing");
            return Task.FromResult(Response(request, Bytes(Document(Entry()))));
        }))) {
            Require(ServerDirectory.Read("Civ13.com", await transport.Fetch("Civ13.com"), now).Servers.Count == 1, "HTTP parse");
            await transport.Fetch("Civ13.com"); Require(httpCalls == 2, "directory responses cached");
        }
        foreach (var status in new[] { HttpStatusCode.MovedPermanently, HttpStatusCode.Redirect, HttpStatusCode.NotFound, HttpStatusCode.ServiceUnavailable }) {
            using var transport = new ServerDirectoryTransport(new DirectoryHandler((request, _) => {
                var response = Response(request, Bytes(Document())); response.StatusCode = status;
                response.Headers.Location = new Uri("https://evil.test/servers.json"); return Task.FromResult(response);
            }));
            await RejectAsync(() => transport.Fetch("Civ13.com"), "redirect/status " + status);
        }
        foreach (var kind in new[] { "html", "origin", "length", "stream" }) {
            using var transport = new ServerDirectoryTransport(new DirectoryHandler((request, _) => {
                var bytes = kind is "length" or "stream" ? new byte[ServerDirectory.MaxBytes + 1] : Bytes(Document());
                var response = Response(request, bytes);
                if (kind == "html") response.Content.Headers.ContentType = new MediaTypeHeaderValue("text/html");
                if (kind == "origin") response.RequestMessage = new HttpRequestMessage(HttpMethod.Get, "https://evil.test/");
                if (kind == "stream") response.Content = new StreamContent(new NonSeekStream(bytes));
                if (kind == "stream") response.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json");
                return Task.FromResult(response);
            }));
            await RejectAsync(() => transport.Fetch("Civ13.com"), "HTTP " + kind);
        }
        using (var transport = new ServerDirectoryTransport(new DirectoryHandler(async (_, token) => {
            await Task.Delay(Timeout.InfiniteTimeSpan, token); throw new Exception("timeout did not cancel");
        }), TimeSpan.FromMilliseconds(20))) await RejectAsync(() => transport.Fetch("Civ13.com"), "header timeout");
        using (var transport = new ServerDirectoryTransport(new DirectoryHandler((request, _) => {
            var response = Response(request, []); response.Content = new StreamContent(new BlockingStream());
            response.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json"); return Task.FromResult(response);
        }), TimeSpan.FromMilliseconds(20))) await RejectAsync(() => transport.Fetch("Civ13.com"), "body timeout");
        using (var transport = new ServerDirectoryTransport(new DirectoryHandler((_, _) => throw new HttpRequestException("private URL"))))
            await RejectAsync(() => transport.Fetch("Civ13.com"), "network failure");

        async Task<(string Output, int Fetches, int Launches)> Browse(string input, params byte[][] responses) {
            var fetched = 0; var launched = 0;
            var transport = new DirectoryFixture(_ => {
                if (fetched >= responses.Length) throw new IOException("offline");
                return responses[fetched++];
            });
            using var output = new StringWriter();
            await ServerBrowser.Run("Civ13.com", transport, new StringReader(input), output, candidate => {
                launched++; Require(candidate.Port == 24017, "browser launched changed target"); return Task.CompletedTask;
            }, () => now);
            return (output.ToString(), fetched, launched);
        }
        var selected = await Browse("1\n", Bytes(Document(Entry())), Bytes(Document(Entry())));
        Require(selected.Launches == 1 && selected.Fetches == 2, "selection did not revalidate before launch");
        var refreshed = await Browse("R\n1\n", Bytes(Document()), Bytes(Document(Entry())), Bytes(Document(Entry())));
        Require(refreshed.Launches == 1 && refreshed.Fetches == 3, "refresh did not repopulate");
        var gone = await Browse("1\nB\n", Bytes(Document(Entry())), Bytes(Document()), Bytes(Document()));
        Require(gone.Launches == 0 && gone.Output.Contains("could not be verified"), "disappeared selection launched");
        var changed = await Browse("1\nB\n", Bytes(Document(Entry())), Bytes(Document(Entry(port: 30000))), Bytes(Document(Entry(port: 30000))));
        Require(changed.Launches == 0, "changed endpoint silently launched");
        var unavailable = await Browse("1\nB\n");
        Require(unavailable.Launches == 0 && unavailable.Output.Contains("unavailable"), "failed fetch used fallback");
        var empty = await Browse("1\nB\n", Bytes(Document()));
        Require(empty.Launches == 0 && empty.Output.Contains("No verified online servers"), "empty directory used static catalog");
        var staleDocument = Document(Entry()); staleDocument["expires_at"] = "2026-10-19T17:00:00Z";
        var expired = await Browse("1\nB\n", Bytes(Document(Entry())), Bytes(staleDocument), Bytes(Document()));
        Require(expired.Launches == 0, "expired prejoin response launched");
        var zeroDocument = Entry(); zeroDocument["players"] = 0;
        var zeroJoin = await Browse("1\n", Bytes(Document(zeroDocument)), Bytes(Document(Entry())));
        Require(zeroJoin.Launches == 1, "online empty server could not join");
        var newMode = Entry(); newMode["mode"] = "Wizard Boy"; newMode["name"] = "Event World";
        Require(Parse(Document(newMode)).Servers.Single().Mode == "Wizard Boy", "compiled mode list restricted discovery");
        var back = await Browse("B\n", Bytes(Document(Entry())));
        Require(back.Launches == 0 && back.Fetches == 1, "Back dispatched");
        var eof = await Browse("", Bytes(Document(Entry()))); Require(eof.Launches == 0, "EOF dispatched");
        var badChoice = await Browse("-1\n0\n999\n2;calc\nB\n", Bytes(Document(Entry())));
        Require(badChoice.Launches == 0, "invalid choice dispatched");
        Console.WriteLine($"PASS: {assertions} live-directory, freshness, transport, metadata and selection controls.");
        return assertions;
    }
    private static HttpResponseMessage Response(HttpRequestMessage request, byte[] bytes) {
        var response = new HttpResponseMessage(HttpStatusCode.OK) { RequestMessage = request, Content = new ByteArrayContent(bytes) };
        response.Content.Headers.ContentType = new MediaTypeHeaderValue("application/json"); return response;
    }
}

internal sealed class DirectoryHandler(Func<HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> response) : HttpMessageHandler {
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) => response(request, cancellationToken);
}
internal sealed class DirectoryFixture(Func<string, ReadOnlyMemory<byte>> fetch) : IServerDirectoryTransport {
    public Task<ReadOnlyMemory<byte>> Fetch(string provider, CancellationToken cancellationToken = default) => Task.FromResult(fetch(provider));
}
internal sealed class NonSeekStream(byte[] bytes) : MemoryStream(bytes) { public override bool CanSeek => false; }
internal sealed class BlockingStream : MemoryStream {
    public override async ValueTask<int> ReadAsync(Memory<byte> buffer, CancellationToken cancellationToken = default) {
        await Task.Delay(Timeout.InfiniteTimeSpan, cancellationToken); return 0;
    }
}
