using System.Diagnostics;
using System.IO.Compression;
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
    private readonly HttpClient _http = new(new HttpClientHandler { AllowAutoRedirect = false }) {
        Timeout = TimeSpan.FromMinutes(10)
    };
    public async Task<string> Text(string url) {
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(20));
        using var response = await _http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
        response.EnsureSuccessStatusCode();
        if (response.Content.Headers.ContentLength > 65536) throw new InvalidDataException("Manifest too large.");
        var text = await response.Content.ReadAsStringAsync(timeout.Token);
        if (text.Length > 65536) throw new InvalidDataException("Manifest too large.");
        return text;
    }
    public async Task Download(string url, string destination) {
        var uri = new Uri(url);
        for (var redirects = 0; redirects <= 5; redirects++) {
            using var response = await _http.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead);
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
            await using var output = new FileStream(destination, FileMode.CreateNew);
            await response.Content.CopyToAsync(output);
            await output.FlushAsync();
            output.Flush(true);
            return;
        }
        throw new IOException("Too many release redirects.");
    }
    public void Dispose() => _http.Dispose();
}

public static class Updater {
    public const string ClientChannelUrl = "https://raw.githubusercontent.com/Civ13/Civ13/master/tools/opendream-client/channel.json";
    public const string LauncherChannelUrl = "https://raw.githubusercontent.com/Civ13/Civ13/master/tools/opendream-client/native-launcher-channel.json";
    public static readonly string[] Required = ["Sign-In.cmd", "Play-Nomads.cmd", "Play-TDM.cmd", "Connect.ps1",
        "dotnet/dotnet.exe", "RobustToolbox/bin/ClientAuth/Robust.Client.dll", "Content.Client.zip"];
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
    public static async Task<Channel> ClientChannel(ITransport transport, string root, string bundled) {
        string json;
        try { json = await transport.Text(ClientChannelUrl); }
        catch (Exception e) when (e is HttpRequestException or IOException or TaskCanceledException) {
            Console.WriteLine("Update check unavailable. Using the last verified or bundled client.");
            var cache = Path.Combine(root, "last-channel.json");
            json = File.Exists(cache) ? File.ReadAllText(cache) : bundled;
        }
        var channel = Channel.Read(json);
        channel.Validate();
        return channel;
    }
    public static async Task<string> InstallClient(Channel channel, string root, ITransport transport) {
        channel.Validate();
        var destination = Path.Combine(root, "OpenDream-" + channel.Sha256[..12].ToLowerInvariant());
        if (Directory.Exists(destination)) {
            var receipt = Channel.Read(File.ReadAllText(Path.Combine(destination, "install-receipt.json")));
            if (!receipt.Sha256.Equals(channel.Sha256, StringComparison.OrdinalIgnoreCase))
                throw new IOException("Existing client receipt does not match.");
            RequirePackage(destination);
        } else {
            var stage = Path.Combine(root, "setup-" + Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(stage);
            var archive = Path.Combine(stage, "client.zip");
            Console.WriteLine("Downloading the complete Civ13 client. This may take several minutes...");
            await transport.Download(channel.Url, archive);
            CheckHash(archive, channel.Sha256);
            var extracted = Path.Combine(stage, "extracted");
            Extract(archive, extracted);
            var package = Path.Combine(extracted, "Civ13-OpenDream-Windows");
            RequirePackage(package);
            AtomicText(Path.Combine(package, "install-receipt.json"), JsonSerializer.Serialize(channel));
            Directory.Move(package, destination);
            // Successful staging can be removed; failed staging is kept for recovery.
            Directory.Delete(stage, true);
        }
        AtomicText(Path.Combine(root, "last-channel.json"), JsonSerializer.Serialize(channel));
        return destination;
    }
    public static async Task<string> EnsureClient(Channel channel, string root, ITransport transport) {
        try { return await InstallClient(channel, root, transport); }
        catch (Exception e) when (e is HttpRequestException or IOException or InvalidDataException or TaskCanceledException) {
            var cache = Path.Combine(root, "last-channel.json");
            if (!File.Exists(cache)) throw;
            var previous = Channel.Read(File.ReadAllText(cache));
            previous.Validate();
            if (previous.Sha256.Equals(channel.Sha256, StringComparison.OrdinalIgnoreCase) ||
                !Directory.Exists(Path.Combine(root, "OpenDream-" + previous.Sha256[..12].ToLowerInvariant()))) throw;
            Console.WriteLine("Client update failed: " + e.Message + " Using the previous verified client.");
            return await InstallClient(previous, root, transport);
        }
    }
    private static void RequirePackage(string path) {
        foreach (var file in Required)
            if (!File.Exists(Path.Combine(path, file))) throw new InvalidDataException("Incomplete client package: " + file);
    }
    public static void Extract(string archive, string destination) {
        Directory.CreateDirectory(destination);
        var prefix = Path.GetFullPath(destination) + Path.DirectorySeparatorChar;
        using var zip = ZipFile.OpenRead(archive);
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        long size = 0;
        if (zip.Entries.Count > 10000) throw new InvalidDataException("Too many client archive entries.");
        foreach (var entry in zip.Entries) {
            var path = Path.GetFullPath(Path.Combine(destination, entry.FullName.Replace('/', Path.DirectorySeparatorChar)));
            size = checked(size + entry.Length);
            if (!path.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) || !seen.Add(path) ||
                size > 4L * 1024 * 1024 * 1024 || ((entry.ExternalAttributes >> 16) & 0xF000) == 0xA000 ||
                entry.FullName.Contains(':'))
                throw new InvalidDataException("Unsafe client archive entry.");
        }
        ZipFile.ExtractToDirectory(archive, destination);
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
}
