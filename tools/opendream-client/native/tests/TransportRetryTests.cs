using Civ13.Launcher;
using System.ComponentModel;
using System.Net;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Text;

// Every request and body is injected. This suite never opens a network socket.
static class TransportRetryTests {
    private const string ManifestUrl = Updater.LauncherChannelUrl;
    private const string ReleaseUrl = "https://github.com/Civ13/Civ13/releases/download/retry-fixture/Civ13.exe";
    private const string AssetUrl = "https://release-assets.githubusercontent.com/retry-fixture/Civ13.exe?token=PRIVATE";
    private const string PrivateFailure = "PRIVATE https://user:password@example.test/?token=secret\r\nINJECTED";

    public static async Task<int> Run(string root) {
        var assertions = 0;
        void Require(bool condition, string message) {
            assertions++;
            if (!condition) throw new Exception("Transport retry contract: " + message);
        }
        async Task<Exception> Failure(Func<Task> action, string message) {
            try { await action().WaitAsync(TimeSpan.FromSeconds(10)); }
            catch (TimeoutException error) { throw new Exception("Transport retry test did not finish: " + message, error); }
            catch (Exception error) { assertions++; return error; }
            throw new Exception("Transport negative control accepted: " + message);
        }
        string CaseRoot(string name) {
            var path = Path.Combine(root, "transport-" + name);
            Directory.CreateDirectory(path);
            return path;
        }
        Task NoDelay(TimeSpan _, CancellationToken token) {
            token.ThrowIfCancellationRequested();
            return Task.CompletedTask;
        }

        Require(ReleaseTransport.IsTransient(Reset()), "nested TLS connection reset was not recognized");
        Require(ReleaseTransport.IsTransient(new HttpRequestException(HttpRequestError.SecureConnectionError, PrivateFailure,
            new AuthenticationException(PrivateFailure, new IOException(PrivateFailure,
                new SocketException((int)SocketError.ConnectionReset))))), "authentication wrapper hid a concrete connection reset");
        Require(ReleaseTransport.IsTransient(new IOException(PrivateFailure, new SocketException((int)SocketError.ConnectionReset))),
            "body-read connection reset was not recognized");
        Require(ReleaseTransport.IsTransient(new TaskCanceledException(PrivateFailure, new TimeoutException(PrivateFailure))),
            "explicit transport timeout was not recognized");
        foreach (var error in PermanentFailures())
            Require(!ReleaseTransport.IsTransient(error), "permanent failure marked transient: " + error.GetType().Name);
        Exception deepFailure = Reset();
        for (var index = 0; index < 20; index++) deepFailure = new IOException(PrivateFailure, deepFailure);
        Require(!ReleaseTransport.IsTransient(deepFailure), "unbounded or incomplete exception chain was classified as transient");

        var retryReports = new List<string>();
        var textDelays = new List<TimeSpan>();
        using (var handler = new ScriptedHandler((attempt, _, _) => {
            if (attempt == 1) throw Reset();
            return Task.FromResult(Ok(new StringContent("manifest recovered")));
        }))
        using (var transport = new ReleaseTransport(handler, retryReports.Add, (delay, token) => {
            textDelays.Add(delay);
            return NoDelay(delay, token);
        })) {
            Require(await transport.Text(ManifestUrl) == "manifest recovered", "text retry lost successful response");
            Require(handler.Requests.Count == 2 && textDelays.Count == 1, "single TLS reset did not retry exactly once");
            Require(handler.Requests.All(uri => uri == ManifestUrl), "text retry changed request URL");
            Require(textDelays.All(delay => delay > TimeSpan.Zero), "retry omitted bounded backoff");
        }
        Require(retryReports.Count > 0, "retry progress was not reported");
        Require(retryReports.All(report => !report.Contains("PRIVATE") && !report.Contains("password") &&
            !report.Contains("token=") && !report.Contains("example.test") && !report.Contains('\r') && !report.Contains('\n')),
            "retry progress leaked private failure details");

        var exhaustedDelays = 0;
        using (var handler = new ScriptedHandler((_, _, _) => throw Reset()))
        using (var transport = new ReleaseTransport(handler, delay: (delay, token) => {
            exhaustedDelays++;
            return NoDelay(delay, token);
        })) {
            var error = await Failure(() => transport.Text(ManifestUrl), "repeated text reset");
            Require(ReleaseTransport.IsTransient(error), "retry exhaustion lost the underlying transport failure");
            Require(handler.Requests.Count == 3 && exhaustedDelays == 2, "repeated reset exceeded or missed the three-attempt cap");
        }

        using (var handler = new ScriptedHandler((_, _, _) => throw new HttpRequestException(
            HttpRequestError.ConnectionError, PrivateFailure, new TimeoutException(PrivateFailure))))
        using (var transport = new ReleaseTransport(handler, delay: NoDelay)) {
            var error = await Failure(() => transport.Text(ManifestUrl), "repeated explicit transport timeout");
            Require(ReleaseTransport.IsTransient(error) && handler.Requests.Count == 3,
                "explicit transport timeout lost its cause or exceeded the three-attempt cap");
        }

        foreach (var permanent in PermanentFailures()) {
            var delays = 0;
            using var handler = new ScriptedHandler((_, _, _) => throw permanent);
            using var transport = new ReleaseTransport(handler, delay: (delay, token) => {
                delays++;
                return NoDelay(delay, token);
            });
            await Failure(() => transport.Text(ManifestUrl), "nontransient text failure");
            Require(handler.Requests.Count == 1 && delays == 0, "certificate, authentication, or local failure was retried");
        }

        foreach (var status in new[] { HttpStatusCode.Unauthorized, HttpStatusCode.Forbidden, HttpStatusCode.NotFound }) {
            using var handler = new ScriptedHandler((_, _, _) => Task.FromResult(new HttpResponseMessage(status)));
            using var transport = new ReleaseTransport(handler, delay: NoDelay);
            var error = await Failure(() => transport.Text(ManifestUrl), "permanent HTTP status");
            Require(error is HttpRequestException request && request.StatusCode == status && handler.Requests.Count == 1,
                "permanent HTTP status was retried or replaced");
        }

        using (var handler = new ScriptedHandler((_, _, _) => Task.FromResult(Ok(new StringContent(new string('x', 65537))))))
        using (var transport = new ReleaseTransport(handler, delay: NoDelay)) {
            var error = await Failure(() => transport.Text(ManifestUrl), "oversized manifest");
            Require(error is InvalidDataException && handler.Requests.Count == 1, "manifest size rejection was retried");
        }

        foreach (var location in new[] {
            "https://example.test/Civ13.exe", "http://github.com/Civ13/Civ13/releases/download/test/Civ13.exe",
            "https://github.com:444/Civ13.exe", "https://user:password@github.com/Civ13.exe"
        }) {
            var destination = Path.Combine(CaseRoot("redirect-" + assertions), "Civ13.exe");
            using var handler = new ScriptedHandler((_, _, _) => Task.FromResult(Redirect(location)));
            using var transport = new ReleaseTransport(handler, delay: NoDelay);
            await Failure(() => transport.Download(ReleaseUrl, destination), "untrusted release redirect");
            Require(handler.Requests.Count == 1 && !File.Exists(destination), "untrusted redirect was followed or retried");
        }

        var downloadRoot = CaseRoot("partial-recovery");
        var downloadPath = Path.Combine(downloadRoot, "Civ13.exe");
        var bytes = Encoding.UTF8.GetBytes("complete verified fixture bytes");
        var partial = new ControlledContent(async (stream, token) => {
            await stream.WriteAsync(Encoding.UTF8.GetBytes("discarded partial bytes"), token);
            throw new IOException(PrivateFailure, new SocketException((int)SocketError.ConnectionReset));
        });
        var successful = new ControlledContent((stream, token) => stream.WriteAsync(bytes, token).AsTask());
        using (var handler = new ScriptedHandler((attempt, _, _) => {
            if (attempt == 3) {
                Require(partial.Disposed, "failed response body remained open during retry");
                Require(!File.Exists(downloadPath), "partial destination remained before retry");
            }
            return Task.FromResult(attempt is 1 or 3 ? Redirect(AssetUrl) : Ok(attempt == 2 ? partial : successful));
        }))
        using (var transport = new ReleaseTransport(handler, delay: NoDelay)) {
            await transport.Download(ReleaseUrl, downloadPath);
            Require(handler.Requests.SequenceEqual(new[] { ReleaseUrl, AssetUrl, ReleaseUrl, AssetUrl }),
                "download retry did not restart the trusted redirect chain");
            Require(File.ReadAllBytes(downloadPath).SequenceEqual(bytes), "download retry appended partial bytes or changed content");
            Require(Directory.GetFiles(downloadRoot).SequenceEqual(new[] { downloadPath }), "successful download retained temporary files");
            Require(successful.Disposed, "successful response body was not disposed");
        }

        var exhaustedRoot = CaseRoot("partial-exhaustion");
        var exhaustedPath = Path.Combine(exhaustedRoot, "Civ13.exe");
        var failedBodies = new List<ControlledContent>();
        using (var handler = new ScriptedHandler((_, _, _) => {
            Require(!File.Exists(exhaustedPath), "failed download was present at the next attempt");
            var body = new ControlledContent(async (stream, token) => {
                await stream.WriteAsync(bytes.AsMemory(0, 3), token);
                throw new IOException(PrivateFailure, new SocketException((int)SocketError.ConnectionReset));
            });
            failedBodies.Add(body);
            return Task.FromResult(Ok(body));
        }))
        using (var transport = new ReleaseTransport(handler, delay: NoDelay)) {
            await Failure(() => transport.Download(ReleaseUrl, exhaustedPath), "repeated partial body reset");
            Require(handler.Requests.Count == 3, "partial failures did not honor the three-attempt cap");
            Require(!Directory.EnumerateFileSystemEntries(exhaustedRoot).Any(), "exhausted download left partial data");
            Require(failedBodies.All(body => body.Disposed), "exhausted response body was not disposed");
        }

        foreach (var createDuringRequest in new[] { false, true }) {
            var destination = Path.Combine(CaseRoot("existing-" + createDuringRequest), "Civ13.exe");
            if (!createDuringRequest) File.WriteAllText(destination, "unowned existing bytes");
            using var handler = new ScriptedHandler((_, _, _) => {
                if (createDuringRequest) File.WriteAllText(destination, "unowned existing bytes");
                return Task.FromResult(Ok(new ByteArrayContent(bytes)));
            });
            using var transport = new ReleaseTransport(handler, delay: NoDelay);
            await Failure(() => transport.Download(ReleaseUrl, destination), "existing destination");
            Require(File.ReadAllText(destination) == "unowned existing bytes", "download deleted or overwrote an unowned destination");
            Require(handler.Requests.Count <= 1, "existing destination failure was retried");
        }

        var stageRoot = CaseRoot("checksum");
        var channel = new Channel(1, "1.0.1", ReleaseUrl, new string('0', 64));
        var validations = 0;
        using (var handler = new ScriptedHandler((_, _, _) => Task.FromResult(Ok(new ByteArrayContent(bytes)))))
        using (var transport = new ReleaseTransport(handler, delay: NoDelay)) {
            var error = await Failure(() => Updater.StageLauncher(channel, new Version(1, 0, 0), stageRoot, transport,
                (_, _) => validations++), "launcher checksum mismatch");
            Require(error is InvalidDataException && handler.Requests.Count == 1 && validations == 0,
                "checksum mismatch retried or reached executable validation");
            var staged = Directory.GetFiles(stageRoot, "Civ13.exe", SearchOption.AllDirectories).Single();
            Require(File.ReadAllBytes(staged).SequenceEqual(bytes), "checksum failure changed diagnostic staging bytes");
        }

        var validChannel = channel with { Sha256 = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant() };
        using (var handler = new ScriptedHandler((_, _, _) => Task.FromResult(Ok(new ByteArrayContent(bytes)))))
        using (var transport = new ReleaseTransport(handler, delay: NoDelay)) {
            var error = await Failure(() => Updater.StageLauncher(validChannel, new Version(1, 0, 0), stageRoot, transport,
                (_, _) => throw new InvalidDataException("fixture executable version mismatch")), "executable validation mismatch");
            Require(error is InvalidDataException && handler.Requests.Count == 1, "executable validation mismatch was retried");
        }

        // Timers control cancellation only; assertions do not depend on an exact duration.
        // A stuck implementation fails the independent ten-second guard above.
        var budget = TimeSpan.FromMilliseconds(100);
        CancellationToken requestToken = default;
        using (var handler = new ScriptedHandler(async (_, _, token) => {
            requestToken = token;
            await Task.Delay(Timeout.InfiniteTimeSpan, token);
            throw new Exception("Canceled request unexpectedly resumed");
        }))
        using (var transport = new ReleaseTransport(handler, delay: NoDelay, textBudget: budget)) {
            var error = await Failure(() => transport.Text(ManifestUrl), "text request overall budget");
            Require(error is OperationCanceledException && requestToken.IsCancellationRequested && handler.Requests.Count == 1,
                "overall text deadline did not cancel the request or was retried");
        }

        var canceledRoot = CaseRoot("canceled-body");
        var canceledPath = Path.Combine(canceledRoot, "Civ13.exe");
        CancellationToken bodyToken = default;
        var blockedBody = new ControlledContent(async (stream, token) => {
            bodyToken = token;
            await stream.WriteAsync(bytes.AsMemory(0, 3), token);
            await Task.Delay(Timeout.InfiniteTimeSpan, token);
        });
        using (var handler = new ScriptedHandler((_, _, _) => Task.FromResult(Ok(blockedBody))))
        using (var transport = new ReleaseTransport(handler, delay: NoDelay, downloadBudget: budget)) {
            var error = await Failure(() => transport.Download(ReleaseUrl, canceledPath), "download body overall budget");
            Require(error is OperationCanceledException && bodyToken.IsCancellationRequested && handler.Requests.Count == 1,
                "overall download deadline did not cancel the body or was retried");
            Require(!Directory.EnumerateFileSystemEntries(canceledRoot).Any() && blockedBody.Disposed,
                "canceled download retained partial data or an open body");
        }

        var delayedRetries = 0;
        CancellationToken delayToken = default;
        using (var handler = new ScriptedHandler((_, _, _) => throw Reset()))
        using (var transport = new ReleaseTransport(handler, delay: async (_, token) => {
            delayedRetries++;
            delayToken = token;
            await Task.Delay(Timeout.InfiniteTimeSpan, token);
        }, textBudget: budget)) {
            var error = await Failure(() => transport.Text(ManifestUrl), "budget during backoff");
            Require(error is OperationCanceledException && delayToken.IsCancellationRequested &&
                delayedRetries == 1 && handler.Requests.Count == 1, "backoff escaped the overall budget or restarted its deadline");
        }
        return assertions;
    }

    private static HttpRequestException Reset() => new(HttpRequestError.SecureConnectionError, PrivateFailure,
        new IOException(PrivateFailure, new SocketException((int)SocketError.ConnectionReset)));

    private static Exception[] PermanentFailures() => [
        new AuthenticationException(PrivateFailure),
        new HttpRequestException(HttpRequestError.SecureConnectionError, PrivateFailure, new AuthenticationException(PrivateFailure)),
        new HttpRequestException(HttpRequestError.SecureConnectionError, PrivateFailure,
            new AuthenticationException(PrivateFailure, new Win32Exception(unchecked((int)0x80090325)))),
        new HttpRequestException(HttpRequestError.UserAuthenticationError, PrivateFailure, Reset()),
        new HttpRequestException(HttpRequestError.HttpProtocolError, PrivateFailure, Reset(), HttpStatusCode.Unauthorized),
        new IOException(PrivateFailure, new SocketException((int)SocketError.AccessDenied)),
        new IOException(PrivateFailure),
        new InvalidDataException(PrivateFailure),
        new UnauthorizedAccessException(PrivateFailure),
        new OperationCanceledException(PrivateFailure),
        new TaskCanceledException(PrivateFailure)
    ];

    private static HttpResponseMessage Ok(HttpContent content) => new(HttpStatusCode.OK) { Content = content };
    private static HttpResponseMessage Redirect(string location) {
        var response = new HttpResponseMessage(HttpStatusCode.Redirect);
        response.Headers.Location = new Uri(location);
        return response;
    }

    private sealed class ScriptedHandler(Func<int, HttpRequestMessage, CancellationToken, Task<HttpResponseMessage>> send)
        : HttpMessageHandler {
        public List<string> Requests { get; } = [];
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken token) {
            Requests.Add(request.RequestUri!.AbsoluteUri);
            return send(Requests.Count, request, token);
        }
    }

    private sealed class ControlledContent(Func<Stream, CancellationToken, Task> write) : HttpContent {
        public bool Disposed { get; private set; }
        protected override Task SerializeToStreamAsync(Stream stream, TransportContext? context) =>
            write(stream, CancellationToken.None);
        protected override Task SerializeToStreamAsync(Stream stream, TransportContext? context, CancellationToken token) =>
            write(stream, token);
        protected override bool TryComputeLength(out long length) { length = 0; return false; }
        protected override void Dispose(bool disposing) {
            if (disposing) Disposed = true;
            base.Dispose(disposing);
        }
    }
}
