using System.Diagnostics;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Civ13.Launcher;

public sealed record LocalHostReceipt(int Schema, int Port, int Pid, long StartTimeUtcTicks,
    string Daemon, string World, string WorldSha256, string SourceCommit, string Map);
public sealed record LocalHostIdentity(long StartTimeUtcTicks, string Executable, string Version);

public static class LocalDreamDaemon {
    public static string RequireDPath(string path) {
        if (!Path.IsPathFullyQualified(path) || !Path.GetFullPath(path).StartsWith("D:\\", StringComparison.OrdinalIgnoreCase))
            throw new IOException("The isolated test requires an absolute D: path.");
        var full = Path.GetFullPath(path);
        if (File.Exists(full) && (File.GetAttributes(full) & FileAttributes.ReparsePoint) != 0)
            throw new IOException("Linked test files are not allowed.");
        for (var item = new DirectoryInfo(full); item != null; item = item.Parent)
            if (item.Exists && (item.Attributes & FileAttributes.ReparsePoint) != 0)
                throw new IOException("Linked test paths are not allowed.");
        return full;
    }
    public static LocalHostReceipt Read(string path) {
        path = RequireDPath(path);
        var file = new FileInfo(path);
        if (!file.Exists || file.Length > 16384 || (file.Attributes & FileAttributes.ReparsePoint) != 0)
            throw new IOException("Invalid local host receipt.");
        using var document = JsonDocument.Parse(File.ReadAllText(path));
        if (document.RootElement.ValueKind != JsonValueKind.Object ||
            document.RootElement.EnumerateObject().Select(p => p.Name).Distinct(StringComparer.OrdinalIgnoreCase).Count() != document.RootElement.EnumerateObject().Count())
            throw new IOException("Invalid or duplicate local host receipt fields.");
        var receipt = JsonSerializer.Deserialize<LocalHostReceipt>(document.RootElement,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? throw new IOException("Local host receipt missing.");
        if (receipt.Schema != 1 || receipt.Port is < 1024 or > 65535 || receipt.Pid <= 0 || receipt.StartTimeUtcTicks <= 0 ||
            !Regex.IsMatch(receipt.SourceCommit ?? "", "^[0-9a-f]{40}$") ||
            !Regex.IsMatch(receipt.WorldSha256 ?? "", "^[0-9a-f]{64}$") || string.IsNullOrWhiteSpace(receipt.Map))
            throw new IOException("Invalid local host identity/source/map binding.");
        return receipt;
    }
    public static ProcessStartInfo Prepare(LocalHostReceipt receipt, string byondBin, string root,
        Func<int, LocalHostIdentity>? inspectHost = null, Func<string?>? inspectUserData = null,
        Func<string, string>? hash = null, Func<string, bool>? matchesClient = null) {
        if (receipt.Schema != 1 || receipt.Port is < 1024 or > 65535 || receipt.Pid <= 0 || receipt.StartTimeUtcTicks <= 0 ||
            !Regex.IsMatch(receipt.SourceCommit ?? "", "^[0-9a-f]{40}$") ||
            !Regex.IsMatch(receipt.WorldSha256 ?? "", "^[0-9a-f]{64}$") || string.IsNullOrWhiteSpace(receipt.Map))
            throw new IOException("Invalid local host identity/source/map binding.");
        root = RequireDPath(root);
        var world = RequireDPath(receipt.World);
        var host = (inspectHost ?? InspectHost)(receipt.Pid);
        if (host.StartTimeUtcTicks != receipt.StartTimeUtcTicks ||
            !string.Equals(Path.GetFullPath(host.Executable), Path.GetFullPath(receipt.Daemon), StringComparison.OrdinalIgnoreCase) ||
            host.Version != "5.0.516.1681" || !Path.GetFileName(host.Executable).Equals("DreamDaemon.exe", StringComparison.OrdinalIgnoreCase) ||
            (hash ?? Updater.Hash)(world) != receipt.WorldSha256)
            throw new IOException("Local DreamDaemon process identity or world file hash changed. Ask the host owner for a fresh receipt.");
        if (!(matchesClient ?? MatchesClient)(byondBin))
            throw new IOException("Verified BYOND 516.1681 client is unavailable.");
        // No proven per-process BYOND user-directory override is available yet.
        // Do not equate a receipt assertion, working directory or TEMP with its real cache location.
        var userData = (inspectUserData ?? (() => null))();
        if (userData == null)
            throw new IOException("BYOND user-data location is unverified. In BYOND Pager, open File > Preferences > Advanced and verify its user-data folder is on D:. A read-only configuration adapter must verify that setting before this test can launch; no account/data is copied automatically.");
        RequireDPath(userData);
        var start = new ProcessStartInfo(Path.Combine(Path.GetFullPath(byondBin), "dreamseeker.exe")) {
            UseShellExecute = false, WorkingDirectory = root
        };
        start.ArgumentList.Add("byond://127.0.0.1:" + receipt.Port);
        start.Environment["TEMP"] = root;
        start.Environment["TMP"] = root;
        start.Environment["TMPDIR"] = root;
        return start;
    }
    private static bool MatchesClient(string bin) {
        if (!OperatingSystem.IsWindows()) return false;
        return new WindowsByondDesktop().Matches(bin, Program.RequiredByond());
    }
    private static LocalHostIdentity InspectHost(int pid) {
        try {
            using var process = Process.GetProcessById(pid);
            var executable = process.MainModule?.FileName ?? throw new IOException("Host executable unavailable.");
            return new(process.StartTime.ToUniversalTime().Ticks, executable,
                FileVersionInfo.GetVersionInfo(executable).FileVersion ?? "");
        } catch (Exception e) when (e is ArgumentException or System.ComponentModel.Win32Exception or InvalidOperationException) {
            throw new IOException("Local host identity cannot be verified.", e);
        }
    }
}
