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
    const string privateFailure = "PRIVATE https://name:password@example.test/private?token=secret\r\nINJECTED";
    var reset = new System.Net.Sockets.SocketException(10054);
    var tls = new System.Security.Authentication.AuthenticationException(privateFailure, reset);
    var requestFailure = new HttpRequestException(HttpRequestError.SecureConnectionError, privateFailure, tls);
    var safeTls = Updater.DescribeFailure(requestFailure);
    Require(safeTls.Contains("SecureConnectionError") && safeTls.Contains("AuthenticationException"), "TLS diagnostic lost nested framework classification");
    Require(safeTls.Contains("SocketException") && safeTls.Contains("native=10054/0x00002746"), "TLS diagnostic lost actual nested socket reset code");
    Require(safeTls.Contains("HRESULT=0x"), "TLS diagnostic omitted numeric HRESULT");
    Require(!safeTls.Contains("PRIVATE") && !safeTls.Contains("password") && !safeTls.Contains("token=") && !safeTls.Contains("example.test"), "TLS diagnostic leaked exception message or URL credentials");
    Require(safeTls.All(character => character is >= ' ' and <= '~'), "TLS diagnostic included injected line breaks or non-printable content");
    var certificateFailure = new System.Security.Authentication.AuthenticationException(privateFailure,
        new System.ComponentModel.Win32Exception(unchecked((int)0x80090325)));
    var safeCertificate = Updater.DescribeFailure(certificateFailure);
    Require(safeCertificate.Contains("Win32Exception") && safeCertificate.Contains("0x80090325"), "certificate failure diagnostic lost native code");
    Require(!safeCertificate.Contains("PRIVATE") && !safeCertificate.Contains("password"), "certificate diagnostic leaked untrusted error text");
    var responseFailure = new HttpRequestException(HttpRequestError.HttpProtocolError, privateFailure, null, System.Net.HttpStatusCode.ServiceUnavailable);
    Require(Updater.DescribeFailure(responseFailure).Contains("HTTP=503"), "HTTP response diagnostic lost actual status code");
    Exception deepFailure = requestFailure;
    for (var index = 0; index < 100; index++) deepFailure = new IOException(privateFailure, deepFailure);
    var safeDeep = Updater.DescribeFailure(deepFailure);
    Require(safeDeep.Length <= 512 && safeDeep.EndsWith("..."), "deep exception chain was not bounded and marked incomplete");
    Require(!safeDeep.Contains("PRIVATE") && !safeDeep.Contains("token="), "deep exception chain leaked message content");
    Require(Updater.DescribeFailure(new Exception(privateFailure)).StartsWith("Exception HRESULT=0x"), "unknown exception diagnostic was not safely classified");
    Reject(() => ServerCatalog.OpenDreamPort("Nomads", null), "unconfigured OpenDream service");
    Require(ServerCatalog.OpenDreamPort("Nomads", "18462") == 18462, "explicit OpenDream operator port changed");
    var expectedLinks = new[] { "https://civ13.com/", "https://civ13.github.io/civ13-wiki/", "https://civ13.com/discord", "https://github.com/civ13/civ13/" };
    Require(CommunityLinks.Items.Values.Select(link => link.Url).SequenceEqual(expectedLinks), "official community destinations changed");
    foreach (var item in CommunityLinks.Items) {
        ProcessStartInfo? opened = null;
        Require(CommunityLinks.TryOpen(item.Key, start => opened = start, TextWriter.Null), "resource choice was not handled");
        Require(opened?.FileName == item.Value.Url && opened.UseShellExecute, "resource did not dispatch to default browser");
    }
    Require(!CommunityLinks.TryOpen("2", _ => throw new Exception("Play opened browser"), TextWriter.Null), "resource handler consumed Play");
    using var linkError = new StringWriter();
    CommunityLinks.TryOpen("7", _ => throw new System.ComponentModel.Win32Exception("No browser"), linkError);
    Require(linkError.ToString().Contains("Could not open Discord") && linkError.ToString().Contains(expectedLinks[2]), "browser failure omitted usable destination");
    var localHost = new LocalHostReceipt(1, 18459, 123, 456, @"C:\verified\DreamDaemon.exe",
        @"D:\isolated\civ13.dmb", new string('a', 64), new string('b', 40), "Gaia Nomads");
    LocalHostIdentity InspectLocal(int pid) => new(456, localHost.Daemon, "5.0.516.1681");
    ProcessStartInfo LocalStart(LocalHostReceipt receipt, Func<string?> userData, Func<int, LocalHostIdentity>? inspector = null,
        Func<string, string>? worldHash = null, Func<string, bool>? client = null) =>
        LocalDreamDaemon.Prepare(receipt, @"C:\verified", @"D:\isolated", inspector ?? InspectLocal,
            userData, worldHash ?? (_ => new string('a', 64)), client ?? (_ => true), strictDOutput: true);
    var normalLocalStart = LocalDreamDaemon.Prepare(localHost, @"C:\verified", @"C:\isolated",
        InspectLocal, hash: _ => new string('a', 64), matchesClient: _ => true);
    Require(normalLocalStart.ArgumentList.Single() == "byond://127.0.0.1:18459", "normal BYOND cache policy blocked local dispatch");
    var consoleHost = localHost with { Daemon = @"C:\verified\dd.exe" };
    var consoleStart = LocalDreamDaemon.Prepare(consoleHost, @"C:\verified", @"D:\isolated",
        _ => new(456, consoleHost.Daemon, "5.0.516.1681"), hash: _ => new string('a', 64), matchesClient: _ => true);
    Require(consoleStart.ArgumentList.Single() == "byond://127.0.0.1:18459", "official console daemon rejected");
    Reject(() => LocalDreamDaemon.Prepare(consoleHost with { Daemon = @"C:\verified\other.exe" }, @"C:\verified", @"D:\isolated",
        _ => new(456, @"C:\verified\other.exe", "5.0.516.1681"), hash: _ => new string('a', 64)), "unrecognized daemon executable");
    var localStart = LocalStart(localHost, () => @"D:\BYOND-user");
    Require(localStart.ArgumentList.Single() == "byond://127.0.0.1:18459" && !localStart.UseShellExecute,
        "isolated DD endpoint escaped loopback or used URI association");
    Require(localStart.Environment["TEMP"] == @"D:\isolated" && localStart.Environment["TMP"] == @"D:\isolated" &&
        localStart.Environment["TMPDIR"] == @"D:\isolated",
        "isolated DD temporary output not on D");
    Reject(() => LocalStart(localHost, () => null), "unverified BYOND user cache");
    Reject(() => LocalStart(localHost, () => @"C:\BYOND-user"), "C BYOND user cache");
    Reject(() => LocalStart(localHost, () => @"D:\BYOND-user", _ => new(999, localHost.Daemon, "5.0.516.1681")), "reused host PID");
    Reject(() => LocalStart(localHost, () => @"D:\BYOND-user", _ => new(456, localHost.Daemon, "5.0.516.1669")), "wrong native host version");
    Reject(() => LocalStart(localHost, () => @"D:\BYOND-user", worldHash: _ => new string('0', 64)), "changed host world");
    Reject(() => LocalStart(localHost, () => @"D:\BYOND-user", client: _ => false), "missing BYOND client");
    Reject(() => LocalDreamDaemon.RequireDPath(@"C:\isolated"), "C launcher root");
    Reject(() => LocalStart(localHost with { Port = 0 }, () => @"D:\BYOND-user"), "invalid local port");
    var resolverCalls = 0;
    Task<System.Net.IPAddress[]> ResolveFixture(string name) {
        Require(name == "valzargaming.com", "connection resolved a different hostname");
        resolverCalls++;
        return Task.FromResult(new[] { System.Net.IPAddress.Parse("192.64.119.81"), System.Net.IPAddress.Parse(resolverCalls == 1 ? "72.218.249.221" : "192.0.2.2") });
    }
    var initialAddresses = await Connection.Resolve(ResolveFixture);
    foreach (var mode in new[] { "Nomads", "TDM" }) {
        var server = ServerCatalog.Select("ValZarGaming", mode);
        var native = ServerCatalog.NativeStart(server, root, initialAddresses.Single(), Civ13.Launcher.Program.RequiredByond(), _ => true);
        var expectedNativePort = mode == "Nomads" ? 1714 : 1715;
        Require(server.Engine == "BYOND" && server.Port == expectedNativePort, "public server engine/port mismatch");
        Require(native.FileName == Path.Combine(root, "dreamseeker.exe") && !native.UseShellExecute &&
            native.ArgumentList.SequenceEqual(new[] { $"byond://72.218.249.221:{expectedNativePort}" }), "public server did not dispatch exact native client URL");
        Reject(() => ServerCatalog.NativeStart(server with { Engine = "OpenDream" }, root, initialAddresses.Single(), Civ13.Launcher.Program.RequiredByond(), _ => true), "OpenDream substituted for DreamDaemon");
        Reject(() => ServerCatalog.NativeStart(server with { Port = 18459 }, root, initialAddresses.Single(), Civ13.Launcher.Program.RequiredByond(), _ => true), "isolated test port substituted for public server");
        Reject(() => ServerCatalog.NativeStart(server, root, initialAddresses.Single(), Civ13.Launcher.Program.RequiredByond(), _ => false), "wrong BYOND version");
        foreach (var endpoint in new[] { "192.64.119.81", "192.0.2.2", "valzargaming.com", "72.218.249.221;calc.exe" })
            Reject(() => ServerCatalog.NativeStart(server, root, endpoint, Civ13.Launcher.Program.RequiredByond(), _ => true), "unverified native endpoint");
    }
    Reject(() => ServerCatalog.Select("unknown", "Nomads"), "unknown public server");
    Reject(() => ServerCatalog.Select("ValZarGaming", "unknown"), "unknown public mode");
    await RejectAsync(() => Connection.Resolve(ResolveFixture), "changed unverified DNS endpoint");
    Require(resolverCalls == 2 && initialAddresses.SequenceEqual(new[] { "72.218.249.221" }), "connection cached DNS or retained excluded address");
    await RejectAsync(() => Connection.Resolve(_ => Task.FromResult(Array.Empty<System.Net.IPAddress>())), "empty DNS answer");
    await RejectAsync(() => Connection.Resolve(_ => Task.FromException<System.Net.IPAddress[]>(new System.Net.Sockets.SocketException())), "DNS failure");
    await RejectAsync(() => Connection.Resolve(_ => Task.FromException<System.Net.IPAddress[]>(new TimeoutException())), "DNS timeout");
    foreach (var file in new[] { "dotnet/dotnet.exe", "RobustToolbox/bin/ClientAuth/Robust.Client.dll", "Content.Client.zip" }) {
        var path = Path.Combine(root, file);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, "fixture never executed");
    }
    foreach (var mode in new[] { "Nomads", "TDM" }) {
        var start = Connection.Start(root, mode, initialAddresses.Single());
        var expectedPort = mode == "Nomads" ? 1715 : 1714;
        Require(start.ArgumentList.SequenceEqual(new[] { Path.Combine(root, "RobustToolbox", "bin", "ClientAuth", "Robust.Client.dll"), "--self-contained", "--mount-zip", Path.Combine(root, "Content.Client.zip"), "--connect", "--connect-address", $"udp://72.218.249.221:{expectedPort}", "+launchauth" }), "connection default routing or authentication changed");
        Require(start.FileName == Path.Combine(root, "dotnet", "dotnet.exe") && !start.UseShellExecute && start.WorkingDirectory == Path.Combine(root, "RobustToolbox", "bin", "ClientAuth"), "packaged runtime/working directory changed");
        Require(start.Environment["DOTNET_ROOT"] == Path.Combine(root, "dotnet") && start.Environment["ROBUST_MODULE_ROBUST_CLIENT_WEBVIEW"] == Path.Combine(root, "webview"), "packaged runtime environment lost");
        foreach (var port in new[] { "1", "18459", "65535" })
            Require(Connection.Start(root, mode, initialAddresses.Single(), port).ArgumentList.Contains($"udp://72.218.249.221:{port}"), "explicit port override lost");
        Require(!start.ArgumentList.Contains("Bypass") && !start.ArgumentList.Any(value => value.Contains("192.0.2.") || value.Contains("192.64.119.81")), "connection bypassed policy or used unverified/excluded address");
    }
    foreach (var invalid in new[] { "0", "65536", "-1", "abc", "1714;calc.exe", "" })
        Reject(() => Connection.Start(root, "Nomads", Connection.ApprovedEndpoint, invalid), "invalid port accepted");
    Reject(() => Connection.Start(Path.Combine(root, "missing-client"), "Nomads", Connection.ApprovedEndpoint), "missing client runtime accepted");
    await RejectAsync(() => Connection.Resolve(_ => Task.FromResult(new[] { System.Net.IPAddress.Parse("192.64.119.81") })), "excluded-only DNS answer");
    await RejectAsync(() => Connection.Resolve(_ => Task.FromResult(new[] { System.Net.IPAddress.Parse("72.218.249.221"), System.Net.IPAddress.Parse("192.0.2.3") })), "mixed unverified endpoint answer");
    Reject(() => Connection.Start(root, "Nomads", "192.64.119.81"), "excluded connection address");
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
    var officialRequirement = Civ13.Launcher.Program.RequiredByond();
    Require(officialRequirement.Version == "516.1681" && officialRequirement.Matches(5, 0, 516, 1681) && !officialRequirement.Matches(5, 0, 516, 1688), "BYOND requirement does not match exact game pin");
    Reject(() => (officialRequirement with { Url = "https://example.com/byond.exe" }).Validate(), "nonofficial BYOND origin");
    var byondFixture = Path.Combine(root, "byond-fixture.exe");
    File.WriteAllText(byondFixture, "fixture never executed");
    var byondRequirement = officialRequirement with { Sha256 = Updater.Hash(byondFixture) };
    var byondRoot = Path.Combine(root, "byond-install");
    Directory.CreateDirectory(byondRoot);
    var byondTransport = new MockTransport(byondFixture, "unused");
    var presentByond = new FakeByondDesktop { HasRequired = true, Bin = Path.Combine(root, "existing", "bin") };
    Require(await Byond.Ensure(byondRequirement, byondRoot, byondTransport, presentByond) == presentByond.Bin && byondTransport.Downloads == 0 && presentByond.Installs == 0, "present BYOND was reinstalled");
    var missingByond = new FakeByondDesktop();
    var installedByond = await Byond.Ensure(byondRequirement, byondRoot, byondTransport, missingByond);
    Require(missingByond.Installs == 1 && byondTransport.Downloads == 1 && File.Exists(Path.Combine(byondRoot, "byond-install.json")), "missing BYOND did not install/record exact version");
    Require(await Byond.Ensure(byondRequirement, byondRoot, byondTransport, missingByond) == installedByond && missingByond.Installs == 1 && byondTransport.Downloads == 1, "BYOND first-run setup is not idempotent");
    var wrongRoot = Path.Combine(root, "byond-wrong-version");
    var oldByond = Path.Combine(wrongRoot, "BYOND", "516.1681");
    Directory.CreateDirectory(oldByond);
    File.WriteAllText(Path.Combine(oldByond, "keep.txt"), "older version preserved");
    var wrongByond = new FakeByondDesktop { Bin = Path.Combine(oldByond, "bin") };
    await Byond.Ensure(byondRequirement, wrongRoot, byondTransport, wrongByond);
    Require(wrongByond.Bin != Path.Combine(oldByond, "bin") && File.ReadAllText(Path.Combine(oldByond, "keep.txt")) == "older version preserved", "wrong-version existing directory overwritten");
    var failedRoot = Path.Combine(root, "byond-failed");
    var failedByond = new FakeByondDesktop();
    byondTransport.Offline = true;
    await RejectAsync(() => Byond.Ensure(byondRequirement, failedRoot, byondTransport, failedByond), "BYOND failed download");
    Require(failedByond.Installs == 0 && !File.Exists(Path.Combine(failedRoot, "byond-install.json")), "failed BYOND download reached installer");
    byondTransport.Offline = false;
    byondTransport.InterruptAfterCopy = true;
    await RejectAsync(() => Byond.Ensure(byondRequirement, failedRoot, byondTransport, failedByond), "interrupted BYOND download");
    Require(Directory.GetFiles(Path.Combine(failedRoot, "BYOND", "installers"), "*.part").Length == 1 && failedByond.Installs == 0, "interrupted download was executed or lost diagnostics");
    byondTransport.InterruptAfterCopy = false;
    Require(await Byond.Ensure(byondRequirement, failedRoot, byondTransport, failedByond) == failedByond.Bin && failedByond.Installs == 1, "interrupted BYOND setup did not recover");
    failedByond = new FakeByondDesktop();
    failedRoot = Path.Combine(root, "byond-bad-hash");
    await RejectAsync(() => Byond.Ensure(byondRequirement with { Sha256 = new string('0', 64) }, failedRoot, byondTransport, failedByond), "BYOND hash failure");
    Require(failedByond.Installs == 0 && failedByond.Validations == 0, "unverified BYOND installer reached execution/validation");
    var declinedByond = new FakeByondDesktop { Confirm = false };
    var beforeDeclined = byondTransport.Downloads;
    await RejectAsync(() => Byond.Ensure(byondRequirement, Path.Combine(root, "byond-declined"), byondTransport, declinedByond), "BYOND user decline");
    Require(byondTransport.Downloads == beforeDeclined && declinedByond.Installs == 0, "declining BYOND installed or downloaded anything");
    var cancelledByond = new FakeByondDesktop { ExitCode = 1 };
    await RejectAsync(() => Byond.Ensure(byondRequirement, Path.Combine(root, "byond-cancelled"), byondTransport, cancelledByond), "BYOND installer cancellation");
    Require(!File.Exists(Path.Combine(root, "byond-cancelled", "byond-install.json")), "cancelled BYOND setup recorded success");
    var wrongInstalledByond = new FakeByondDesktop { InstallReportsWrongVersion = true };
    await RejectAsync(() => Byond.Ensure(byondRequirement, Path.Combine(root, "byond-wrong-installed"), byondTransport, wrongInstalledByond), "installer returned success with wrong installed version");
    Require(!File.Exists(Path.Combine(root, "byond-wrong-installed", "byond-install.json")), "wrong installed BYOND recorded success");
    // Optional actual self-contained binary closes the packaging boundary without launching a game.
    if (args.Length is 1 or 2) {
        var exe = Path.GetFullPath(args[0]);
        var executableVersion = args.Length == 2 ? args[1] : "1.0.0";
        Updater.ValidateExecutable(exe, executableVersion); assertions++;
        var actualChannel = exeChannel with { Version = executableVersion, Sha256 = Updater.Hash(exe) };
        var actualTransport = new MockTransport(exe, JsonSerializer.Serialize(actualChannel));
        var actualStage = await Updater.StageLauncher(actualChannel, new Version(0, 0, 0), install, actualTransport);
        Require(actualStage is not null && Updater.Hash(actualStage) == Updater.Hash(exe), "actual EXE download/version/hash stage failed");
        actualTransport.InterruptAfterCopy = true;
        await RejectAsync(() => Updater.StageLauncher(actualChannel, new Version(0, 0, 0), install, actualTransport), "actual EXE interrupted download");
        actualTransport.InterruptAfterCopy = false;
        Require(await Updater.StageLauncher(actualChannel, Version.Parse(executableVersion), install, actualTransport) is null, "actual EXE no-update failed");
        var target = Path.Combine(root, "Civ13.exe");
        File.Copy(exe, target);
        Updater.ReplaceLauncher(exe, target, Updater.Hash(exe), executableVersion);
        Require(Updater.Hash(target) == Updater.Hash(exe) && File.Exists(target + ".previous"), "actual atomic executable replacement/backup failed");
        Reject(() => Updater.ReplaceLauncher(exe, target, new string('0', 64), executableVersion), "actual replacement hash rejection");
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
        foreach (var arg in new[] { "--apply-update", parent.Id.ToString(), parent.StartTime.ToUniversalTime().Ticks.ToString(), exe, target, Updater.Hash(exe), executableVersion, install, "--self-check" }) helperStart.ArgumentList.Add(arg);
        using var helper = Process.Start(helperStart) ?? throw new Exception("Actual update helper failed to start");
        Thread.Sleep(200);
        Require(!parent.HasExited && File.ReadAllText(target + ".previous") == "before parent exit", "helper replaced launcher before parent exit");
        Require(helper.WaitForExit(30000), "actual update helper timed out");
        Require(helper.ExitCode == 0, "actual update helper failed: " + helper.StandardError.ReadToEnd());
        Require(Updater.Hash(target) == Updater.Hash(exe) && Updater.Hash(target + ".previous") == Updater.Hash(exe), "post-exit replacement/backup failed");
        Require(File.ReadAllText(Path.Combine(install, "native-update-result.json")).Contains("\"success\":true"), "post-exit update receipt missing");
        foreach (var failStartup in new[] { true, false }) {
            File.WriteAllText(target, "previous controlled launcher bytes");
            var previousHash = Updater.Hash(target);
            var restarted = false;
            Reject(() => Updater.ApplyVerifiedUpdate(exe, target, Updater.Hash(exe), executableVersion, install,
                _ => { if (failStartup) throw new IOException("controlled startup failure"); },
                _ => { restarted = true; throw new IOException("controlled relaunch failure"); }), "failed update rollback");
            Require(Updater.Hash(target) == previousHash && Updater.Hash(target + ".failed") == Updater.Hash(exe), "failed startup/relaunch did not restore previous EXE");
            Require(restarted != failStartup && File.ReadAllText(settings) == "preserve me" && Directory.Exists(first), "failure changed data/install or restarted failed startup");
            Require(File.ReadAllText(Path.Combine(install, "native-update-result.json")).Contains("\"rolledBack\":true"), "rollback receipt missing");
        }
        File.Copy(exe, target, true);
        using (var lockedTarget = new FileStream(target, FileMode.Open, FileAccess.Read, FileShare.Read)) {
            Reject(() => Updater.ApplyVerifiedUpdate(exe, target, Updater.Hash(exe), executableVersion, install, _ => { }, _ => { }), "locked target install failure");
            Require(Updater.Hash(target) == Updater.Hash(exe), "locked target failure altered executable");
        }
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
    public bool InterruptAfterCopy { get; set; }
    public string Manifest { get; set; } = manifest;
    public int Downloads { get; private set; }
    public Task<string> Text(string url) => Offline ? Task.FromException<string>(new IOException("offline fixture")) : Task.FromResult(Manifest);
    public Task Download(string url, string destination) {
        if (Offline) throw new IOException("offline fixture");
        Downloads++;
        File.Copy(archive, destination);
        if (InterruptAfterCopy) throw new IOException("interrupted fixture download");
        return Task.CompletedTask;
    }
}

sealed class FakeByondDesktop : IByondDesktop {
    public bool HasRequired { get; set; }
    public string Bin { get; set; } = "missing";
    public bool Confirm { get; set; } = true;
    public int ExitCode { get; set; }
    public bool InstallReportsWrongVersion { get; set; }
    public int Installs { get; private set; }
    public int Validations { get; private set; }
    public IEnumerable<string> Candidates(string root, ByondRequirement requirement) => [Bin];
    public bool Matches(string path, ByondRequirement requirement) => HasRequired && path == Bin;
    public string? ChooseExisting() => null;
    public bool ConfirmInstall(ByondRequirement requirement) => Confirm;
    public void ValidateInstaller(string installer, ByondRequirement requirement) { Validations++; }
    public Task<int> Install(string installer, string destination) {
        Installs++;
        Bin = Path.Combine(destination, "bin");
        HasRequired = ExitCode == 0 && !InstallReportsWrongVersion;
        return Task.FromResult(ExitCode);
    }
}
