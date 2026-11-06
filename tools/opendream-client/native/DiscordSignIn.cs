using System.Net;
using System.Net.Sockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Civ13.Launcher;

// Optional "Sign in with Discord" for Civ13 accounts (docs/accounts/discord-accounts.md).
// The launcher is a Discord OAuth2 public client: PKCE, no client secret. It keeps
// the player's refresh token in the launcher data folder, and before each join
// trades a fresh access token at the Civ13 sign-in service for a single-use ticket.
// Only that ticket rides in the byond:// link. BYOND play never needs any of this.
public sealed record DiscordSignInSettings(string ClientId, Uri SigninUrl) {
    public const int RedirectPort = 53134;
    public static readonly string RedirectUri = $"http://127.0.0.1:{RedirectPort}/discord";

    // The Civ13 sign-in service. discord.json can point elsewhere with "signin_url",
    // or turn the sign-in link off with "signin_url": "".
    public const string BuiltInSigninUrl = "https://signin.valzargaming.com/signin";

    // The client ID is the presence application's unless discord.json overrides it.
    public static DiscordSignInSettings? Load(string root) {
        var clientId = PresenceSettings.ValidId(PresenceSettings.BuiltInApplicationId);
        var url = ValidUrl(BuiltInSigninUrl);
        try {
            var path = Path.Combine(root, PresenceSettings.FileName);
            if (File.Exists(path)) {
                using var document = JsonDocument.Parse(File.ReadAllText(path));
                var json = document.RootElement;
                if (json.TryGetProperty("signin_client_id", out var id) && id.ValueKind == JsonValueKind.String)
                    clientId = PresenceSettings.ValidId(id.GetString()) ?? clientId;
                if (json.TryGetProperty("signin_url", out var value) && value.ValueKind == JsonValueKind.String)
                    url = ValidUrl(value.GetString());
            }
        } catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException) { }
        return clientId != null && url != null ? new DiscordSignInSettings(clientId, url) : null;
    }

    // HTTPS only: the access token travels in the body.
    public static Uri? ValidUrl(string? text) =>
        Uri.TryCreate(text, UriKind.Absolute, out var url) && url.Scheme == Uri.UriSchemeHttps &&
        string.IsNullOrEmpty(url.UserInfo) && string.IsNullOrEmpty(url.Query) && string.IsNullOrEmpty(url.Fragment) ? url : null;
}

public sealed class DiscordSignInException(string message, Exception? inner = null) : IOException(message, inner);

public sealed record PkcePair(string Verifier, string Challenge, string State) {
    public static PkcePair Create() {
        var verifier = Base64Url(RandomNumberGenerator.GetBytes(32));
        return new PkcePair(verifier, Base64Url(SHA256.HashData(Encoding.ASCII.GetBytes(verifier))),
            Base64Url(RandomNumberGenerator.GetBytes(16)));
    }
    public static string Base64Url(byte[] data) => Convert.ToBase64String(data).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}

public sealed class DiscordSignIn {
    public const string FileName = "discord-signin.json";
    public const string DiscordApi = "https://discord.com/api/v10";
    private static readonly Regex TicketShape = new("^[A-Za-z0-9_-]{32,128}$");
    private readonly DiscordSignInSettings settings;
    private readonly string root;
    private readonly HttpClient http;
    private readonly Func<Uri, bool> openBrowser;
    private readonly string discordApi;

    public DiscordSignIn(DiscordSignInSettings settings, string root, HttpClient http, Func<Uri, bool> openBrowser, string discordApi = DiscordApi) {
        this.settings = settings;
        this.root = root;
        this.http = http;
        this.openBrowser = openBrowser;
        this.discordApi = discordApi.TrimEnd('/');
    }

    public bool SignedIn => ReadRefreshToken() != null;

    public static Uri AuthorizeUrl(DiscordSignInSettings settings, PkcePair pkce, bool silent) {
        var query = new Dictionary<string, string> {
            ["response_type"] = "code", ["client_id"] = settings.ClientId, ["scope"] = "identify",
            ["redirect_uri"] = DiscordSignInSettings.RedirectUri, ["state"] = pkce.State,
            ["code_challenge"] = pkce.Challenge, ["code_challenge_method"] = "S256",
            ["prompt"] = silent ? "none" : "consent",
        };
        return new Uri("https://discord.com/oauth2/authorize?" + string.Join("&",
            query.Select(pair => Uri.EscapeDataString(pair.Key) + "=" + Uri.EscapeDataString(pair.Value))));
    }

    // Opens Discord's consent page in the browser and waits for the loopback redirect.
    public async Task SignInInteractive(CancellationToken cancellationToken = default) {
        var pkce = PkcePair.Create();
        var listener = new TcpListener(IPAddress.Loopback, DiscordSignInSettings.RedirectPort);
        try { listener.Start(); }
        catch (SocketException e) { throw new DiscordSignInException($"Port {DiscordSignInSettings.RedirectPort} is in use; close the other sign-in and try again.", e); }
        try {
            if (!openBrowser(AuthorizeUrl(settings, pkce, silent: false)))
                throw new DiscordSignInException("Could not open the browser for Discord sign-in.");
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(TimeSpan.FromMinutes(5));
            var code = await ReceiveCode(listener, pkce.State, timeout.Token);
            var tokens = await Token(new Dictionary<string, string> {
                ["grant_type"] = "authorization_code", ["code"] = code, ["redirect_uri"] = DiscordSignInSettings.RedirectUri,
                ["code_verifier"] = pkce.Verifier,
            }, cancellationToken);
            SaveRefreshToken(tokens.Refresh);
        } catch (OperationCanceledException e) {
            throw new DiscordSignInException("Discord sign-in timed out or was cancelled.", e);
        } finally { listener.Stop(); }
    }

    public void SignOut() {
        try { File.Delete(Path.Combine(root, FileName)); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
    }

    // A fresh single-use join ticket for the world on one game port, or an exception.
    // Uses the stored refresh token; a refused refresh signs the player out.
    public async Task<string> JoinTicket(int port, CancellationToken cancellationToken = default) {
        var refresh = ReadRefreshToken() ?? throw new DiscordSignInException("Not signed in with Discord.");
        (string Access, string Refresh) tokens;
        try {
            tokens = await Token(new Dictionary<string, string> { ["grant_type"] = "refresh_token", ["refresh_token"] = refresh }, cancellationToken);
        } catch (DiscordSignInException) {
            SignOut();
            throw new DiscordSignInException("Your Discord sign-in expired. Sign in with Discord again.");
        }
        SaveRefreshToken(tokens.Refresh);
        var body = JsonSerializer.Serialize(new { access_token = tokens.Access, port });
        using var request = new HttpRequestMessage(HttpMethod.Post, settings.SigninUrl) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
        using var response = await Send(request, cancellationToken);
        var json = await Read(response, cancellationToken);
        if (!response.IsSuccessStatusCode || !json.TryGetProperty("ok", out var ok) || ok.ValueKind != JsonValueKind.True ||
            !json.TryGetProperty("result", out var result) || !result.TryGetProperty("ticket", out var ticket) ||
            ticket.ValueKind != JsonValueKind.String || !TicketShape.IsMatch(ticket.GetString()!))
            throw new DiscordSignInException("The Civ13 sign-in service refused the sign-in" +
                (json.TryGetProperty("error", out var error) && error.ValueKind == JsonValueKind.String ? ": " + error.GetString() : "."));
        return ticket.GetString()!;
    }

    public static bool ValidTicket(string? ticket) => ticket != null && TicketShape.IsMatch(ticket);

    private async Task<(string Access, string Refresh)> Token(Dictionary<string, string> form, CancellationToken cancellationToken) {
        form["client_id"] = settings.ClientId;
        using var request = new HttpRequestMessage(HttpMethod.Post, discordApi + "/oauth2/token") { Content = new FormUrlEncodedContent(form) };
        using var response = await Send(request, cancellationToken);
        var json = await Read(response, cancellationToken);
        if (!response.IsSuccessStatusCode || !json.TryGetProperty("access_token", out var access) || access.ValueKind != JsonValueKind.String ||
            !json.TryGetProperty("refresh_token", out var next) || next.ValueKind != JsonValueKind.String)
            throw new DiscordSignInException("Discord did not accept the sign-in.");
        return (access.GetString()!, next.GetString()!);
    }

    private async Task<HttpResponseMessage> Send(HttpRequestMessage request, CancellationToken cancellationToken) {
        try { return await http.SendAsync(request, cancellationToken).WaitAsync(TimeSpan.FromSeconds(15), cancellationToken); }
        catch (Exception e) when (e is HttpRequestException or TimeoutException or TaskCanceledException) {
            throw new DiscordSignInException("Could not reach " + request.RequestUri!.Host + " for Discord sign-in.", e);
        }
    }

    private static async Task<JsonElement> Read(HttpResponseMessage response, CancellationToken cancellationToken) {
        var text = await response.Content.ReadAsStringAsync(cancellationToken);
        if (text.Length > 64 * 1024) throw new DiscordSignInException("Sign-in answer too large.");
        try { using var document = JsonDocument.Parse(text); return document.RootElement.Clone(); }
        catch (JsonException) { return JsonDocument.Parse("{}").RootElement.Clone(); }
    }

    // One HTTP request on the loopback port: GET /discord?code=...&state=...
    public static async Task<string> ReceiveCode(TcpListener listener, string state, CancellationToken cancellationToken) {
        while (true) {
            using var client = await listener.AcceptTcpClientAsync(cancellationToken);
            using var stream = client.GetStream();
            var buffer = new byte[8192];
            var length = 0;
            while (length < buffer.Length) {
                var read = await stream.ReadAsync(buffer.AsMemory(length), cancellationToken);
                if (read == 0) break;
                length += read;
                if (Encoding.ASCII.GetString(buffer, 0, length).Contains("\r\n\r\n")) break;
            }
            var line = Encoding.ASCII.GetString(buffer, 0, length).Split("\r\n")[0];
            var (code, message) = ParseRedirect(line, state);
            var page = Encoding.UTF8.GetBytes("<!doctype html><meta charset=utf-8><title>Civ13</title><p style=\"font-family:sans-serif\">" +
                WebUtility.HtmlEncode(message) + "</p>");
            var head = Encoding.ASCII.GetBytes($"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: {page.Length}\r\nConnection: close\r\n\r\n");
            await stream.WriteAsync(head, cancellationToken);
            await stream.WriteAsync(page, cancellationToken);
            if (code != null) return code;
            if (message.StartsWith("Discord sign-in was cancelled", StringComparison.Ordinal)) throw new DiscordSignInException(message);
        }
    }

    // The code from a redirect request line, or null with the page text to show.
    public static (string? Code, string Message) ParseRedirect(string requestLine, string state) {
        var parts = requestLine.Split(' ');
        if (parts.Length != 3 || parts[0] != "GET" || !parts[1].StartsWith("/discord?", StringComparison.Ordinal))
            return (null, "Not a Discord sign-in. You can close this tab.");
        var query = parts[1]["/discord?".Length..].Split('&').Select(pair => pair.Split('=', 2))
            .Where(pair => pair.Length == 2).GroupBy(pair => pair[0])
            .ToDictionary(group => group.Key, group => Uri.UnescapeDataString(group.First()[1]));
        if (!query.TryGetValue("state", out var got) || !CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(got), Encoding.ASCII.GetBytes(state)))
            return (null, "This sign-in link does not match the launcher. You can close this tab.");
        if (query.ContainsKey("error")) return (null, "Discord sign-in was cancelled. You can close this tab.");
        if (!query.TryGetValue("code", out var code) || code.Length is 0 or > 512) return (null, "Discord sent no sign-in code. You can close this tab.");
        return (code, "Signed in to Civ13 with Discord. You can close this tab and go back to the launcher.");
    }

    // The refresh token stays in the player's own launcher data folder.
    private string? ReadRefreshToken() {
        try {
            var path = Path.Combine(root, FileName);
            if (!File.Exists(path)) return null;
            using var document = JsonDocument.Parse(File.ReadAllText(path));
            return document.RootElement.TryGetProperty("refresh_token", out var value) && value.ValueKind == JsonValueKind.String &&
                value.GetString() is { Length: > 0 and <= 512 } token ? token : null;
        } catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException) { return null; }
    }

    private void SaveRefreshToken(string token) {
        Directory.CreateDirectory(root);
        var path = Path.Combine(root, FileName);
        var temp = path + ".tmp";
        File.WriteAllText(temp, JsonSerializer.Serialize(new { refresh_token = token }));
        File.Move(temp, path, true);
    }
}
