using Civ13.Launcher;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

// Optional Discord sign-in. Discord and the sign-in service are faked; nothing leaves the machine.
static class DiscordSignInTests {
    const string Ticket = "AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_ab";

    sealed class FakeHttp(Func<HttpRequestMessage, string, (HttpStatusCode, string)> answer) : HttpMessageHandler {
        public readonly List<(string Url, string Body)> Seen = [];
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) {
            var body = request.Content == null ? "" : await request.Content.ReadAsStringAsync(cancellationToken);
            Seen.Add((request.RequestUri!.AbsoluteUri, body));
            var (status, text) = answer(request, body);
            return new HttpResponseMessage(status) { Content = new StringContent(text, Encoding.UTF8, "application/json") };
        }
    }

    public static async Task<int> Run(string root) {
        var assertions = 0;
        void Require(bool yes, string why) { assertions++; if (!yes) throw new Exception("Discord sign-in: " + why); }
        async Task Refuse(Func<Task> action, string why) {
            try { await action(); } catch (DiscordSignInException) { assertions++; return; }
            throw new Exception("Discord sign-in accepted: " + why);
        }
        var folder = Path.Combine(root, "signin-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(folder);
        void Settings(string json) => File.WriteAllText(Path.Combine(folder, PresenceSettings.FileName), json);

        // Off unless discord.json names an HTTPS sign-in service.
        Require(DiscordSignInSettings.Load(folder) == null, "on without discord.json");
        Settings("{\"show_activity\": true}");
        Require(DiscordSignInSettings.Load(folder) == null, "on without signin_url");
        foreach (var bad in new[] { "http://example.test/signin", "https://user:pw@example.test/signin", "https://example.test/signin?x=1", "not a url" }) {
            Settings(JsonSerializer.Serialize(new { signin_url = bad }));
            Require(DiscordSignInSettings.Load(folder) == null, "accepted sign-in URL " + bad);
        }
        Settings("{\"signin_url\": \"https://signin.example.test/signin\"}");
        var settings = DiscordSignInSettings.Load(folder)!;
        Require(settings.ClientId == PresenceSettings.BuiltInApplicationId, "did not default to the presence application");
        Settings("{\"signin_url\": \"https://signin.example.test/signin\", \"signin_client_id\": \"223456789012345678\"}");
        Require(DiscordSignInSettings.Load(folder)!.ClientId == "223456789012345678", "ignored signin_client_id");

        // PKCE: S256 challenge of the verifier, and a public-client authorize URL with no secret.
        var pkce = PkcePair.Create();
        var challenge = PkcePair.Base64Url(System.Security.Cryptography.SHA256.HashData(Encoding.ASCII.GetBytes(pkce.Verifier)));
        Require(pkce.Challenge == challenge && pkce.Verifier.Length >= 43, "PKCE challenge is not S256 of the verifier");
        var authorize = DiscordSignIn.AuthorizeUrl(settings, pkce, silent: false).AbsoluteUri;
        Require(authorize.StartsWith("https://discord.com/oauth2/authorize?") && authorize.Contains("code_challenge_method=S256") &&
            authorize.Contains("scope=identify") && authorize.Contains(Uri.EscapeDataString(DiscordSignInSettings.RedirectUri)) &&
            authorize.Contains("state=" + pkce.State) && !authorize.Contains("secret"), "authorize URL is wrong");

        // The loopback redirect: state must match, cancel and junk are refused.
        Require(DiscordSignIn.ParseRedirect($"GET /discord?code=abc&state={pkce.State} HTTP/1.1", pkce.State).Code == "abc", "good redirect refused");
        Require(DiscordSignIn.ParseRedirect($"GET /discord?code=abc&state=other HTTP/1.1", pkce.State).Code == null, "foreign state accepted");
        Require(DiscordSignIn.ParseRedirect($"GET /discord?error=access_denied&state={pkce.State} HTTP/1.1", pkce.State).Code == null, "cancel accepted");
        Require(DiscordSignIn.ParseRedirect("GET /favicon.ico HTTP/1.1", pkce.State).Code == null, "other path accepted");
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        try {
            var port = ((IPEndPoint)listener.LocalEndpoint).Port;
            var receive = DiscordSignIn.ReceiveCode(listener, pkce.State, new CancellationTokenSource(TimeSpan.FromSeconds(10)).Token);
            async Task<string> Get(string path) {
                using var client = new TcpClient();
                await client.ConnectAsync(IPAddress.Loopback, port);
                using var stream = client.GetStream();
                await stream.WriteAsync(Encoding.ASCII.GetBytes($"GET {path} HTTP/1.1\r\nHost: 127.0.0.1\r\n\r\n"));
                return await new StreamReader(stream).ReadToEndAsync();
            }
            Require((await Get("/favicon.ico")).Contains("Not a Discord sign-in"), "stray request not answered");
            Require((await Get($"/discord?code=xyz&state={pkce.State}")).Contains("Signed in to Civ13"), "redirect page missing");
            Require(await receive == "xyz", "loopback code lost");
        } finally { listener.Stop(); }

        // Join tickets: refresh at Discord, then trade the new access token for a ticket by game port.
        File.WriteAllText(Path.Combine(folder, DiscordSignIn.FileName), "{\"refresh_token\": \"refresh-1\"}");
        var ticketAnswer = (HttpStatusCode.OK, JsonSerializer.Serialize(new { ok = true, result = new { ticket = Ticket, expires_in = 120 } }));
        var fake = new FakeHttp((request, _) => request.RequestUri!.Host == "discord.test"
            ? (HttpStatusCode.OK, "{\"access_token\": \"access-2\", \"refresh_token\": \"refresh-2\"}")
            : ticketAnswer);
        using var http = new HttpClient(fake);
        var signIn = new DiscordSignIn(settings, folder, http, _ => false, "https://discord.test/api");
        Require(signIn.SignedIn, "stored refresh token not read");
        Require(await signIn.JoinTicket(1714) == Ticket, "ticket not returned");
        Require(fake.Seen[0].Url == "https://discord.test/api/oauth2/token" && fake.Seen[0].Body.Contains("grant_type=refresh_token") &&
            fake.Seen[0].Body.Contains("refresh_token=refresh-1") && fake.Seen[0].Body.Contains("client_id=" + PresenceSettings.BuiltInApplicationId) &&
            !fake.Seen[0].Body.Contains("secret"), "refresh request is wrong");
        using (var sent = JsonDocument.Parse(fake.Seen[1].Body))
            Require(fake.Seen[1].Url == "https://signin.example.test/signin" && sent.RootElement.GetProperty("access_token").GetString() == "access-2" &&
                sent.RootElement.GetProperty("port").GetInt32() == 1714, "sign-in service request is wrong");
        Require(File.ReadAllText(Path.Combine(folder, DiscordSignIn.FileName)).Contains("refresh-2"), "rotated refresh token not saved");
        ticketAnswer = (HttpStatusCode.OK, JsonSerializer.Serialize(new { ok = true, result = new { ticket = "short" } }));
        await Refuse(() => signIn.JoinTicket(1714), "malformed ticket");
        ticketAnswer = (HttpStatusCode.Conflict, "{\"ok\": false, \"error\": \"unknown server\"}");
        await Refuse(() => signIn.JoinTicket(1799), "refused ticket");
        Require(signIn.SignedIn, "a refused ticket signed the player out");
        var expired = new FakeHttp((_, _) => (HttpStatusCode.BadRequest, "{\"error\": \"invalid_grant\"}"));
        using var expiredHttp = new HttpClient(expired);
        var stale = new DiscordSignIn(settings, folder, expiredHttp, _ => false, "https://discord.test/api");
        await Refuse(() => stale.JoinTicket(1714), "expired refresh token");
        Require(!stale.SignedIn, "an expired refresh token was kept");
        await Refuse(() => stale.JoinTicket(1714), "join ticket without sign-in");

        // Only a well-formed ticket rides in the join link.
        Require(DiscordSignIn.ValidTicket(Ticket) && !DiscordSignIn.ValidTicket("a b") && !DiscordSignIn.ValidTicket(null) &&
            !DiscordSignIn.ValidTicket(new string('a', 129)) && !DiscordSignIn.ValidTicket(Ticket + "&x=1"), "ticket shape check");
        return assertions;
    }
}
