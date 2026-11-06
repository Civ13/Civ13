using System.Diagnostics;
using System.ComponentModel;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Text.Json;

namespace Civ13.Launcher;

public sealed record Channel(int Schema, string Version, string Url, string Sha256) {
    public static Channel Read(string json) => JsonSerializer.Deserialize<Channel>(json,
        new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
        ?? throw new InvalidDataException("Empty update manifest.");

    public void Validate(bool executable = false) {
        if (Schema != 1 || string.IsNullOrWhiteSpace(Version) || Version.Length > 100 ||
            Sha256 is null || Sha256.Length != 64 || !Sha256.All(Uri.IsHexDigit) ||
            !Uri.TryCreate(Url, UriKind.Absolute, out var uri) || uri.Scheme != "https" ||
            uri.Host != "github.com" || !uri.IsDefaultPort || uri.UserInfo.Length != 0 ||
            uri.Query.Length != 0 || uri.Fragment.Length != 0 ||
            !uri.AbsolutePath.StartsWith("/Civ13/Civ13/releases/download/", StringComparison.Ordinal) ||
            (executable && (!uri.AbsolutePath.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) ||
                            !System.Version.TryParse(Version, out _))))
            throw new InvalidDataException("Update must have a version, SHA-256 and a Civ13 HTTPS release URL.");
    }
}

public interface ITransport {
    Task<string> Text(string url);
    Task Download(string url, string destination);
}

public sealed class ReleaseTransport : ITransport, IDisposable {
    private readonly HttpClient _http;
    private readonly Action<string>? _report;
    private readonly Func<TimeSpan, CancellationToken, Task> _delay;
    private readonly TimeSpan _textBudget;
    private readonly TimeSpan _downloadBudget;
    // A connection reset during the TLS handshake (10054) usually clears within seconds; retries
    // that came 250 ms apart all landed inside the same outage, so the waits now double from one second.
    public const int Attempts = 5;
    public static TimeSpan Backoff(int failedAttempt) => TimeSpan.FromSeconds(1 << Math.Clamp(failedAttempt - 1, 0, 3));
    public ReleaseTransport() : this(new HttpClientHandler { AllowAutoRedirect = false }) { }
    public ReleaseTransport(HttpMessageHandler handler, Action<string>? report = null,
        Func<TimeSpan, CancellationToken, Task>? delay = null, TimeSpan? textBudget = null,
        TimeSpan? downloadBudget = null) {
        _http = new HttpClient(handler) { Timeout = Timeout.InfiniteTimeSpan };
        _report = report;
        _delay = delay ?? ((time, token) => Task.Delay(time, token));
        // Five six-second attempts plus 1 + 2 + 4 + 8 seconds of waiting.
        _textBudget = textBudget ?? TimeSpan.FromSeconds(60);
        _downloadBudget = downloadBudget ?? TimeSpan.FromMinutes(10);
        if (_textBudget <= TimeSpan.Zero || _downloadBudget <= TimeSpan.Zero)
            throw new ArgumentOutOfRangeException(nameof(textBudget), "Update budgets must be positive.");
    }
    public static bool IsTransient(Exception error) {
        var transient = false;
        Exception? current = error;
        for (var depth = 0; current is not null && depth < 16; depth++, current = current.InnerException) {
            // Never retry certificate/native authentication errors or HTTP rejections.
            if (current is HttpRequestException request && (request.StatusCode is not null ||
                request.HttpRequestError is HttpRequestError.UserAuthenticationError or HttpRequestError.ProxyTunnelError)) return false;
            if (current is Win32Exception && current is not SocketException) return false;
            if (current is SocketException socket) {
                if (socket.SocketErrorCode is not (SocketError.ConnectionReset or SocketError.ConnectionAborted or
                    SocketError.NetworkReset or SocketError.TimedOut)) return false;
                transient = true;
            }
            if (current is TimeoutException) transient = true;
        }
        // An incomplete chain could hide a non-retryable cause.
        return current is null && transient;
    }
    private async Task<T> Retry<T>(Func<CancellationToken, Task<T>> action, TimeSpan budget,
        TimeSpan? attemptBudget, string stage) {
        using var overall = new CancellationTokenSource(budget);
        for (var attempt = 1; ; attempt++) {
            overall.Token.ThrowIfCancellationRequested();
            using var deadline = CancellationTokenSource.CreateLinkedTokenSource(overall.Token);
            if (attemptBudget is { } limit) deadline.CancelAfter(limit);
            try { return await action(deadline.Token); }
            catch (Exception e) when (attempt < Attempts && !overall.IsCancellationRequested &&
                (IsTransient(e) || (e is OperationCanceledException && deadline.IsCancellationRequested))) {
                var wait = Backoff(attempt);
                _report?.Invoke($"{stage} connection interrupted; retrying in {wait.TotalSeconds:0} s ({attempt + 1}/{Attempts})...");
                await _delay(wait, overall.Token);
            }
        }
    }
    public Task<string> Text(string url) => Retry(async token => {
        using var response = await _http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, token);
        response.EnsureSuccessStatusCode();
        if (response.Content.Headers.ContentLength > 65536) throw new InvalidDataException("Manifest too large.");
        var text = await response.Content.ReadAsStringAsync(token);
        if (text.Length > 65536) throw new InvalidDataException("Manifest too large.");
        return text;
    }, _textBudget, TimeSpan.FromSeconds(6), "Update manifest");

    public async Task Download(string url, string destination) => await Retry(async token => {
        var created = false;
        var complete = false;
        try {
            var uri = new Uri(url);
            for (var redirects = 0; redirects <= 5; redirects++) {
                using var headerDeadline = CancellationTokenSource.CreateLinkedTokenSource(token);
                headerDeadline.CancelAfter(TimeSpan.FromSeconds(20));
                HttpResponseMessage response;
                try { response = await _http.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, headerDeadline.Token); }
                catch (OperationCanceledException e) when (headerDeadline.IsCancellationRequested && !token.IsCancellationRequested) {
                    throw new HttpRequestException(HttpRequestError.ConnectionError, "Release response headers timed out.",
                        new TimeoutException("Release response headers timed out.", e));
                }
                headerDeadline.CancelAfter(Timeout.InfiniteTimeSpan);
                using (response) {
                    if ((int)response.StatusCode is >= 300 and < 400) {
                        var location = response.Headers.Location ?? throw new IOException("Missing release redirect.");
                        uri = location.IsAbsoluteUri ? location : new Uri(uri, location);
                        if (uri.Scheme != "https" || !uri.IsDefaultPort || uri.UserInfo.Length != 0 ||
                            (uri.Host != "github.com" && uri.Host != "release-assets.githubusercontent.com" &&
                             uri.Host != "objects.githubusercontent.com"))
                            throw new IOException("Untrusted release redirect.");
                        continue;
                    }
                    response.EnsureSuccessStatusCode();
                    await using (var output = new FileStream(destination, FileMode.CreateNew)) {
                        created = true;
                        await response.Content.CopyToAsync(output, token);
                        await output.FlushAsync(token);
                        output.Flush(true);
                    }
                    complete = true;
                    return true;
                }
            }
            throw new IOException("Too many release redirects.");
        } finally {
            // Only a file this attempt created belongs to us. Never remove a caller's
            // pre-existing file after CreateNew rejects it; never append on retry.
            if (created && !complete) File.Delete(destination);
        }
    }, _downloadBudget, null, "Update download");
    public void Dispose() => _http.Dispose();
}

public static class Updater {
    // Exception messages/stack traces can contain signed URLs or credentials.
    // Keep only framework classifications and numeric codes from a bounded chain.
    public static string DescribeFailure(Exception error) {
        ArgumentNullException.ThrowIfNull(error);
        var parts = new List<string>();
        Exception? current = error;
        for (var depth = 0; current is not null && depth < 6; depth++, current = current.InnerException) {
            var kind = current switch {
                HttpRequestException => "HttpRequestException",
                AuthenticationException => "AuthenticationException",
                SocketException => "SocketException",
                Win32Exception => "Win32Exception",
                TaskCanceledException => "TaskCanceledException",
                TimeoutException => "TimeoutException",
                OperationCanceledException => "OperationCanceledException",
                IOException => "IOException",
                JsonException => "JsonException",
                FormatException => "FormatException",
                _ => "Exception"
            };
            var part = kind + FormattableString.Invariant($" HRESULT=0x{unchecked((uint)current.HResult):X8}");
            if (current is HttpRequestException request) {
                part += " " + request.HttpRequestError;
                if (request.StatusCode is { } status)
                    part += FormattableString.Invariant($" HTTP={(int)status}");
            }
            if (current is SocketException socket)
                part += " " + socket.SocketErrorCode;
            if (current is Win32Exception native)
                part += FormattableString.Invariant($" native={native.NativeErrorCode}/0x{unchecked((uint)native.NativeErrorCode):X8}");
            parts.Add(part);
        }
        if (current is not null) parts.Add("...");
        var result = string.Join(" -> ", parts);
        return result.Length > 512 ? result[..509] + "..." : result;
    }

    public const string LauncherChannelUrl = "https://raw.githubusercontent.com/Civ13/Civ13/native-launcher-updates/native-launcher-channel.json";
    public static FileStream Lock(string root) {
        Directory.CreateDirectory(root);
        try { return new FileStream(Path.Combine(root, "launcher.lock"), FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None); }
        catch (IOException e) { throw new IOException("Another Civ13 launcher is updating. Wait for it to finish.", e); }
    }
    public static string Hash(string path) {
        using var input = File.OpenRead(path);
        return Convert.ToHexString(SHA256.HashData(input)).ToLowerInvariant();
    }
    public static void CheckHash(string path, string expected) {
        if (!Hash(path).Equals(expected, StringComparison.OrdinalIgnoreCase))
            throw new InvalidDataException("Checksum failed. Previous versions have been preserved.");
    }
    public static void AtomicText(string path, string text) {
        var stage = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        using (var output = new FileStream(stage, FileMode.CreateNew)) {
            var bytes = System.Text.Encoding.UTF8.GetBytes(text);
            output.Write(bytes);
            output.Flush(true);
        }
        File.Move(stage, path, true);
    }
    public static void ValidateExecutable(string path, string version) {
        using (var stream = File.OpenRead(path)) {
            if (stream.ReadByte() != 'M' || stream.ReadByte() != 'Z') throw new InvalidDataException("Update is not a Windows executable.");
        }
        var actual = FileVersionInfo.GetVersionInfo(path).ProductVersion?.Split('+')[0];
        if (!System.Version.TryParse(actual, out var actualVersion) || actualVersion != System.Version.Parse(version))
            throw new InvalidDataException("Launcher executable version differs from its manifest.");
    }
    public static async Task<string?> StageLauncher(Channel channel, System.Version current, string root,
        ITransport transport, Action<string, string>? validate = null) {
        channel.Validate(true);
        if (System.Version.Parse(channel.Version) <= current) return null;
        var stage = Path.Combine(root, "launcher-stage-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(stage);
        var candidate = Path.Combine(stage, "Civ13.exe");
        await transport.Download(channel.Url, candidate);
        CheckHash(candidate, channel.Sha256);
        (validate ?? ValidateExecutable)(candidate, channel.Version);
        return candidate;
    }
    public static void ReplaceLauncher(string candidate, string target, string expected, string version) {
        CheckHash(candidate, expected);
        ValidateExecutable(candidate, version);
        var adjacent = target + "." + Guid.NewGuid().ToString("N") + ".tmp";
        File.Copy(candidate, adjacent);
        CheckHash(adjacent, expected);
        // Same-volume Windows replacement is atomic; the old EXE remains as a backup.
        try { File.Replace(adjacent, target, target + ".previous", true); }
        finally { if (File.Exists(adjacent)) File.Delete(adjacent); }
    }
    public static void ApplyVerifiedUpdate(string candidate, string target, string expected, string version,
        string root, Action<string> checkStartup, Action<string> restart) {
        var replaced = false;
        try {
            using (Lock(root)) {
                ReplaceLauncher(candidate, target, expected, version);
                replaced = true;
                checkStartup(target);
            }
            // The new launcher must be able to acquire the setup lock.
            restart(target);
            AtomicText(Path.Combine(root, "native-update-result.json"), JsonSerializer.Serialize(new { success = true, version, sha256 = expected }));
        } catch (Exception failure) {
            var rolledBack = false;
            try {
                if (replaced) {
                    using (Lock(root)) {
                        CheckHash(target, expected);
                        File.Replace(target + ".previous", target, target + ".failed", true);
                        rolledBack = true;
                    }
                }
            } finally {
                AtomicText(Path.Combine(root, "native-update-result.json"), JsonSerializer.Serialize(new { success = false, rolledBack, error = failure.Message }));
            }
            throw;
        }
    }
}
