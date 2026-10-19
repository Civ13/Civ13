using System.Diagnostics;
using System.Text.Json;
using Civ13.Launcher;

// This deliberately never invokes normal launcher startup or BYOND.
// Transport/staging use the hash-pinned 1.0.2 source; replacement uses its actual release EXE.
var root = Path.GetFullPath(args.Single());
Directory.CreateDirectory(root);
const string oldHash = "68c215f88791b8f31885f35d6bbbe307f5e4ca1527cf3de74a2a8a88ba4ade8f";
const string newHash = "2f0ffac265a1643056722039cb46d89ed49b1d156d3f8035f01b6f2be26ac349";
using var transport = new ReleaseTransport();
var manifest = Channel.Read(await transport.Text(Updater.LauncherChannelUrl));
manifest.Validate(true);
Require(manifest.Version == "1.0.3" && manifest.Sha256 == newHash &&
    manifest.Url == "https://github.com/Civ13/Civ13/releases/download/launcher-v1.0.3/Civ13.exe",
    "Live stable feed does not match the pinned 1.0.3 release; review the probe before rerunning.");
Console.WriteLine("PASS: exact 1.0.2 transport reads live stable feed 1.0.3.");
var target = Path.Combine(root, "Civ13.exe");
await transport.Download("https://github.com/Civ13/Civ13/releases/download/launcher-v1.0.2/Civ13.exe", target);
Updater.CheckHash(target, oldHash);
Updater.ValidateExecutable(target, "1.0.2");
using (var version = Start(target, "--version")) {
    Require(version.WaitForExit(30000) && version.ExitCode == 0, "Old release --version failed.");
    Require(JsonDocument.Parse(version.StandardOutput.ReadToEnd()).RootElement.GetProperty("version").GetString() == "1.0.2", "Old release reported a different version.");
}
Console.WriteLine("PASS: actual published 1.0.2 binary hash and version.");
var candidate = await Updater.StageLauncher(manifest, new Version(1, 0, 2, 0), root, transport)
    ?? throw new Exception("1.0.2 did not stage 1.0.3.");
Console.WriteLine("PASS: exact 1.0.2 updater detects, downloads, hashes and validates published 1.0.3.");
var helperPath = Path.Combine(root, "UpdateHelper.exe");
File.Copy(target, helperPath);
using var parent = Start("C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe",
    "-NoProfile", "-NonInteractive", "-Command", "Start-Sleep -Seconds 3");
using var helper = Start(helperPath, "--apply-update", parent.Id.ToString(),
    parent.StartTime.ToUniversalTime().Ticks.ToString(), candidate, target, newHash, "1.0.3", root, "--self-check");
Thread.Sleep(200);
Require(!parent.HasExited && Updater.Hash(target) == oldHash, "Helper replaced before parent exit.");
if (!helper.WaitForExit(60000)) {
    helper.Kill(true);
    throw new Exception("Actual 1.0.2 helper timed out.");
}
Require(helper.ExitCode == 0, "Actual 1.0.2 helper failed: " + helper.StandardError.ReadToEnd());
Updater.CheckHash(target, newHash);
Updater.CheckHash(target + ".previous", oldHash);
using var receipt = JsonDocument.Parse(File.ReadAllText(Path.Combine(root, "native-update-result.json")));
Require(receipt.RootElement.GetProperty("success").GetBoolean() &&
    receipt.RootElement.GetProperty("version").GetString() == "1.0.3" &&
    receipt.RootElement.GetProperty("sha256").GetString() == newHash, "Success receipt mismatch.");
using (var version = Start(target, "--version")) {
    Require(version.WaitForExit(30000) && version.ExitCode == 0, "New release --version failed.");
    Require(JsonDocument.Parse(version.StandardOutput.ReadToEnd()).RootElement.GetProperty("version").GetString() == "1.0.3", "New release reported a different version.");
}
Console.WriteLine("PASS: published 1.0.2 helper replaced with 1.0.3, preserved 1.0.2 backup, self-checked/restarted and wrote success receipt.");
Console.WriteLine("Scope: isolated Windows runner; no normal BYOND startup/account interaction; not proof of the user's network/filesystem environment.");

static void Require(bool value, string message) { if (!value) throw new Exception(message); }
static Process Start(string path, params string[] args) {
    var start = new ProcessStartInfo(path) { UseShellExecute = false, CreateNoWindow = true,
        RedirectStandardOutput = true, RedirectStandardError = true };
    foreach (var arg in args) start.ArgumentList.Add(arg);
    return Process.Start(start) ?? throw new Exception("Probe process did not start.");
}
