using System.Diagnostics;
using System.Reflection;
using System.Text.Json;

namespace Civ13.Launcher;

public static class Program {
    public static void WriteMainMenu(TextWriter output) {
        output.WriteLine(ServerCatalog.MainMenu);
        foreach (var link in CommunityLinks.Items)
            output.WriteLine($"{link.Key}: {link.Value.Label} - {link.Value.Url}");
        output.WriteLine(ServerCatalog.OpenDreamMenu);
    }

    public static string BundledChannel() {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("client-channel.json")
            ?? throw new InvalidOperationException("Bundled client manifest missing.");
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    }
    public static ByondRequirement RequiredByond() {
        using var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("byond.json")
            ?? throw new InvalidOperationException("Bundled BYOND requirement missing.");
        using var reader = new StreamReader(stream);
        return ByondRequirement.Read(reader.ReadToEnd());
    }
    public static async Task<int> Main(string[] args) {
        try {
            var version = Assembly.GetExecutingAssembly().GetName().Version!;
            if (args.SequenceEqual(["--version"])) {
                Console.WriteLine(JsonSerializer.Serialize(new { version = version.ToString(3), platform = "win-x64", selfContained = true }));
                return 0;
            }
            if (args.SequenceEqual(["--self-check"])) {
                Channel.Read(BundledChannel()).Validate();
                RequiredByond().Validate();
                Console.WriteLine("PASS: embedded client/BYOND manifests and native launcher entrypoint.");
                return 0;
            }
            if (!OperatingSystem.IsWindows() || !Environment.Is64BitOperatingSystem)
                throw new PlatformNotSupportedException("Civ13 requires Windows x64.");
            if (args.Length > 0 && args[0] == "--apply-update") return ApplyUpdate(args);
            string? explicitRoot = null;
            string? localReceipt = null;
            string? serverPort = null;
            for (var index = 0; index < args.Length; index++) {
                if (args[index] == "--root" && explicitRoot == null && index + 1 < args.Length)
                    explicitRoot = LocalDreamDaemon.RequirePath(args[++index]);
                else if (args[index] == "--local-dreamdaemon" && localReceipt == null && index + 1 < args.Length)
                    localReceipt = LocalDreamDaemon.RequirePath(args[++index]);
                else if (args[index] == "--server-port" && serverPort == null && index + 1 < args.Length) {
                    serverPort = args[++index];
                    Connection.Port("Nomads", serverPort);
                }
                else throw new ArgumentException("Supported options: --version, --self-check, --root <absolute folder>, --local-dreamdaemon <absolute host receipt>, --server-port <1-65535>.");
            }
            var root = explicitRoot ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Civ13");
            if (localReceipt != null) {
                if (serverPort != null) throw new IOException("Local DreamDaemon connections use the verified host receipt port; omit --server-port.");
                if (explicitRoot == null) throw new IOException("Local DreamDaemon testing requires an explicit --root.");
                var receipt = LocalDreamDaemon.Read(localReceipt);
                var desktop = new WindowsByondDesktop();
                string? bin = null;
                foreach (var candidate in desktop.Candidates(root, RequiredByond())) {
                    if (!desktop.Matches(candidate, RequiredByond())) continue;
                    bin = candidate;
                    break;
                }
                if (bin == null) throw new IOException("Existing verified BYOND 516.1681 client missing; this local path never installs it.");
                var start = LocalDreamDaemon.Prepare(receipt, bin, root);
                Directory.CreateDirectory(root);
                using var process = Process.Start(start) ?? throw new IOException("BYOND client did not start.");
                return 0;
            }
            if (explicitRoot != null) {
                Directory.CreateDirectory(root);
                Environment.SetEnvironmentVariable("TEMP", root);
                Environment.SetEnvironmentVariable("TMP", root);
                Environment.SetEnvironmentVariable("TMPDIR", root);
            }
            using var owner = Updater.Lock(root);
            using var transport = new ReleaseTransport(new HttpClientHandler { AllowAutoRedirect = false }, Console.WriteLine);
            Console.WriteLine("Civ13 Launcher " + version.ToString(3));
            Console.WriteLine("Checking for launcher updates (installed " + version.ToString(3) + ")...");
            var updateStage = "manifest check";
            try {
                var manifest = Channel.Read(await transport.Text(Updater.LauncherChannelUrl));
                manifest.Validate(true);
                var latest = Version.Parse(manifest.Version);
                Console.WriteLine("Latest stable launcher: " + latest + ".");
                if (latest <= version)
                    Console.WriteLine("This launcher is current or newer than the stable release.");
                else Console.WriteLine("Downloading and verifying launcher " + latest + "...");
                updateStage = "download and verification";
                var candidate = await Updater.StageLauncher(manifest, version, root, transport);
                if (candidate is not null) {
                    updateStage = "starting update helper";
                    StartUpdateHelper(candidate, manifest, root);
                    Console.WriteLine("Verified launcher update downloaded. Restarting after this launcher exits...");
                    return 0;
                }
            } catch (Exception e) when (e is HttpRequestException or IOException or InvalidDataException or OperationCanceledException or TimeoutException or JsonException or FormatException) {
                Console.WriteLine("Launcher update unavailable during " + updateStage + ": " + Updater.DescribeFailure(e));
            }
            using var byondTransport = new ByondTransport();
            var byond = await Byond.Ensure(RequiredByond(), root, byondTransport, new WindowsByondDesktop());
            Console.WriteLine("BYOND " + RequiredByond().Version + " available at " + byond);
            Console.WriteLine("Sign in to your BYOND account in the BYOND Pager before joining.");
            owner.Dispose();
            using var directories = new ServerDirectoryTransport();
            while (true) {
                WriteMainMenu(Console.Out);
                Console.Write("Choose a number: ");
                var choice = Console.ReadLine();
                if (choice is null or "4") return 0;
                if (CommunityLinks.TryOpen(choice, start => { using var browser = Process.Start(start); }, Console.Out)) continue;
                if (choice == "1") Process.Start(new ProcessStartInfo(Path.Combine(byond, "byond.exe")) { UseShellExecute = false, WorkingDirectory = byond });
                if (ServerCatalog.MenuServer(choice) is { } serverName) {
                    if (serverPort != null) {
                        Console.WriteLine("Public server selections use the live directory; omit --server-port.");
                        continue;
                    }
                    var desktop = new WindowsByondDesktop();
                    await ServerBrowser.Run(serverName, directories, Console.In, Console.Out, async server => {
                        var endpoint = await ServerCatalog.NativeEndpoint(server);
                        Console.WriteLine($"Connecting to {server.Name} using BYOND {RequiredByond().Version} on port {server.Port}.");
                        try {
                            using var game = Process.Start(ServerCatalog.NativeStart(server, byond, endpoint, RequiredByond(),
                                path => OperatingSystem.IsWindows() && desktop.Matches(path, RequiredByond())))
                                ?? throw new IOException("BYOND client did not start.");
                        } catch (System.ComponentModel.Win32Exception e) {
                            throw new IOException("BYOND client could not start.", e);
                        }
                    });
                }
                if (choice == ServerCatalog.OpenDreamMenuKey) {
                    try {
                        using var clientOwner = Updater.Lock(root);
                        var client = await Updater.ClientChannel(transport, root, BundledChannel());
                        var destination = await Updater.EnsureClient(client, root, transport);
                        Console.WriteLine("OpenDream - 1: Sign in   2: Operator Nomads target   3: Operator TDM target   4: Back");
                        Console.WriteLine("No public OpenDream game service is configured. Joining requires an operator's verified --server-port.");
                        var engineChoice = Console.ReadLine();
                        if (engineChoice == "1") { Process.Start(new ProcessStartInfo(Path.Combine(destination, "Sign-In.cmd")) { UseShellExecute = true, WorkingDirectory = destination }); continue; }
                        if (engineChoice is not ("2" or "3")) continue;
                        var mode = engineChoice == "2" ? "Nomads" : "TDM";
                        var openDreamPort = ServerCatalog.OpenDreamPort(mode, serverPort);
                        var addresses = await Connection.Resolve();
                        Console.WriteLine(Connection.Host + " currently resolves to: " + string.Join(", ", addresses));
                        // Pass only the approved address from this lookup, avoiding a second
                        // unrestricted lookup that could select the explicitly excluded address.
                        Console.WriteLine($"Connecting to experimental OpenDream {mode} on operator port {openDreamPort}.");
                        Process.Start(Connection.Start(destination, mode, addresses.Single(), serverPort));
                    } catch (IOException e) { Console.WriteLine(e.Message); }
                }
            }
        } catch (Exception e) {
            Console.Error.WriteLine("Civ13: " + e.Message);
            if (!(args.Length > 0 && args[0] == "--apply-update") && !Console.IsInputRedirected) { Console.WriteLine("Press Enter to close."); Console.ReadLine(); }
            return 1;
        }
    }
    private static void StartUpdateHelper(string candidate, Channel manifest, string root) {
        var target = Environment.ProcessPath ?? throw new IOException("Launcher path unavailable.");
        var helper = Path.Combine(Path.GetDirectoryName(candidate)!, "UpdateHelper.exe");
        File.Copy(target, helper);
        var start = new ProcessStartInfo(helper) { UseShellExecute = false, CreateNoWindow = true };
        foreach (var arg in new[] { "--apply-update", Environment.ProcessId.ToString(),
            Process.GetCurrentProcess().StartTime.ToUniversalTime().Ticks.ToString(), candidate,
            target, manifest.Sha256, manifest.Version, root }) start.ArgumentList.Add(arg);
        using var helperProcess = Process.Start(start) ?? throw new IOException("Could not start launcher update helper.");
    }
    private static int ApplyUpdate(string[] args) {
        if (args.Length != 8 && !(args.Length == 9 && args[8] == "--self-check")) throw new ArgumentException("Invalid update helper arguments.");
        var pid = int.Parse(args[1]);
        var ticks = long.Parse(args[2]);
        try {
            using var parent = Process.GetProcessById(pid);
            if (parent.StartTime.ToUniversalTime().Ticks != ticks) throw new IOException("Update parent identity changed.");
            if (!parent.WaitForExit(120000)) throw new IOException("Original launcher did not exit; update cancelled.");
        } catch (ArgumentException) { /* Original process has already exited. */ }
        var target = Path.GetFullPath(args[4]);
        Updater.ApplyVerifiedUpdate(args[3], target, args[5], args[6], args[7], CheckStartup, path => {
            var restart = new ProcessStartInfo(path) { UseShellExecute = args.Length == 8, CreateNoWindow = args.Length == 9, WorkingDirectory = Path.GetDirectoryName(path)! };
            if (args.Length == 9) restart.ArgumentList.Add("--self-check");
            else {
                restart.ArgumentList.Add("--root");
                restart.ArgumentList.Add(args[7]);
            }
            using var restarted = Process.Start(restart) ?? throw new IOException("Updated launcher could not restart.");
            if (args.Length == 9 && (!restarted.WaitForExit(30000) || restarted.ExitCode != 0)) throw new IOException("Updated launcher self-check failed.");
        });
        return 0;
    }
    private static void CheckStartup(string path) {
        var start = new ProcessStartInfo(path) { UseShellExecute = false, CreateNoWindow = true };
        start.ArgumentList.Add("--self-check");
        using var process = Process.Start(start) ?? throw new IOException("Updated launcher startup check could not start.");
        if (!process.WaitForExit(30000)) {
            process.Kill(true);
            process.WaitForExit();
            throw new IOException("Updated launcher startup check timed out.");
        }
        if (process.ExitCode != 0) throw new IOException("Updated launcher startup check failed.");
    }
}
