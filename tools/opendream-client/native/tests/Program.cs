using Civ13.Launcher;
using System.IO.Compression;
using System.Text.Json;
using System.Diagnostics;

var root = Path.Combine(Path.GetTempPath(), "civ13-native-launcher-tests-" + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(root);
var assertions = 0;
void Require(bool condition, string message) { assertions++; if (!condition) throw new Exception(message); }
void Reject(Action action, string message) {
    try { action(); } catch (Exception e) when (e is IOException or InvalidDataException or FormatException) { assertions++; return; }
    throw new Exception("Negative control accepted: " + message);
}
async Task RejectAsync(Func<Task> action, string message) {
    try { await action(); } catch (Exception e) when (e is IOException or InvalidDataException or FormatException) { assertions++; return; }
    throw new Exception("Negative control accepted: " + message);
}
try {
    var package = Path.Combine(root, "package", "Civ13-OpenDream-Windows");
    Directory.CreateDirectory(package);
    foreach (var name in Updater.Required) {
        var path = Path.Combine(package, name);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, "fixture never executed");
    }
    var archive = Path.Combine(root, "client.zip");
    ZipFile.CreateFromDirectory(Path.GetDirectoryName(package)!, archive);
    var channel = new Channel(1, "fixture", "https://github.com/Civ13/Civ13/releases/download/test/client.zip", Updater.Hash(archive));
    var transport = new MockTransport(archive, JsonSerializer.Serialize(channel));
    var install = Path.Combine(root, "install");
    using (Updater.Lock(install)) Reject(() => Updater.Lock(install).Dispose(), "concurrent update lock");
    using (Updater.Lock(install)) { assertions++; }
    var first = await Updater.InstallClient(channel, install, transport);
    Require(File.Exists(Path.Combine(first, "install-receipt.json")), "client receipt missing");
    Require(await Updater.InstallClient(channel, install, transport) == first && transport.Downloads == 1, "repeat client installation downloaded again");
    var settings = Path.Combine(install, "account-settings.json");
    File.WriteAllText(settings, "preserve me");
    transport.Offline = true;
    Require((await Updater.ClientChannel(transport, install, Civ13.Launcher.Program.BundledChannel())).Sha256 == channel.Sha256, "offline cache not used");
    Require(await Updater.InstallClient(channel, install, transport) == first, "offline installed client unavailable");
    transport.Offline = false;
    await RejectAsync(() => Updater.InstallClient(channel with { Sha256 = new string('0', 64) }, install, transport), "client hash failure");
    Require(File.Exists(Path.Combine(first, "Sign-In.cmd")) && File.ReadAllText(settings) == "preserve me", "failure altered old client/account settings");
    Require(await Updater.EnsureClient(channel with { Sha256 = new string('0', 64) }, install, transport) == first, "failed update did not fall back to installed client");
    transport.Offline = true;
    Require(await Updater.EnsureClient(channel with { Sha256 = new string('1', 64) }, install, transport) == first, "offline download did not fall back to installed client");
    transport.Offline = false;
    var before = File.ReadAllText(Path.Combine(install, "last-channel.json"));
    var hostile = channel with { Url = "https://example.com/client.zip" };
    transport.Manifest = JsonSerializer.Serialize(hostile);
    await RejectAsync(() => Updater.ClientChannel(transport, install, Civ13.Launcher.Program.BundledChannel()), "remote invalid origin must not use cache");
    Require(File.ReadAllText(Path.Combine(install, "last-channel.json")) == before, "invalid remote changed cache");
    foreach (var url in new[] { "http://github.com/Civ13/Civ13/releases/download/test/a.exe", "https://github.com/Other/Repo/releases/download/test/a.exe", "https://github.com:444/Civ13/Civ13/releases/download/test/a.exe", "https://github.com/Civ13/Civ13/releases/download/test/a.exe?extra=yes" })
        Reject(() => (channel with { Url = url }).Validate(), "origin restriction " + url);
    var unsafeArchive = Path.Combine(root, "unsafe.zip");
    using (var zip = ZipFile.Open(unsafeArchive, ZipArchiveMode.Create)) {
        using var writer = new StreamWriter(zip.CreateEntry("../escape.txt").Open()); writer.Write("escape");
    }
    Reject(() => Updater.Extract(unsafeArchive, Path.Combine(root, "unsafe")), "archive traversal");
    Require(!File.Exists(Path.Combine(root, "escape.txt")), "archive escaped staging");
    var duplicateArchive = Path.Combine(root, "duplicate.zip");
    using (var zip = ZipFile.Open(duplicateArchive, ZipArchiveMode.Create)) { zip.CreateEntry("same"); zip.CreateEntry("SAME"); }
    Reject(() => Updater.Extract(duplicateArchive, Path.Combine(root, "duplicate")), "case duplicate archive");
    var exeChannel = channel with { Version = "1.0.1", Url = "https://github.com/Civ13/Civ13/releases/download/test/Civ13.exe" };
    var validated = false;
    var staged = await Updater.StageLauncher(exeChannel, new Version(1, 0, 0), install, transport,
        (path, version) => { validated = File.Exists(path) && version == "1.0.1"; });
    Require(staged is not null && validated && Updater.Hash(staged) == channel.Sha256, "successful mock launcher update not verified");
    var downloads = transport.Downloads;
    Require(await Updater.StageLauncher(exeChannel, new Version(1, 0, 1), install, transport) is null && transport.Downloads == downloads, "same-version update downloaded");
    Require(await Updater.StageLauncher(exeChannel, new Version(2, 0, 0), install, transport) is null, "downgrade accepted");
    validated = false;
    await RejectAsync(() => Updater.StageLauncher(exeChannel with { Sha256 = new string('0', 64) }, new Version(1, 0, 0), install, transport,
        (_, _) => validated = true), "launcher hash failure");
    Require(!validated, "unverified executable reached validation");
    Reject(() => Updater.ValidateExecutable(archive, "1.0.1"), "non-EXE update");
    transport.Offline = true;
    await RejectAsync(() => Updater.StageLauncher(exeChannel, new Version(1, 0, 0), install, transport), "offline launcher download");
    Require(File.Exists(Path.Combine(first, "Sign-In.cmd")), "offline update lost client");
    File.WriteAllText(Path.Combine(package, "Sign-In.cmd"), "second fixture never executed");
    var secondArchive = Path.Combine(root, "second-client.zip");
    ZipFile.CreateFromDirectory(Path.GetDirectoryName(package)!, secondArchive);
    var secondChannel = channel with { Sha256 = Updater.Hash(secondArchive), Version = "second fixture" };
    var second = await Updater.InstallClient(secondChannel, install, new MockTransport(secondArchive, JsonSerializer.Serialize(secondChannel)));
    Require(second != first && File.ReadAllText(Path.Combine(first, "Sign-In.cmd")) == "fixture never executed", "side-by-side install changed previous client");
    Require(File.ReadAllText(settings) == "preserve me", "new version changed account settings");
    // Optional actual self-contained binary closes the packaging boundary without launching a game.
    if (args.Length == 1) {
        var exe = Path.GetFullPath(args[0]);
        Updater.ValidateExecutable(exe, "1.0.0"); assertions++;
        var target = Path.Combine(root, "Civ13.exe");
        File.Copy(exe, target);
        Updater.ReplaceLauncher(exe, target, Updater.Hash(exe), "1.0.0");
        Require(Updater.Hash(target) == Updater.Hash(exe) && File.Exists(target + ".previous"), "actual atomic executable replacement/backup failed");
        Reject(() => Updater.ReplaceLauncher(exe, target, new string('0', 64), "1.0.0"), "actual replacement hash rejection");
        Require(Updater.Hash(target) == Updater.Hash(exe), "rejected replacement changed executable");
        File.WriteAllText(target + ".previous", "before parent exit");
        var waitStart = new ProcessStartInfo("C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe") {
            UseShellExecute = false, CreateNoWindow = true
        };
        foreach (var arg in new[] { "-NoProfile", "-NonInteractive", "-Command", "Start-Sleep -Seconds 3" }) waitStart.ArgumentList.Add(arg);
        using var parent = Process.Start(waitStart) ?? throw new Exception("Test parent failed to start");
        var helperPath = Path.Combine(root, "UpdateHelper.exe");
        File.Copy(exe, helperPath);
        var helperStart = new ProcessStartInfo(helperPath) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var arg in new[] { "--apply-update", parent.Id.ToString(), parent.StartTime.ToUniversalTime().Ticks.ToString(), exe, target, Updater.Hash(exe), "1.0.0", install, "--self-check" }) helperStart.ArgumentList.Add(arg);
        using var helper = Process.Start(helperStart) ?? throw new Exception("Actual update helper failed to start");
        Thread.Sleep(200);
        Require(!parent.HasExited && File.ReadAllText(target + ".previous") == "before parent exit", "helper replaced launcher before parent exit");
        Require(helper.WaitForExit(30000), "actual update helper timed out");
        Require(helper.ExitCode == 0, "actual update helper failed: " + helper.StandardError.ReadToEnd());
        Require(Updater.Hash(target) == Updater.Hash(exe) && Updater.Hash(target + ".previous") == Updater.Hash(exe), "post-exit replacement/backup failed");
        Require(File.ReadAllText(Path.Combine(install, "native-update-result.json")).Contains("\"success\":true"), "post-exit update receipt missing");
    }
    Console.WriteLine($"PASS: {assertions} native launcher assertions; isolated mock transport, no accounts or game processes.");
} catch (Exception e) {
    Console.Error.WriteLine("FAIL: " + e);
    return 1;
} finally {
    // Task-created exact temporary root only.
    Directory.Delete(root, true);
}
return 0;

sealed class MockTransport(string archive, string manifest) : ITransport {
    public bool Offline { get; set; }
    public string Manifest { get; set; } = manifest;
    public int Downloads { get; private set; }
    public Task<string> Text(string url) => Offline ? Task.FromException<string>(new IOException("offline fixture")) : Task.FromResult(Manifest);
    public Task Download(string url, string destination) {
        if (Offline) throw new IOException("offline fixture");
        Downloads++;
        File.Copy(archive, destination);
        return Task.CompletedTask;
    }
}
