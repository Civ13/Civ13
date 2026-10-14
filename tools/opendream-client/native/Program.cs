using System.Diagnostics;
using System.Reflection;
using System.Text.Json;

namespace Civ13.Launcher;

public static class Program {
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
            if (args.Length != 0) throw new ArgumentException("Supported options: --version, --self-check.");
            var root = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Civ13");
            using var owner = Updater.Lock(root);
            using var transport = new ReleaseTransport();
            Console.WriteLine("Civ13 Launcher " + version.ToString(3));
            try {
                var manifest = Channel.Read(await transport.Text(Updater.LauncherChannelUrl));
                var candidate = await Updater.StageLauncher(manifest, version, root, transport);
                if (candidate is not null) {
                    StartUpdateHelper(candidate, manifest, root);
                    Console.WriteLine("Verified launcher update downloaded. Restarting after this launcher exits...");
                    return 0;
                }
            } catch (Exception e) when (e is HttpRequestException or IOException or InvalidDataException or TaskCanceledException or JsonException or FormatException) {
                Console.WriteLine("Launcher update unavailable: " + e.Message);
            }
            var client = await Updater.ClientChannel(transport, root, BundledChannel());
            using var byondTransport = new ByondTransport();
            var byond = await Byond.Ensure(RequiredByond(), root, byondTransport, new WindowsByondDesktop());
            Console.WriteLine("BYOND " + RequiredByond().Version + " available at " + byond);
            Console.WriteLine("Installing BYOND does not sign you in. Use your own account in the published client's sign-in flow.");
            Console.WriteLine("Client version: " + client.Version);
            var destination = await Updater.EnsureClient(client, root, transport);
            owner.Dispose();
            while (true) {
                Console.WriteLine("\nCiv13 - 1: Sign in   2: Play Nomads   3: Play TDM   4: Exit");
                Console.Write("Choose a number (sign in before your first game): ");
                var choice = Console.ReadLine();
                if (choice is null or "4") return 0;
                var file = choice switch { "1" => "Sign-In.cmd", "2" => "Play-Nomads.cmd", "3" => "Play-TDM.cmd", _ => null };
                if (file is not null) Process.Start(new ProcessStartInfo(Path.Combine(destination, file)) {
                    UseShellExecute = true, WorkingDirectory = destination
                });
            }
        } catch (Exception e) {
            if (args.Length >= 8 && args[0] == "--apply-update") {
                try { Updater.AtomicText(Path.Combine(args[7], "native-update-result.json"), JsonSerializer.Serialize(new { success = false, error = e.Message })); }
                catch (Exception logError) when (logError is IOException or UnauthorizedAccessException) { }
            }
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
        using (Updater.Lock(args[7])) {
            Updater.ReplaceLauncher(args[3], Path.GetFullPath(args[4]), args[5], args[6]);
            Updater.AtomicText(Path.Combine(args[7], "native-update-result.json"), JsonSerializer.Serialize(new { success = true, version = args[6], sha256 = args[5] }));
        }
        var target = Path.GetFullPath(args[4]);
        var restart = new ProcessStartInfo(target) { UseShellExecute = args.Length == 8, CreateNoWindow = args.Length == 9, WorkingDirectory = Path.GetDirectoryName(target)! };
        if (args.Length == 9) restart.ArgumentList.Add("--self-check");
        using var restarted = Process.Start(restart) ?? throw new IOException("Updated launcher could not restart.");
        if (args.Length == 9 && (!restarted.WaitForExit(30000) || restarted.ExitCode != 0)) throw new IOException("Updated launcher self-check failed.");
        return 0;
    }
}
