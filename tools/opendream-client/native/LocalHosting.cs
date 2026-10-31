using System.Diagnostics;
using System.Net.Sockets;
using System.Text.Json;

namespace Civ13.Launcher;

// Operator-only DreamDaemon hosting. Enabled only by <launcher root>\host.json, so
// player installs are unchanged. Starting the server also starts the configured
// Civilizationbot portable supervisor unless it is already running.
public sealed record HostBot(string Php, string Root, string Profile, int HttpPort);
public sealed record HostUpdate(string Git, string Branch);
public sealed record HostProfile(string GameDirectory, string World, int Port, HostBot? Bot, HostUpdate? Update = null);

public static class LocalHosting {
    public const string MenuKey = "H";
    public const string FileName = "host.json";
    public static string Menu => MenuKey + ": Host local DreamDaemon server";

    public static HostProfile? Load(string root) {
        var path = Path.Combine(root, FileName);
        if (!File.Exists(path)) return null;
        using var document = JsonDocument.Parse(File.ReadAllText(path));
        var json = document.RootElement;
        if (json.ValueKind != JsonValueKind.Object || !json.TryGetProperty("schema", out var schema) || schema.ValueKind != JsonValueKind.Number || schema.GetInt32() != 1)
            throw new InvalidDataException("host.json requires schema 1.");
        var game = AbsoluteDirectory(Text(json, "game_directory"), "game_directory");
        var world = Text(json, "world");
        if (Path.GetFileName(world) != world || !world.EndsWith(".dmb", StringComparison.OrdinalIgnoreCase) || !File.Exists(Path.Combine(game, world)))
            throw new InvalidDataException("host.json world must name a compiled .dmb inside game_directory.");
        var port = Port(json, "port");
        HostUpdate? update = null;
        if (json.TryGetProperty("update", out var updateJson) && updateJson.ValueKind != JsonValueKind.Null) {
            var git = AbsoluteFile(Text(updateJson, "git"), "update.git");
            var branch = Text(updateJson, "branch");
            if (!System.Text.RegularExpressions.Regex.IsMatch(branch, "^[A-Za-z0-9._/-]{1,100}$") || branch.StartsWith('-') || branch.Contains(".."))
                throw new InvalidDataException("host.json update.branch must be a plain branch name.");
            if (!File.Exists(Path.Combine(game, Path.ChangeExtension(world, ".dme"))))
                throw new InvalidDataException("host.json update requires the world's .dme beside it in game_directory.");
            update = new HostUpdate(git, branch);
        }
        HostBot? bot = null;
        if (json.TryGetProperty("bot", out var botJson) && botJson.ValueKind != JsonValueKind.Null) {
            var php = AbsoluteFile(Text(botJson, "php"), "bot.php");
            var botRoot = AbsoluteDirectory(Text(botJson, "root"), "bot.root");
            if (!File.Exists(Path.Combine(botRoot, "scripts", "windows", "control.php")))
                throw new InvalidDataException("host.json bot.root must be a Civilizationbot checkout with scripts/windows/control.php.");
            var profile = AbsoluteFile(Text(botJson, "profile"), "bot.profile");
            // The bot's HTTP listener is the liveness probe; read its port from the bot profile itself.
            using var botProfile = JsonDocument.Parse(File.ReadAllText(profile));
            bot = new HostBot(php, botRoot, profile, Port(botProfile.RootElement, "http_port"));
        }
        return new HostProfile(game, world, port, bot, update);
    }

    // The hosted world is always listed publicly on the BYOND hub.
    public static ProcessStartInfo DaemonStart(HostProfile host, string byondBin) {
        var start = new ProcessStartInfo(Path.Combine(byondBin, "dd.exe")) {
            UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = host.GameDirectory };
        foreach (var argument in new[] { host.World, host.Port.ToString(), "-trusted", "-public", "-close", "-log", "logs/world.log" })
            start.ArgumentList.Add(argument);
        return start;
    }

    public static ProcessStartInfo BotStart(HostBot bot) {
        var start = new ProcessStartInfo(bot.Php) { UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = bot.Root };
        foreach (var argument in new[] { "scripts/windows/control.php", "start", bot.Profile }) start.ArgumentList.Add(argument);
        return start;
    }

    // Fast-forward the checkout to origin/<branch>, then rebuild the world. Local edits are kept;
    // anything but a clean fast-forward or a 0-error/0-warning compile stops the start.
    public static IReadOnlyList<ProcessStartInfo> UpdateSteps(HostProfile host, string byondBin) {
        var update = host.Update ?? throw new InvalidOperationException("No update configured.");
        ProcessStartInfo Step(string file, params string[] arguments) {
            var step = new ProcessStartInfo(file) { UseShellExecute = false, CreateNoWindow = true, WorkingDirectory = host.GameDirectory,
                RedirectStandardOutput = true, RedirectStandardError = true };
            foreach (var argument in arguments) step.ArgumentList.Add(argument);
            return step;
        }
        return [
            Step(update.Git, "fetch", "origin", update.Branch),
            Step(update.Git, "merge", "--ff-only", "FETCH_HEAD"),
            Step(Path.Combine(byondBin, "dm.exe"), "-max_errors", "0", Path.ChangeExtension(host.World, ".dme")),
        ];
    }

    // Runs a step to completion, returning its exit code and combined output.
    public static (int Exit, string Output) RunCaptured(ProcessStartInfo step) {
        using var process = Process.Start(step) ?? throw new IOException("Could not start " + Path.GetFileName(step.FileName) + ".");
        var error = process.StandardError.ReadToEndAsync();
        var output = process.StandardOutput.ReadToEnd();
        if (!process.WaitForExit(TimeSpan.FromMinutes(15))) { process.Kill(true); throw new IOException(Path.GetFileName(step.FileName) + " timed out."); }
        return (process.ExitCode, output + error.Result);
    }

    // Starts whatever is not already listening; returns one line per component for the console.
    public static IReadOnlyList<string> Run(HostProfile host, string byondBin, Func<int, bool> listening, Action<ProcessStartInfo> start,
            Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var report = new List<string>();
        if (listening(host.Port)) report.Add($"DreamDaemon is already running on port {host.Port}; not updating a live world.");
        else {
            if (host.Update != null) {
                foreach (var step in UpdateSteps(host, byondBin)) {
                    var name = Path.GetFileName(step.FileName) + " " + step.ArgumentList[0];
                    var (exit, output) = (run ?? RunCaptured)(step);
                    var compile = Path.GetFileName(step.FileName).Equals("dm.exe", StringComparison.OrdinalIgnoreCase);
                    if (exit != 0 || (compile && !output.Contains("0 errors, 0 warnings"))) {
                        var tail = output.Trim().Split('\n').LastOrDefault()?.Trim() ?? "";
                        report.Add($"Update failed at {name} (exit {exit}): {tail}. DreamDaemon was not started.");
                        return report;
                    }
                }
                report.Add($"Updated to origin/{host.Update.Branch} and rebuilt {host.World}.");
            }
            Directory.CreateDirectory(Path.Combine(host.GameDirectory, "logs"));
            start(DaemonStart(host, byondBin));
            report.Add($"Started DreamDaemon: {host.World} on port {host.Port} (public).");
        }
        if (host.Bot is { } bot) {
            if (listening(bot.HttpPort)) report.Add($"Civilizationbot is already running (port {bot.HttpPort}).");
            else {
                start(BotStart(bot));
                report.Add("Started the Civilizationbot supervisor.");
            }
        }
        return report;
    }

    public static bool Listening(int port) {
        using var client = new TcpClient();
        try { return client.ConnectAsync("127.0.0.1", port).Wait(TimeSpan.FromSeconds(1)) && client.Connected; }
        catch (AggregateException) { return false; }
    }

    private static string Text(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String && value.GetString() is { Length: > 0 } text
            ? text : throw new InvalidDataException($"host.json requires {name}.");
    private static int Port(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var port) && port is >= 1 and <= 65535
            ? port : throw new InvalidDataException($"{name} must be a port from 1 to 65535.");
    private static string AbsoluteDirectory(string path, string name) =>
        Path.IsPathFullyQualified(path) && Directory.Exists(path) ? Path.GetFullPath(path) : throw new InvalidDataException($"host.json {name} must be an existing absolute folder.");
    private static string AbsoluteFile(string path, string name) =>
        Path.IsPathFullyQualified(path) && File.Exists(path) ? Path.GetFullPath(path) : throw new InvalidDataException($"host.json {name} must be an existing absolute file.");
}
