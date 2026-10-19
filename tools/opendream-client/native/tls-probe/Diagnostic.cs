using System.ComponentModel;
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Security.Authentication;
using System.Text;
using Civ13.Launcher;

var lines = new StringBuilder();
void Log(string text) { Console.WriteLine(text); lines.AppendLine(text); }
if (args.SequenceEqual(new[] { "--self-test" })) {
    var nested = new HttpRequestException("SECRET_URL", new AuthenticationException("SECRET_CERT", new Win32Exception(123, "SECRET_NATIVE")));
    var text = Describe(nested);
    if (text.Contains("SECRET") || !text.Contains("native=123") || !text.Contains("AuthenticationException")) return 1;
    foreach (var errors in new[] { SslPolicyErrors.RemoteCertificateChainErrors, SslPolicyErrors.RemoteCertificateNameMismatch, SslPolicyErrors.RemoteCertificateNotAvailable })
        if (AcceptCertificate(errors)) return 1;
    if (!AcceptCertificate(SslPolicyErrors.None)) return 1;
    Console.WriteLine("PASS: redacted nested error codes and fail-closed certificate decisions.");
    return 0;
}
if (args.Length != 0 && !args.SequenceEqual(new[] { "--no-pause" })) return 2;
var passed = true;
var root = Path.Combine(Path.GetTempPath(), "civ13-tls-probe-" + Guid.NewGuid().ToString("N"));
try {
    Log("Civ13 TLS diagnostic v1; unchanged 1.0.2 transport; no installs or security-setting changes.");
    Log("UTC " + DateTime.UtcNow.ToString("O"));
    Log(RuntimeInformation.FrameworkDescription + "; " + RuntimeInformation.OSDescription + "; " + RuntimeInformation.ProcessArchitecture);
    foreach (var name in new[] { "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY" })
        Log(name + " present=" + !string.IsNullOrEmpty(Environment.GetEnvironmentVariable(name)));
    Directory.CreateDirectory(root);
    using var transport = new ReleaseTransport();
    const string release = "https://github.com/Civ13/Civ13/releases/download/launcher-v1.0.3/Civ13.exe";
    foreach (var stage in new[] { ("feed", Updater.LauncherChannelUrl), ("release", release) }) {
        try {
            Log("START " + stage.Item1 + " host=" + new Uri(stage.Item2).Host);
            try { Log("Default proxy bypass=" + HttpClient.DefaultProxy.IsBypassed(new Uri(stage.Item2))); }
            catch (Exception e) { Log("Proxy inspection unavailable: " + Describe(e)); }
            if (stage.Item1 == "feed") {
                var manifest = Channel.Read(await transport.Text(stage.Item2));
                manifest.Validate(true);
                Log("PASS feed; advertised version=" + Version.Parse(manifest.Version));
            } else {
                var file = Path.Combine(root, "download.tmp");
                await transport.Download(stage.Item2, file);
                Updater.CheckHash(file, "2f0ffac265a1643056722039cb46d89ed49b1d156d3f8035f01b6f2be26ac349");
                Log("PASS release; actual 1.0.3 download SHA256 verified; never executed.");
            }
        } catch (Exception e) {
            passed = false;
            Log("FAIL " + stage.Item1 + ": " + Describe(e));
        }
        // Independent header-only trace identifies the failing hop and certificate status.
        // It uses the same default proxy/TLS settings, and rejects every certificate error.
        await TraceHeaders(stage.Item1, stage.Item2, Log);
    }
} catch (Exception e) { passed = false; Log("FAIL diagnostic: " + Describe(e)); }
finally {
    try { if (Directory.Exists(root)) Directory.Delete(root, true); }
    catch (Exception e) { Log("Temporary-download cleanup failed: " + Describe(e)); }
}
Log("RESULT " + (passed ? "PASS" : "FAIL") + "; share this report. No certificate or proxy values are included.");
try {
    var name = "Civ13-TLS-Diagnostic-" + DateTime.UtcNow.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N")[..6] + ".txt";
    File.WriteAllText(Path.Combine(AppContext.BaseDirectory, name), lines.ToString());
    Console.WriteLine("Report saved beside this executable: " + name);
} catch { Console.WriteLine("Could not save report; copy this window's output instead."); }
if (args.Length == 0 && !Console.IsInputRedirected) { Console.WriteLine("Press Enter to close."); Console.ReadLine(); }
return passed ? 0 : 1;

static bool AcceptCertificate(SslPolicyErrors errors) => errors == SslPolicyErrors.None;
static bool Allowed(Uri uri) => uri.Scheme == "https" && uri.IsDefaultPort && uri.UserInfo.Length == 0 &&
    uri.Host is "raw.githubusercontent.com" or "github.com" or "release-assets.githubusercontent.com" or "objects.githubusercontent.com";
static async Task TraceHeaders(string stage, string url, Action<string> log) {
    using var handler = new HttpClientHandler { AllowAutoRedirect = false };
    handler.ServerCertificateCustomValidationCallback = (_, _, chain, errors) => {
        var statuses = chain is null ? "unavailable" : string.Join(",", chain.ChainStatus.Select(s => s.Status.ToString()).Distinct().Take(12));
        log("TLS " + stage + " policy=" + errors + "; chain=" + (statuses.Length == 0 ? "NoError" : statuses));
        return AcceptCertificate(errors);
    };
    using var http = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(20) };
    var uri = new Uri(url);
    for (var hop = 0; hop <= 5; hop++) {
        if (!Allowed(uri)) { log("Trace blocked untrusted redirect."); return; }
        try {
            log("TRACE " + stage + " hop=" + hop + " host=" + uri.Host);
            using var request = new HttpRequestMessage(HttpMethod.Get, uri);
            using var response = await http.SendAsync(request, HttpCompletionOption.ResponseHeadersRead);
            log("TRACE " + stage + " hop=" + hop + " HTTP=" + (int)response.StatusCode);
            if ((int)response.StatusCode is < 300 or >= 400) return;
            if (response.Headers.Location is not { } location) { log("Trace redirect has no location."); return; }
            uri = location.IsAbsoluteUri ? location : new Uri(uri, location);
        } catch (Exception e) { log("TRACE FAIL " + stage + " hop=" + hop + ": " + Describe(e)); return; }
    }
    log("Trace exceeded five redirects.");
}
static string Describe(Exception error) {
    var parts = new List<string>();
    Exception? current = error;
    for (var depth = 0; current is not null && depth < 6; depth++, current = current.InnerException) {
        var kind = current switch {
            HttpRequestException => "HttpRequestException", AuthenticationException => "AuthenticationException",
            SocketException => "SocketException", Win32Exception => "Win32Exception",
            OperationCanceledException => "OperationCanceledException", IOException => "IOException",
            System.Text.Json.JsonException => "JsonException", FormatException => "FormatException", _ => "Exception"
        };
        var part = kind + FormattableString.Invariant($" HRESULT=0x{unchecked((uint)current.HResult):X8}");
        if (current is HttpRequestException request) {
            part += " " + request.HttpRequestError;
            if (request.StatusCode is { } status) part += " HTTP=" + (int)status;
        }
        if (current is SocketException socket) part += " " + socket.SocketErrorCode;
        if (current is Win32Exception native) part += FormattableString.Invariant($" native={native.NativeErrorCode}/0x{unchecked((uint)native.NativeErrorCode):X8}");
        parts.Add(part);
    }
    return string.Join(" -> ", parts);
}
