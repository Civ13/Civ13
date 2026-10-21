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
        using var vzgFixture = typeof(ServerDirectoryTests).Assembly.GetManifestResourceStream("server-directory-vzg.json")
            ?? throw new Exception("Shared VZG contract fixture missing.");
        using var vzgBytes = new MemoryStream();
        vzgFixture.CopyTo(vzgBytes);
        var vzgDirectory = ServerDirectory.Read("ValZarGaming", vzgBytes.ToArray(), now);
        Require(vzgDirectory.Servers.Count == 1, "shared VZG fixture did not produce one selectable server");
        var vzgServer = vzgDirectory.Servers.Single();
        Require(vzgServer.Id == "vzg-fixture" && vzgServer.Name == "VZG fixture" && vzgServer.Host == "valzargaming.com" &&
            vzgServer.Port == 24017 && vzgServer.Players == 0 && vzgServer.Map == "Gaia" && vzgServer.Mode == "Nomads" &&
            vzgServer.Epoch == "1200" && vzgServer.RoundId == "round-42" && vzgServer.RoundDurationSeconds == 1234,
            "shared VZG production projection changed");
        Require(ServerDirectory.Read("Civ13.com", vzgBytes.ToArray(), now).Servers.Count == 0,
            "shared VZG projection leaked into official provider");
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
        foreach (var host in new[] { "127.0.0.1", "localhost", "8.8.8.8", "civ13.com.evil.test", "valzargaming.com", "https://civ13.com", "civ13.com:1714", "civ13.com;calc.exe", "CIV13.COM", "civ13.com." })
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
        var officialCalls = 0;
        var endpoint = await ServerCatalog.NativeEndpoint(server, host => {
            officialCalls++; Require(host == "civ13.com", "official selection resolved wrong hostname");
            return Task.FromResult(new[] { IPAddress.Parse("8.8.8.8") });
        }, now, statusProbe: (_, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet()));
        var start = ServerCatalog.NativeStart(server, root, endpoint, Civ13.Launcher.Program.RequiredByond(), _ => true, now);
        Require(start.ArgumentList.Single() == "byond://8.8.8.8:24017" && !start.UseShellExecute && officialCalls == 1,
            "official dispatch did not bind the single validated DNS result");
        Reject(() => ServerCatalog.NativeStart(server, root, endpoint, Civ13.Launcher.Program.RequiredByond(), _ => false, now), "client version");
        Reject(() => ServerCatalog.NativeStart(server, root, endpoint, Civ13.Launcher.Program.RequiredByond(), _ => true, now.AddMinutes(1)), "expired dispatch");
        var valzar = Parse(Document(Entry("ValZarGaming", 32009)), "ValZarGaming").Servers.Single();
        var calls = 0;
        Task<IPAddress[]> ChangingDns(string host) {
            calls++; Require(host == "valzargaming.com", "wrong DNS name");
            return Task.FromResult(new[] { IPAddress.Parse(calls == 1 ? "8.8.4.4" : "1.1.1.1") });
        }
        var first = await ServerCatalog.NativeEndpoint(valzar, ChangingDns, now, statusProbe: (_, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet()));
        var changedIp = await ServerCatalog.NativeEndpoint(valzar, ChangingDns, now, statusProbe: (_, _, _) => Task.FromResult<ReadOnlyMemory<byte>>(ByondStatusTests.Packet()));
        Require(first.Address == "8.8.4.4" && changedIp.Address == "1.1.1.1" && calls == 2, "fresh valid public IP change was blocked or DNS was cached");
        Require(ServerCatalog.NativeStart(valzar, root, first, Civ13.Launcher.Program.RequiredByond(), _ => true, now).ArgumentList.Single() ==
            "byond://8.8.4.4:32009", "first DNS result was not bound to its connection attempt");
        Require(ServerCatalog.NativeStart(valzar, root, changedIp, Civ13.Launcher.Program.RequiredByond(), _ => true, now).ArgumentList.Single() ==
            "byond://1.1.1.1:32009" && calls == 2, "dispatch re-resolved DNS or ignored the current address");
        Reject(() => ServerCatalog.NativeStart(server, root, first, Civ13.Launcher.Program.RequiredByond(), _ => true, now), "VZG DNS identity substituted for official provider");
        Reject(() => ServerCatalog.NativeStart(valzar, root, endpoint, Civ13.Launcher.Program.RequiredByond(), _ => true, now), "official DNS identity substituted for VZG");
        var ticks = 1000L;
        var expiringEndpoint = await Connection.ResolveHost("civ13.com", _ => Task.FromResult(new[] { IPAddress.Parse("8.8.8.8") }), () => ticks);
        ticks = 16000;
        Require(ServerCatalog.NativeStart(server, root, expiringEndpoint, Civ13.Launcher.Program.RequiredByond(), _ => true, now).ArgumentList.Single() ==
            "byond://8.8.8.8:24017", "endpoint rejected within its monotonic freshness bound");
        ticks = 16001;
        Reject(() => ServerCatalog.NativeStart(server, root, expiringEndpoint, Civ13.Launcher.Program.RequiredByond(), _ => true, now), "stale DNS result reused");
        ticks = 999;
        Reject(() => ServerCatalog.NativeStart(server, root, expiringEndpoint, Civ13.Launcher.Program.RequiredByond(), _ => true, now), "endpoint monotonic clock rollback");
        foreach (var invalidHost in new[] { "evil.test", "CIV13.COM", "civ13.com.", "127.0.0.1", "civ13.com;calc.exe", "https://civ13.com", "valzargaming.com:1715" })
            await RejectAsync(() => Connection.ResolveHost(invalidHost, _ => throw new Exception("unapproved hostname reached DNS")), "hostname allowlist");
        foreach (var invalidIp in new[] { "0.1.2.3", "10.0.0.1", "100.64.0.1", "100.127.255.254", "127.0.0.1", "169.254.169.254", "172.16.0.1", "172.31.255.254",
            "192.0.0.9", "192.0.2.1", "192.31.196.1", "192.52.193.1", "192.88.99.1", "192.168.1.1", "192.175.48.1", "198.18.0.1", "198.19.255.254",
            "198.51.100.1", "203.0.113.1", "224.0.0.1", "239.255.255.255", "240.0.0.1", "255.255.255.255", "::", "::1", "fe80::1", "fc00::1", "::ffff:8.8.8.8", "2606:4700:4700::1111" }) {
            await RejectAsync(() => ServerCatalog.NativeEndpoint(valzar, _ => Task.FromResult(new[] { IPAddress.Parse(invalidIp) }), now), "private/reserved/unsupported DNS: " + invalidIp);
            await RejectAsync(() => ServerCatalog.NativeEndpoint(server, _ => Task.FromResult(new[] { IPAddress.Parse("8.8.8.8"), IPAddress.Parse(invalidIp) }), now), "mixed public/unsafe DNS: " + invalidIp);
        }
        foreach (var publicIp in new[] { "1.1.1.1", "8.8.8.8", "100.63.255.254", "100.128.0.1", "172.15.255.254", "172.32.0.1", "198.17.255.254", "198.20.0.1" })
            Require(Connection.IsPublicIPv4(IPAddress.Parse(publicIp)), "public range boundary blocked: " + publicIp);
        await RejectAsync(() => Connection.Resolve(_ => Task.FromResult(Array.Empty<IPAddress>())), "empty DNS has no fallback");
        await RejectAsync(() => Connection.Resolve(_ => Task.FromException<IPAddress[]>(new System.Net.Sockets.SocketException())), "DNS failure has no fallback");
        await RejectAsync(() => Connection.Resolve(_ => Task.FromException<IPAddress[]>(new TimeoutException())), "DNS timeout has no fallback");
        await RejectAsync(() => Connection.Resolve(_ => Task.FromResult(Enumerable.Repeat(IPAddress.Parse("8.8.8.8"), 33).ToArray())), "DNS answer bound");
        var multi = await Connection.Resolve(_ => Task.FromResult(new[] { IPAddress.Parse("8.8.8.8"), IPAddress.Parse("1.1.1.1"), IPAddress.Parse("8.8.8.8") }));
        Require(multi.Address == "1.1.1.1", "multi-address selection was not deterministic and bounded");

        Require(ServerCatalog.DirectoryUrl("Civ13.com").AbsoluteUri == "https://civ13.com/.well-known/civ13/servers.json?provider=civ13.com", "official canonical query changed");
        Require(ServerCatalog.DirectoryUrl("ValZarGaming").AbsoluteUri == "https://civ13.com/.well-known/civ13/servers.json?provider=valzargaming.com", "VZG canonical central query changed");
        foreach (var provider in new[] { "civ13.com", "Civ13.com&port=1714", "ValZarGaming&provider=civ13.com", "https://evil.test", "ValZarGaming?host=127.0.0.1" })
            Reject(() => ServerCatalog.DirectoryUrl(provider), "query/provider injection");
        Require(Parse(Document(Enumerable.Range(0, 32).Select(i => Entry(port: 30000 + i, id: "n" + i)).ToArray())).Servers.Count == 32, "maximum bounded directory rejected");
        var cappedBytes = Enumerable.Repeat((byte)' ', ServerDirectory.MaxBytes).ToArray();
        Bytes(Document()).CopyTo(cappedBytes, 0);
        Require(ServerDirectory.Read("Civ13.com", cappedBytes, now).Servers.Count == 0, "exact byte cap rejected");
        Require(Parse(Document(Entry(), Entry("ValZarGaming", id: "other")), "ValZarGaming").Servers.Single().Provider == "ValZarGaming", "same port on another approved host caused cross-provider collision");
        using (var partialTransport = new ServerDirectoryTransport(new DirectoryHandler((request, _) => {
            var response = Response(request, Bytes(Document(Entry())));
            if (request.RequestUri == ServerCatalog.DirectoryUrl("ValZarGaming")) response.StatusCode = HttpStatusCode.NotFound;
            return Task.FromResult(response);
        }))) {
            Require(ServerDirectory.Read("Civ13.com", await partialTransport.Fetch("Civ13.com"), now).Servers.Count == 1, "configured provider unavailable");
            await RejectAsync(() => partialTransport.Fetch("ValZarGaming"), "unconfigured provider must not borrow another snapshot");
            Require(ServerDirectory.Read("Civ13.com", await partialTransport.Fetch("Civ13.com"), now).Servers.Count == 1, "one unavailable provider poisoned the other");
        }

        // Exercise production HTTP code with bounded offline response streams, never real ports.
        var httpCalls = 0;
        using (var transport = new ServerDirectoryTransport(new DirectoryHandler((request, _) => {
            httpCalls++;
            var provider = request.RequestUri!.Query == "?provider=valzargaming.com" ? "ValZarGaming" : "Civ13.com";
            Require(request.RequestUri == ServerCatalog.DirectoryUrl(provider) && request.RequestUri.Host == "civ13.com", "wrong central discovery origin/path/query");
            Require(request.Headers.CacheControl is { NoCache: true, NoStore: true }, "directory cache bypass missing");
            return Task.FromResult(Response(request, Bytes(Document(Entry(provider)))));
        }))) {
            Require(ServerDirectory.Read("Civ13.com", await transport.Fetch("Civ13.com"), now).Servers.Count == 1, "HTTP parse");
            await transport.Fetch("Civ13.com"); Require(httpCalls == 2, "directory responses cached");
            Require(ServerDirectory.Read("ValZarGaming", await transport.Fetch("ValZarGaming"), now).Servers.Single().Host == "valzargaming.com", "central VZG query did not retain provider identity");
            Require(httpCalls == 3, "VZG menu reused another provider response");
        }
        foreach (var status in new[] { HttpStatusCode.MovedPermanently, HttpStatusCode.Redirect, HttpStatusCode.NotFound, HttpStatusCode.ServiceUnavailable }) {
            using var transport = new ServerDirectoryTransport(new DirectoryHandler((request, _) => {
                var response = Response(request, Bytes(Document())); response.StatusCode = status;
                response.Headers.Location = new Uri("https://evil.test/servers.json"); return Task.FromResult(response);
            }));
            await RejectAsync(() => transport.Fetch("Civ13.com"), "redirect/status " + status);
        }
        foreach (var kind in new[] { "html", "origin", "query", "length", "stream" }) {
            using var transport = new ServerDirectoryTransport(new DirectoryHandler((request, _) => {
                var bytes = kind is "length" or "stream" ? new byte[ServerDirectory.MaxBytes + 1] : Bytes(Document());
                var response = Response(request, bytes);
                if (kind == "html") response.Content.Headers.ContentType = new MediaTypeHeaderValue("text/html");
                if (kind == "origin") response.RequestMessage = new HttpRequestMessage(HttpMethod.Get, "https://evil.test/");
                if (kind == "query") response.RequestMessage = new HttpRequestMessage(HttpMethod.Get, ServerCatalog.DirectoryUrl("ValZarGaming"));
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

        async Task<(string Output, int Fetches, int Launches)> BrowseProvider(string provider, string input, params byte[][] responses) {
            var fetched = 0; var launched = 0;
            var transport = new DirectoryFixture(_ => {
                if (fetched >= responses.Length) throw new IOException("offline");
                return responses[fetched++];
            });
            using var output = new StringWriter();
            await ServerBrowser.Run(provider, transport, new StringReader(input), output, candidate => {
                launched++; Require(candidate.Port == 24017 && candidate.Provider == provider, "browser launched changed target/provider"); return Task.CompletedTask;
            }, () => now);
            return (output.ToString(), fetched, launched);
        }
        Task<(string Output, int Fetches, int Launches)> Browse(string input, params byte[][] responses) => BrowseProvider("Civ13.com", input, responses);
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
        var emptyVzg = await BrowseProvider("ValZarGaming", "1\nB\n", Bytes(Document()));
        Require(emptyVzg.Launches == 0 && emptyVzg.Output.Contains("No verified online servers") && !emptyVzg.Output.Contains("unavailable"), "configured empty VZG response was mislabeled");
        var unavailableVzg = await BrowseProvider("ValZarGaming", "1\nB\n");
        Require(unavailableVzg.Launches == 0 && unavailableVzg.Output.Contains("unavailable"), "unconfigured VZG fell back to static servers");
        var wrongProvider = await BrowseProvider("ValZarGaming", "1\nB\n", Bytes(Document(Entry())));
        Require(wrongProvider.Launches == 0 && wrongProvider.Output.Contains("No verified online servers"), "official records leaked into VZG menu");
        var swappedProvider = await BrowseProvider("ValZarGaming", "1\nB\n", Bytes(Document(Entry("ValZarGaming"))), Bytes(Document(Entry())), Bytes(Document()));
        Require(swappedProvider.Launches == 0, "prejoin allowed an identically named server from another provider");
        var zeroVzg = Entry("ValZarGaming"); zeroVzg["players"] = 0;
        var selectedVzg = await BrowseProvider("ValZarGaming", "1\n", Bytes(Document(zeroVzg)), Bytes(Document(Entry("ValZarGaming"))));
        Require(selectedVzg.Launches == 1 && selectedVzg.Fetches == 2, "zero-player VZG selection was not refreshed and retained");
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
        assertions += await ByondStatusTests.Run(server, now);
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
