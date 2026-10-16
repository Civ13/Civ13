using System.Diagnostics;
using System.Runtime.Versioning;
using System.Text.Json;
using Microsoft.Win32;

namespace Civ13.Launcher;

public sealed record ByondRequirement(int Schema, string Version, string Url, string Sha256) {
    public static ByondRequirement Read(string json) {
        var requirement = JsonSerializer.Deserialize<ByondRequirement>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? throw new InvalidDataException("BYOND requirement missing.");
        requirement.Validate();
        return requirement;
    }
    public void Validate() {
        if (Schema != 1 || !System.Version.TryParse(Version, out var version) || version.Build != -1 ||
            version.Major <= 0 || version.Minor <= 0 || Sha256 is null || Sha256.Length != 64 || !Sha256.All(Uri.IsHexDigit) ||
            Url != $"https://www.byond.com/download/build/{version.Major}/{Version}_byond.exe")
            throw new InvalidDataException("Invalid pinned official BYOND requirement.");
    }
    public bool Matches(int major, int minor, int build, int revision) {
        var expected = System.Version.Parse(Version);
        return major == 5 && minor == 0 && build == expected.Major && revision == expected.Minor;
    }
}

public interface IByondDesktop {
    IEnumerable<string> Candidates(string root, ByondRequirement requirement);
    bool Matches(string path, ByondRequirement requirement);
    string? ChooseExisting();
    bool ConfirmInstall(ByondRequirement requirement);
    void ValidateInstaller(string installer, ByondRequirement requirement);
    Task<int> Install(string installer, string destination);
}

public static class Byond {
    public static async Task<string> Ensure(ByondRequirement requirement, string root, ITransport transport, IByondDesktop desktop) {
        requirement.Validate();
        var found = desktop.Candidates(root, requirement).FirstOrDefault(path => desktop.Matches(path, requirement));
        if (found is not null) return found;
        var chosen = desktop.ChooseExisting();
        if (!string.IsNullOrWhiteSpace(chosen)) {
            chosen = Path.GetFullPath(chosen);
            if (File.Exists(chosen)) chosen = Path.GetDirectoryName(chosen)!;
            if (desktop.Matches(chosen, requirement)) return chosen;
            if (desktop.Matches(Path.Combine(chosen, "bin"), requirement)) return Path.Combine(chosen, "bin");
            throw new IOException("That folder does not contain the required BYOND " + requirement.Version + ".");
        }
        if (!desktop.ConfirmInstall(requirement)) throw new IOException("BYOND setup cancelled. Existing installations are unchanged.");
        var installers = Path.Combine(root, "BYOND", "installers");
        Directory.CreateDirectory(installers);
        var installer = Path.Combine(installers, requirement.Version + "-" + requirement.Sha256[..12] + ".exe");
        if (File.Exists(installer) && !Updater.Hash(installer).Equals(requirement.Sha256, StringComparison.OrdinalIgnoreCase))
            File.Move(installer, installer + ".bad-" + Guid.NewGuid().ToString("N"));
        if (!File.Exists(installer)) {
            var partial = installer + "." + Guid.NewGuid().ToString("N") + ".part";
            await transport.Download(requirement.Url, partial);
            Updater.CheckHash(partial, requirement.Sha256);
            desktop.ValidateInstaller(partial, requirement);
            File.Move(partial, installer);
        }
        Updater.CheckHash(installer, requirement.Sha256);
        desktop.ValidateInstaller(installer, requirement);
        var destination = Path.Combine(root, "BYOND", requirement.Version);
        // Never overwrite a pre-existing incomplete or wrong-version directory.
        if (Directory.Exists(destination)) destination += "-" + Guid.NewGuid().ToString("N");
        Console.WriteLine("Opening the official BYOND installer. Keep its suggested separate folder: " + destination);
        Console.WriteLine("Review its license and any Windows permission prompts. No silent install is used.");
        if (await desktop.Install(installer, destination) != 0) throw new IOException("BYOND installer failed or was cancelled. You can retry next launch.");
        var installed = Path.Combine(destination, "bin");
        if (!desktop.Matches(installed, requirement)) {
            installed = desktop.Candidates(root, requirement).FirstOrDefault(path => desktop.Matches(path, requirement))
                ?? throw new IOException("Installer finished, but required BYOND version was not found. Restart the launcher after setup completes.");
        }
        Updater.AtomicText(Path.Combine(root, "byond-install.json"), JsonSerializer.Serialize(new { version = requirement.Version, bin = installed, installerSha256 = requirement.Sha256 }));
        return installed;
    }
}

public sealed class ByondTransport : ITransport, IDisposable {
    private readonly HttpClient _http = new(new HttpClientHandler { AllowAutoRedirect = false }) { Timeout = TimeSpan.FromMinutes(2) };
    public Task<string> Text(string url) => throw new NotSupportedException();
    public async Task Download(string url, string destination) {
        using var timeout = new CancellationTokenSource(TimeSpan.FromMinutes(2));
        var uri = new Uri(url);
        for (var redirects = 0; redirects <= 3; redirects++) {
            if (uri.Scheme != "https" || !uri.IsDefaultPort || uri.UserInfo.Length != 0 ||
                (uri.Host != "www.byond.com" && uri.Host != "byond.com")) throw new IOException("BYOND download must stay on the official HTTPS site.");
            using var response = await _http.GetAsync(uri, HttpCompletionOption.ResponseHeadersRead, timeout.Token);
            if ((int)response.StatusCode is >= 300 and < 400) {
                var location = response.Headers.Location ?? throw new IOException("Missing BYOND download redirect.");
                uri = location.IsAbsoluteUri ? location : new Uri(uri, location);
                continue;
            }
            response.EnsureSuccessStatusCode();
            if (response.Content.Headers.ContentLength > 64 * 1024 * 1024) throw new IOException("BYOND installer exceeds download limit.");
            await using var input = await response.Content.ReadAsStreamAsync(timeout.Token);
            await using var output = new FileStream(destination, FileMode.CreateNew);
            var buffer = new byte[65536];
            long total = 0;
            int read;
            while ((read = await input.ReadAsync(buffer, timeout.Token)) != 0) {
                total += read;
                if (total > 64 * 1024 * 1024) throw new IOException("BYOND installer exceeds download limit.");
                await output.WriteAsync(buffer.AsMemory(0, read), timeout.Token);
            }
            await output.FlushAsync();
            output.Flush(true);
            return;
        }
        throw new IOException("Too many BYOND redirects.");
    }
    public void Dispose() => _http.Dispose();
}

[SupportedOSPlatform("windows")]
public sealed class WindowsByondDesktop : IByondDesktop {
    public IEnumerable<string> Candidates(string root, ByondRequirement requirement) {
        var candidates = new List<string> { Path.Combine(root, "BYOND", requirement.Version, "bin") };
        var receipt = Path.Combine(root, "byond-install.json");
        if (File.Exists(receipt)) {
            try {
                using var json = JsonDocument.Parse(File.ReadAllText(receipt));
                var bin = json.RootElement.GetProperty("bin").GetString();
                if (!string.IsNullOrWhiteSpace(bin)) candidates.Add(bin);
            } catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException or KeyNotFoundException or InvalidOperationException) { }
        }
        foreach (var hive in new[] { RegistryHive.LocalMachine, RegistryHive.CurrentUser })
            foreach (var view in new[] { RegistryView.Registry32, RegistryView.Registry64 }) {
                try {
                    using var registry = RegistryKey.OpenBaseKey(hive, view);
                    using var key = registry.OpenSubKey(@"Software\Dantom\BYOND");
                    if (key?.GetValue("installpath") is string path && !string.IsNullOrWhiteSpace(path)) candidates.Add(Path.Combine(path, "bin"));
                } catch (Exception e) when (e is UnauthorizedAccessException or System.Security.SecurityException or IOException) { }
            }
        foreach (var location in new[] { Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData) })
            if (!string.IsNullOrWhiteSpace(location)) candidates.Add(Path.Combine(location, "BYOND", "bin"));
        var explicitBin = Environment.GetEnvironmentVariable("BYOND_BIN");
        if (!string.IsNullOrWhiteSpace(explicitBin)) candidates.Add(explicitBin);
        return candidates.Distinct(StringComparer.OrdinalIgnoreCase);
    }
    public bool Matches(string path, ByondRequirement requirement) {
        foreach (var name in new[] { "byond.exe", "dreamseeker.exe" }) {
            var file = Path.Combine(path, name);
            try {
                if (!File.Exists(file)) return false;
                var info = FileVersionInfo.GetVersionInfo(file);
                if (!requirement.Matches(info.FileMajorPart, info.FileMinorPart, info.FileBuildPart, info.FilePrivatePart)) return false;
            } catch (Exception e) when (e is IOException or UnauthorizedAccessException or ArgumentException) { return false; }
        }
        return true;
    }
    public string? ChooseExisting() {
        Console.WriteLine("Required BYOND version was not found. If you already installed it elsewhere, enter that folder; otherwise press Enter to download it.");
        return Console.ReadLine();
    }
    public bool ConfirmInstall(ByondRequirement requirement) {
        Console.Write($"Download and open the official BYOND {requirement.Version} installer? [y/N]: ");
        return Console.ReadLine()?.Equals("y", StringComparison.OrdinalIgnoreCase) == true;
    }
    public void ValidateInstaller(string installer, ByondRequirement requirement) {
        var info = FileVersionInfo.GetVersionInfo(installer);
        if (!requirement.Matches(info.FileMajorPart, info.FileMinorPart, info.FileBuildPart, info.FilePrivatePart))
            throw new InvalidDataException("Official installer version differs from the required BYOND version.");
        var data = File.ReadAllBytes(installer);
        if (data.Length < 2 || data[0] != 'M' || data[1] != 'Z' || data.AsSpan().IndexOf("NullsoftInst"u8) < 0)
            throw new InvalidDataException("Pinned BYOND installer is not the expected NSIS executable.");
    }
    public async Task<int> Install(string installer, string destination) {
        // NSIS /D must be last and unquoted, even for paths with spaces. No /S or /NCRC.
        var start = new ProcessStartInfo(installer) { UseShellExecute = true, Arguments = "/D=" + Path.GetFullPath(destination) };
        using var process = Process.Start(start) ?? throw new IOException("BYOND installer did not start.");
        await process.WaitForExitAsync();
        return process.ExitCode;
    }
}
