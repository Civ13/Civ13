using Civ13.Launcher;
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
    using (var helpText = new StringWriter()) {
        var oldOutput = Console.Out;
        try {
            Console.SetOut(helpText);
            var helpExit = await Civ13.Launcher.Program.Main(["--help"]);
            Require(helpExit == 0, "help failed");
        } finally { Console.SetOut(oldOutput); }
        var help = helpText.ToString();
        Require(help.Contains("--registered-instances") && help.Contains("trusted D: root"), "help omitted the explicit operator view");
        Require(help.Contains("process state, ownership and readiness remain unknown") &&
            help.Contains("inspect the displayed status for freshness"), "help implied parsed registrations prove readiness");
        Require(help.Contains("launcher is optional for BYOND gameplay"), "help omitted the ordinary BYOND path");
        Require(help.Contains("--root") && help.Contains("--local-dreamdaemon") && help.Contains("--console"), "help omitted existing options");
        Require(!help.Contains("--server-port") && !help.Contains("OpenDream"), "help still offers the removed OpenDream path");
    }
    if (args.Length is 1 or 2 && args[0] == "--byond-only") {
        await ByondDetectionTests.Run(root, args.Length == 2 ? args[1] : null);
        return 0;
    }
    if (args.Length == 2 && args[0] == "--pacing-cache-child") return TopicPacingTests.Child(args[1], cached: true);
    if (args.Length == 2 && args[0] == "--pacing-child") return TopicPacingTests.Child(args[1]);
    if (args.SequenceEqual(new[] { "--probe-public" })) {
        var discovery = new ServerDiscovery();
        foreach (var provider in new[] { "Civ13.com", "ValZarGaming" }) {
            var snapshot = await discovery.Fetch(provider);
            Console.WriteLine(JsonSerializer.Serialize(new { provider, snapshot.Unverified, snapshot.PacingPaused, snapshot.Deferred,
                servers = snapshot.Servers.Select(server => new { server.Host, server.Port, server.Players,
                    server.Map, server.Mode, server.Epoch, server.RoundId, server.RoundDurationSeconds, server.CheckedAt }) }));
        }
        Console.WriteLine("Prejoin NOT attempted. Use the interactive J recheck after spacing only when the runtime owner confirms eligibility.");
        return 0;
    }
    if (args.SequenceEqual(new[] { "--hosting-only" })) {
        LocalHostingTests.Run(root);
        LocalBotTests.Run(root);
        return 0;
    }
    if (args.SequenceEqual(new[] { "--presence-only" })) {
        Console.WriteLine("Discord presence assertions: " + DiscordPresenceTests.Run(root));
        Console.WriteLine("Discord sign-in assertions: " + await DiscordSignInTests.Run(root));
        return 0;
    }
    if (args.SequenceEqual(new[] { "--discovery-only" })) {
        await CachedJoinTests.Run(root);
        await ServerDiscoveryTests.Run(root);
        await HostStatusTests.Run(root);
        await TopicPacingTests.Run(root);
        return 0;
    }
    assertions += await ByondDetectionTests.Run(root);
    assertions += await TransportRetryTests.Run(root);
    assertions += await CachedJoinTests.Run(root);
    assertions += await ServerDiscoveryTests.Run(root);
    assertions += await HostStatusTests.Run(root);
    assertions += await TopicPacingTests.Run(root);
    assertions += LocalHostingTests.Run(root);
    assertions += LocalBotTests.Run(root);
    assertions += DiscordPresenceTests.Run(root);
    assertions += await DiscordSignInTests.Run(root);
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
    using var menuOutput = new StringWriter();
    Civ13.Launcher.Program.WriteMainMenu(menuOutput);
    var menuText = menuOutput.ToString();
    Require(menuText.Contains("2: Civ13.com servers") &&
        menuText.Contains("3: ValZarGaming.com servers"), "public menu labels changed");
    Require(!menuText.Contains("OpenDream") && !menuText.Contains("9: "), "main menu still offers OpenDream");
    var menuPositions = Enumerable.Range(1, 8).Select(key => menuText.IndexOf(key + ": ", StringComparison.Ordinal)).ToArray();
    Require(menuPositions.All(position => position >= 0) &&
        menuPositions.SequenceEqual(menuPositions.Order()), "main menu did not render options in 1-8 visual order");
    Require(ServerCatalog.MenuServer("2") == "Civ13.com", "option 2 selected wrong provider");
    Require(ServerCatalog.MenuServer("3") == "ValZarGaming", "option 3 selected wrong provider");
    foreach (var key in new string?[] { null, "1", "4", "5", "6", "7", "8", "9", "unknown" })
        Require(ServerCatalog.MenuServer(key) is null, "nonserver menu key selected a public provider");
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
    LocalHostIdentity InspectLocal(int pid) => new(456, localHost.Daemon, "5.0.516.1688");
    ProcessStartInfo LocalStart(LocalHostReceipt receipt, Func<string?> userData, Func<int, LocalHostIdentity>? inspector = null,
        Func<string, string>? worldHash = null, Func<string, bool>? client = null) =>
        LocalDreamDaemon.Prepare(receipt, @"C:\verified", @"D:\isolated", inspector ?? InspectLocal,
            userData, worldHash ?? (_ => new string('a', 64)), client ?? (_ => true), strictDOutput: true);
    var normalLocalStart = LocalDreamDaemon.Prepare(localHost, @"C:\verified", @"C:\isolated",
        InspectLocal, hash: _ => new string('a', 64), matchesClient: _ => true);
    Require(normalLocalStart.ArgumentList.Single() == "byond://127.0.0.1:18459", "normal BYOND cache policy blocked local dispatch");
    var consoleHost = localHost with { Daemon = @"C:\verified\dd.exe" };
    var consoleStart = LocalDreamDaemon.Prepare(consoleHost, @"C:\verified", @"D:\isolated",
        _ => new(456, consoleHost.Daemon, "5.0.516.1688"), hash: _ => new string('a', 64), matchesClient: _ => true);
    Require(consoleStart.ArgumentList.Single() == "byond://127.0.0.1:18459", "official console daemon rejected");
    Reject(() => LocalDreamDaemon.Prepare(consoleHost with { Daemon = @"C:\verified\other.exe" }, @"C:\verified", @"D:\isolated",
        _ => new(456, @"C:\verified\other.exe", "5.0.516.1688"), hash: _ => new string('a', 64)), "unrecognized daemon executable");
    var localStart = LocalStart(localHost, () => @"D:\BYOND-user");
    Require(localStart.ArgumentList.Single() == "byond://127.0.0.1:18459" && !localStart.UseShellExecute,
        "isolated DD endpoint escaped loopback or used URI association");
    Require(localStart.Environment["TEMP"] == @"D:\isolated" && localStart.Environment["TMP"] == @"D:\isolated" &&
        localStart.Environment["TMPDIR"] == @"D:\isolated",
        "isolated DD temporary output not on D");
    Reject(() => LocalStart(localHost, () => null), "unverified BYOND user cache");
    Reject(() => LocalStart(localHost, () => @"C:\BYOND-user"), "C BYOND user cache");
    Reject(() => LocalStart(localHost, () => @"D:\BYOND-user", _ => new(999, localHost.Daemon, "5.0.516.1688")), "reused host PID");
    Reject(() => LocalStart(localHost, () => @"D:\BYOND-user", _ => new(456, localHost.Daemon, "5.0.516.1669")), "wrong native host version");
    foreach (var bad in new[] { "", "516.1688", "5.0.516", "5.0.516.1681", "5.0.516.1689", "5.0.516.1688 extra" }) {
        try {
            LocalStart(localHost, () => @"D:\BYOND-user", _ => new(456, localHost.Daemon, bad));
            throw new Exception("Incompatible local host metadata accepted");
        } catch (IOException error) {
            Require(error.Message.Contains("requires BYOND 516.1688") && error.Message.Contains("metadata"), "compatibility failure omitted required version or metadata context");
        }
    }
    Reject(() => LocalStart(localHost, () => @"D:\BYOND-user", worldHash: _ => new string('0', 64)), "changed host world");
    Reject(() => LocalStart(localHost, () => @"D:\BYOND-user", client: _ => false), "missing BYOND client");
    Reject(() => LocalDreamDaemon.RequireDPath(@"C:\isolated"), "C launcher root");
    Reject(() => LocalStart(localHost with { Port = 0 }, () => @"D:\BYOND-user"), "invalid local port");
    var resolverCalls = 0;
    Task<System.Net.IPAddress[]> ResolveFixture(string name) {
        Require(name == "play.valzargaming.com", "connection resolved a different hostname");
        resolverCalls++;
        return Task.FromResult(new[] { System.Net.IPAddress.Parse(resolverCalls == 1 ? "8.8.8.8" : "1.1.1.1") });
    }
    var initialEndpoint = await Connection.Resolve(ResolveFixture);
    var changedEndpoint = await Connection.Resolve(ResolveFixture);
    Require(resolverCalls == 2 && initialEndpoint.Address == "8.8.8.8" && changedEndpoint.Address == "1.1.1.1", "connection cached DNS or kept a permanent public-IP pin");
    await RejectAsync(() => Connection.Resolve(_ => Task.FromResult(Array.Empty<System.Net.IPAddress>())), "empty DNS answer");
    await RejectAsync(() => Connection.Resolve(_ => Task.FromException<System.Net.IPAddress[]>(new System.Net.Sockets.SocketException())), "DNS failure");
    await RejectAsync(() => Connection.Resolve(_ => Task.FromException<System.Net.IPAddress[]>(new TimeoutException())), "DNS timeout");
    await RejectAsync(() => Connection.Resolve(_ => Task.FromResult(new[] { System.Net.IPAddress.Loopback })), "loopback DNS answer");
    await RejectAsync(() => Connection.Resolve(_ => Task.FromResult(new[] { System.Net.IPAddress.Parse("8.8.8.8"), System.Net.IPAddress.Parse("192.0.2.3") })), "mixed public/reserved endpoint answer");
    // A plain fixture file stands in for the downloaded launcher bytes; it is never executed.
    var archive = Path.Combine(root, "launcher-fixture.bin");
    File.WriteAllText(archive, "fixture never executed");
    var channel = new Channel(1, "fixture", "https://github.com/Civ13/Civ13/releases/download/test/client.zip", Updater.Hash(archive));
    var transport = new MockTransport(archive, JsonSerializer.Serialize(channel));
    var install = Path.Combine(root, "install");
    using (Updater.Lock(install)) Reject(() => Updater.Lock(install).Dispose(), "concurrent update lock");
    using (Updater.Lock(install)) { assertions++; }
    var settings = Path.Combine(install, "account-settings.json");
    File.WriteAllText(settings, "preserve me");
    foreach (var url in new[] { "http://github.com/Civ13/Civ13/releases/download/test/a.exe", "https://github.com/Other/Repo/releases/download/test/a.exe", "https://github.com:444/Civ13/Civ13/releases/download/test/a.exe", "https://github.com/Civ13/Civ13/releases/download/test/a.exe?extra=yes" })
        Reject(() => (channel with { Url = url }).Validate(), "origin restriction " + url);
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
    var officialRequirement = Civ13.Launcher.Program.RequiredByond();
    Require(officialRequirement.Version == "516.1688" && officialRequirement.Matches(5, 0, 516, 1688) && !officialRequirement.Matches(5, 0, 516, 1681), "BYOND requirement does not match exact game pin");
    Reject(() => (officialRequirement with { Url = "https://example.com/byond.exe" }).Validate(), "nonofficial BYOND origin");
    Require(officialRequirement.MatchesPeVersion("5.0.516.1688"), "exact PE version rejected");
    foreach (var bad in new string?[] { null, "", "516.1688", "5.0.516", "5.0.516.1681", "5.0.516.1689", "5.0.516.1688 extra", " 5.0.516.1688", "5.0.516.01688" })
        Require(!officialRequirement.MatchesPeVersion(bad), "malformed or different PE metadata accepted");
    foreach (var bad in new[] { "", "516", "516.01688", " 516.1688", "516.1688.1", "65535.1688" })
        Reject(() => (officialRequirement with { Version = bad }).Validate(), "invalid requirement version");
    foreach (var bad in new[] { "", "null", "[]", "{}", "{\"schema\":1}", "{\"version\":516.1688}", "{\"version\":\"516.1688\",\"Version\":\"516.1681\"}" })
        Reject(() => ByondRequirement.Read(bad), "missing or malformed embedded metadata");
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
            Require(restarted != failStartup && File.ReadAllText(settings) == "preserve me", "failure changed data/install or restarted failed startup");
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
