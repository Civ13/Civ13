using System.Diagnostics;
using System.Globalization;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace Civ13.Launcher;

// Operator-only DreamDaemon hosting. Enabled only by <launcher root>\host.json, so
// player installs are unchanged. Starting the server also starts the configured
// Civilizationbot portable supervisor unless it is already running.
public sealed record HostBot(string Php, string Root, string Profile, int HttpPort);
public sealed record HostUpdate(string Git, string Branch);
// Civ13's scripts/gaia-host/gaia_host.py: the same start/save-and-stop/restart/update path the bot uses.
public sealed record HostControl(string Python, string Script, string Config, HostGroup? Group = null);
// The region group the server belongs to (control.group in host.json): scripts/shard-group/shard_group.py
// acts on every region at once, and scripts/windows/host's deploy.bat and restart-host.bat run the
// whole save, pull, compile and start sequence and restart the host service. All three come from the
// same checkout as control.script, so host.json names only the group config.
public sealed record HostGroup(string Config, string ShardScript, string Deploy, string RestartHost);
public sealed record HostProfile(string GameDirectory, string World, int Port, HostBot? Bot, HostUpdate? Update = null, HostControl? Control = null, string? MobileUrl = null);
// One answer from the control script. Busy means an action is still running in its worker.
public sealed record ControlAnswer(bool Ok, string Message, bool Busy);

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
        HostControl? control = null;
        if (json.TryGetProperty("control", out var controlJson) && controlJson.ValueKind != JsonValueKind.Null) {
            if (update != null) throw new InvalidDataException("host.json control already updates the server; remove the update section.");
            var script = AbsoluteFile(Text(controlJson, "script"), "control.script");
            HostGroup? group = null;
            if (controlJson.TryGetProperty("group", out var groupJson) && groupJson.ValueKind != JsonValueKind.Null) {
                var repository = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(script)!, "..", ".."));
                string Beside(string relative) {
                    var path = Path.Combine(repository, relative);
                    return File.Exists(path) ? path : throw new InvalidDataException($"host.json control.group needs {relative} in the checkout of control.script.");
                }
                group = new HostGroup(AbsoluteFile(Text(controlJson, "group"), "control.group"),
                    Beside(Path.Combine("scripts", "shard-group", "shard_group.py")),
                    Beside(Path.Combine("scripts", "windows", "host", "deploy.bat")),
                    Beside(Path.Combine("scripts", "windows", "host", "restart-host.bat")));
            }
            control = new HostControl(AbsoluteFile(Text(controlJson, "python"), "control.python"), script,
                AbsoluteFile(Text(controlJson, "config"), "control.config"), group);
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
        var mobile = json.TryGetProperty("mobile_url", out _) ? MobileAddress(Text(json, "mobile_url")) : null;
        if (mobile != null && control == null) throw new InvalidDataException("mobile_url requires control.");
        return new HostProfile(game, world, port, bot, update, control, mobile);
    }

    // Display only: configuring an address never starts the companion or installs trust.
    public static string MobileAddress(string value) {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var uri) || uri.Scheme != "https" ||
            uri.UserInfo.Length != 0 || uri.Query.Length != 0 || uri.Fragment.Length != 0 || uri.AbsolutePath != "/" ||
            uri.Port is < 1024 or > 65535 || !System.Net.IPAddress.TryParse(uri.Host, out var address) ||
            address.AddressFamily != AddressFamily.InterNetwork)
            throw new InvalidDataException("mobile_url must be an HTTPS private IPv4 address and explicit port.");
        var bytes = address.GetAddressBytes();
        if (!(bytes[0] == 10 || bytes[0] == 172 && bytes[1] is >= 16 and <= 31 || bytes[0] == 192 && bytes[1] == 168))
            throw new InvalidDataException("mobile_url must be on the private LAN.");
        return $"https://{address}:{uri.Port}";
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
                RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
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
    // Captured steps get an empty, closed stdin rather than the launcher's console input: Python's subprocess
    // duplicates an inherited console handle and fails with WinError 50 ("The request is not supported").
    public static (int Exit, string Output) RunCaptured(ProcessStartInfo step) {
        using var process = Process.Start(step) ?? throw new IOException("Could not start " + Path.GetFileName(step.FileName) + ".");
        if (step.RedirectStandardInput) process.StandardInput.Close();
        var error = process.StandardError.ReadToEndAsync();
        var output = process.StandardOutput.ReadToEnd();
        if (!process.WaitForExit(TimeSpan.FromMinutes(15))) { process.Kill(true); throw new IOException(Path.GetFileName(step.FileName) + " timed out."); }
        return (process.ExitCode, output + error.Result);
    }

    // kill is a forced stop without a save; force-restart kills if running, then starts from the last completed save.
    // unlock removes stale BYOND lock files from a stopped server's save; force-unlock even if it looks running.
    public static readonly string[] ControlActions = ["status", "start", "stop", "restart", "update", "check-update", "kill", "force-restart", "unlock", "force-unlock"];

    // Only the action name reaches the script; its config file names every path and command.
    public static ProcessStartInfo ControlStep(HostControl control, string action) {
        if (!ControlActions.Contains(action)) throw new ArgumentException("Unsupported control action.", nameof(action));
        var step = new ProcessStartInfo(control.Python) { UseShellExecute = false, CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(control.Script)!, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "-I", "-B", control.Script, "--config", control.Config, action }) step.ArgumentList.Add(argument);
        return step;
    }

    public static ControlAnswer RunControl(HostControl control, string action, Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var (exit, output) = (run ?? RunCaptured)(ControlStep(control, action));
        return ParseControl(action, exit, output);
    }

    public static ControlAnswer ParseControl(string action, int exit, string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{')) ?? "";
        JsonDocument document;
        try { document = JsonDocument.Parse(line); }
        catch (JsonException) { return new ControlAnswer(false, $"The host script gave no answer (exit {exit}).", false); }
        using (document) {
            var json = document.RootElement;
            if (json.ValueKind != JsonValueKind.Object || !json.TryGetProperty("ok", out var ok) || ok.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                return new ControlAnswer(false, $"The host script gave no answer (exit {exit}).", false);
            if (!ok.GetBoolean())
                return new ControlAnswer(false, "Refused: " + (Str(json, "refused") ?? Str(json, "error") ?? "no reason given"), false);
            if (action == "status") return new ControlAnswer(true, Describe(json), Bool(json, "busy"));
            if (action is "unlock" or "force-unlock") return new ControlAnswer(true, DescribeUnlock(json), false);
            if (action == "kill")
                return Bool(json, "killed") ? new ControlAnswer(true, "Server force-stopped without saving. The next start loads the last completed save.", false)
                    : new ControlAnswer(false, "The host script did not stop the server.", false);
            // force-restart answers with the start it requested.
            if (!Bool(json, "accepted") || Str(json, "action") != (action == "force-restart" ? "start" : action))
                return new ControlAnswer(false, "The host script did not accept " + action + ".", false);
            return new ControlAnswer(true, action switch {
                "start" => "Starting the server...",
                "stop" => "Saving the world, then stopping the server...",
                "restart" => "Saving the world, then restarting the server...",
                "force-restart" => (Bool(json, "killed") ? "Server force-stopped without saving; s" : "S") + "tarting it from the last completed save...",
                _ => "Pulling and compiling master...",
            }, true);
        }
    }

    // freeze/thaw: sleep an empty, saved region now, or wake it; setup: create or refresh a region's worktree and
    // config and enrol it for travel (refused while it runs). stage and handover: staged builds (#3936).
    public static readonly string[] GroupActions = ["status", "start", "stop", "restart", "update", "kill", "force-restart", "check-update", "help-status", "help-start", "help-stop", "unlock", "force-unlock", "config-apply", "stage", "handover",
        "freeze", "thaw", "setup", "epoch", "fresh-world"];

    // code/modules/persistence/functions.dm epoch_names, as shard_group.py EPOCH_NAMES; index = ordinal_age.
    public static readonly string[] EpochNames = ["5000 B.C.", "313 B.C.", "1013", "1713", "1873", "1903", "1943", "1969", "2013", "2026"];
    // shard_group.py ids, never starting with "-" so one cannot read as an option.
    private static readonly System.Text.RegularExpressions.Regex RegionId = new("^[a-z0-9][a-z0-9_-]{0,31}$");

    // shard_group.py for every region of the group, or one (a region id as shard_group.py names it);
    // again only the action name and that id come from the caller.
    // epoch: the ordinal to advance the whole group to ("epoch" only, never with a region; every region follows the mainland).
    public static ProcessStartInfo GroupStep(HostControl control, string action, string? region = null, int? epoch = null, string? confirmRegion = null) {
        var group = control.Group ?? throw new InvalidOperationException("No region group configured.");
        if (!GroupActions.Contains(action)) throw new ArgumentException("Unsupported group action.", nameof(action));
        if (region != null && !RegionId.IsMatch(region)) throw new ArgumentException("Not a region id.", nameof(region));
        if ((action == "epoch") != (epoch != null) || (action == "epoch" && region != null) || epoch is < 0 || epoch >= EpochNames.Length)
            throw new ArgumentException("epoch takes one epoch for the whole group.", nameof(epoch));
        if (action == "fresh-world" ? region == null || confirmRegion != region : confirmRegion != null)
            throw new ArgumentException("Fresh world requires an exact selected-region confirmation.", nameof(confirmRegion));
        var step = new ProcessStartInfo(control.Python) { UseShellExecute = false, CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(group.ShardScript)!, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "-I", "-B", group.ShardScript, "--config", group.Config, action }) step.ArgumentList.Add(argument);
        if (region != null) { step.ArgumentList.Add("--region"); step.ArgumentList.Add(region); }
        if (confirmRegion != null) { step.ArgumentList.Add("--confirm-region"); step.ArgumentList.Add(confirmRegion); }
        if (epoch is { } ordinal) { step.ArgumentList.Add("--epoch"); step.ArgumentList.Add(ordinal.ToString(CultureInfo.InvariantCulture)); }
        return step;
    }

    // deploy.bat (resume: "deploy.bat continue", which carries on from waiting for the save; regions: only
    // those region ids, none for every region) or restart-host.bat, run by cmd.exe with its output read line by line.
    public static ProcessStartInfo GroupScriptStep(HostControl control, string script, bool resume = false, IReadOnlyList<string>? regions = null) {
        var group = control.Group ?? throw new InvalidOperationException("No region group configured.");
        var path = script switch {
            "deploy" => group.Deploy,
            "restart-host" => group.RestartHost,
            _ => throw new ArgumentException("Unsupported group script.", nameof(script)),
        };
        if ((resume || regions is { Count: > 0 }) && script != "deploy") throw new ArgumentException("Only deploy can continue or choose regions.", nameof(script));
        if (regions != null && regions.Any(region => !RegionId.IsMatch(region))) throw new ArgumentException("Not a region id.", nameof(regions));
        var step = new ProcessStartInfo(Path.Combine(Environment.SystemDirectory, "cmd.exe")) { UseShellExecute = false, CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(path)!, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "/d", "/c", path }) step.ArgumentList.Add(argument);
        if (resume) step.ArgumentList.Add("continue");
        foreach (var region in regions ?? []) step.ArgumentList.Add(region);
        return step;
    }

    // Port and TransferPort are the region's game and travel agent ports from the group config (0 when absent).
    public sealed record GroupRegion(string Id, string Name, bool Mainland, int Port = 0, int TransferPort = 0);

    // The regions of the group config (control.group), in its order, for choosing which ones to update.
    // The mainland is the config's "mainland", or the first region, as shard_group.py decides it.
    public static IReadOnlyList<GroupRegion> GroupRegions(HostGroup group) {
        using var document = JsonDocument.Parse(File.ReadAllText(group.Config));
        var json = document.RootElement;
        if (json.ValueKind != JsonValueKind.Object || !json.TryGetProperty("regions", out var list) || list.ValueKind != JsonValueKind.Array)
            throw new InvalidDataException("The group config lists no regions.");
        var found = new List<(string Id, string Name, int Port, int TransferPort)>();
        foreach (var region in list.EnumerateArray().Take(16)) {
            if (region.ValueKind != JsonValueKind.Object || Str(region, "id") is not { } id || !RegionId.IsMatch(id)) continue;
            found.Add((id, Clean(Str(region, "name") ?? id), OptionalPort(region, "port"), OptionalPort(region, "transfer_port")));
        }
        if (found.Count == 0) throw new InvalidDataException("The group config lists no regions.");
        var mainland = Str(json, "mainland") ?? found[0].Id;
        return found.Select(region => new GroupRegion(region.Id, region.Name, region.Id == mainland, region.Port, region.TransferPort)).ToList();
    }

    private static int OptionalPort(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var port) && port is > 0 and < 65536 ? port : 0;

    // A region's world log in its worktree (<group root>/<id>/logs/world.log, as shard_group.py region_dir
    // places it), or null when the group config names no root. The id is checked like every other region id.
    public static string? RegionLog(HostGroup group, string region) {
        if (!RegionId.IsMatch(region)) throw new ArgumentException("Not a region id.", nameof(region));
        using var document = JsonDocument.Parse(File.ReadAllText(group.Config));
        if (document.RootElement.ValueKind != JsonValueKind.Object || Str(document.RootElement, "root") is not { Length: > 0 } root) return null;
        return Path.Combine(Path.GetFullPath(root), region, "logs", "world.log");
    }

    // deploy.bat's exit code when a region did not save and is still running (the others stay stopped).
    public const int DeployUnsaved = 3;

    public static ControlAnswer RunGroup(HostControl control, string action, Func<ProcessStartInfo, (int Exit, string Output)>? run = null, string? region = null, int? epoch = null, string? confirmRegion = null) {
        var (exit, output) = (run ?? RunCaptured)(GroupStep(control, action, region, epoch, confirmRegion));
        return ParseGroup(action, exit, output);
    }

    public sealed record UnsavedRegion(string Id, string Name, string Reason);

    // After deploy.bat exits with DeployUnsaved: the regions still running with no save under way, from
    // shard_group.py status, each with why: the stop's refusal from deploy's own output (the JSON line
    // shard_group.py stop printed) or the failed save's error, as wait_group.py decides it.
    public static IReadOnlyList<UnsavedRegion> UnsavedRegions(string statusOutput, string deployOutput) {
        var refusals = new Dictionary<string, string>();
        foreach (var text in deployOutput.Split('\n').Select(part => part.Trim()).Where(part => part.StartsWith('{'))) {
            try {
                using var answer = JsonDocument.Parse(text);
                if (answer.RootElement.ValueKind == JsonValueKind.Object && answer.RootElement.TryGetProperty("refused", out var refused)
                        && refused.ValueKind == JsonValueKind.Object)
                    foreach (var entry in refused.EnumerateObject())
                        if (entry.Value.ValueKind == JsonValueKind.String) refusals[entry.Name] = entry.Value.GetString()!;
            } catch (JsonException) { }
        }
        var found = new List<UnsavedRegion>();
        var line = statusOutput.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{')) ?? "";
        try {
            using var document = JsonDocument.Parse(line);
            if (!document.RootElement.TryGetProperty("regions", out var regions) || regions.ValueKind != JsonValueKind.Object) return found;
            foreach (var region in regions.EnumerateObject().Take(16)) {
                var entry = region.Value;
                if (entry.ValueKind != JsonValueKind.Object || !RegionId.IsMatch(region.Name) || !Bool(entry, "listening") || Bool(entry, "busy")) continue;
                string? error = null;
                if (entry.TryGetProperty("operation", out var operation) && operation.ValueKind == JsonValueKind.Object)
                    error = Str(operation, "error") is { Length: > 0 } failed ? failed : null;
                var reason = refusals.TryGetValue(region.Name, out var refusal) ? "its save was refused: " + refusal
                    : error ?? "it is still running and not saving";
                found.Add(new UnsavedRegion(region.Name, Clean(Str(entry, "name") ?? region.Name), reason.Length > 300 ? reason[..300] : reason));
            }
        } catch (JsonException) { }
        return found;
    }

    // shard_group.py answers {"ok", "regions": {id: status}} for status, and {"ok", "accepted": {id: ...},
    // "refused": {id: reason}} (or "refused": "reason" for the whole group) for an action.
    public static ControlAnswer ParseGroup(string action, int exit, string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{')) ?? "";
        JsonDocument document;
        try { document = JsonDocument.Parse(line); }
        catch (JsonException) { return new ControlAnswer(false, $"The group script gave no answer (exit {exit}).", false); }
        using (document) {
            var json = document.RootElement;
            if (json.ValueKind != JsonValueKind.Object || !json.TryGetProperty("ok", out var ok) || ok.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                return new ControlAnswer(false, $"The group script gave no answer (exit {exit}).", false);
            var refused = Refusals(json);
            if (!ok.GetBoolean())
                return new ControlAnswer(false, "Refused: " + (refused ?? Str(json, "error") ?? "no reason given"), false);
            if (action == "status") {
                var busy = false;
                var regions = new List<string>();
                if (json.TryGetProperty("regions", out var list) && list.ValueKind == JsonValueKind.Object) {
                    foreach (var region in list.EnumerateObject().Take(16)) {
                        if (region.Value.ValueKind != JsonValueKind.Object) continue;
                        var entry = region.Value;
                        busy |= Bool(entry, "busy");
                        var text = Clean(Str(entry, "name") ?? region.Name) + ": " + Lower(Str(entry, "state") ?? "unknown");
                        if (entry.TryGetProperty("world", out var world) && world.ValueKind == JsonValueKind.Object
                                && world.TryGetProperty("clients", out var clients) && clients.ValueKind == JsonValueKind.Number)
                            text += $", {clients.GetInt32()} players";
                        if (entry.TryGetProperty("operation", out var operation) && operation.ValueKind == JsonValueKind.Object
                                && Str(operation, "action") is { } last && Str(operation, "phase") is { } phase) {
                            text += $", last {Lower(last)} ({Words(phase)})";
                            if (Str(operation, "error") is { Length: > 0 } failed) text += ": " + failed;
                        }
                        text += RegionDetails(entry);
                        regions.Add(text);
                    }
                }
                var summary = regions.Count == 0 ? "The group has no regions." : "Group: " + string.Join("; ", regions) + ".";
                // Present only when the group has travel (transfer ports): the coordinator moves characters between regions.
                if (json.TryGetProperty("coordinator", out var coordinator) && coordinator.ValueKind is JsonValueKind.True or JsonValueKind.False)
                    summary += coordinator.GetBoolean() ? " Travel coordinator running." : " Travel coordinator is not running (a start or restart starts it).";
                return new ControlAnswer(true, summary, busy);
            }
            if (action is "unlock" or "force-unlock") {
                var lines = new List<string>();
                if (json.TryGetProperty("done", out var done) && done.ValueKind == JsonValueKind.Object)
                    foreach (var region in done.EnumerateObject().Take(16))
                        if (region.Value.ValueKind == JsonValueKind.Object) lines.Add(Clean(region.Name) + ": " + DescribeUnlock(region.Value));
                if (refused != null) lines.Add("Refused: " + refused + ".");
                return new ControlAnswer(lines.Count > 0, lines.Count == 0 ? "The group script did not check any region." : string.Join(" ", lines), false);
            }
            if (action == "config-apply") {
                // {"done": {id: {"copied": [paths], "running": bool}}, "refused": {id: reason}}
                var lines = new List<string>();
                if (json.TryGetProperty("done", out var done) && done.ValueKind == JsonValueKind.Object)
                    foreach (var region in done.EnumerateObject().Take(16)) {
                        if (region.Value.ValueKind != JsonValueKind.Object) continue;
                        var count = region.Value.TryGetProperty("copied", out var copied) && copied.ValueKind == JsonValueKind.Array ? copied.GetArrayLength() : 0;
                        lines.Add(Clean(region.Name) + ": " + (count == 0 ? "already current" : count == 1 ? "1 file written" : $"{count} files written")
                            + (Bool(region.Value, "running") ? " (running: used from its next restart)." : "."));
                    }
                if (refused != null) lines.Add("Refused: " + refused + ".");
                return new ControlAnswer(lines.Count > 0, lines.Count == 0 ? "The group script did not apply the settings to any region." : string.Join(" ", lines), false);
            }
            if (action is "freeze" or "thaw") {
                // {"done": {id: {"frozen": true, ...} | {"thawed": true, ...}}, "refused": {id: reason}}
                var done = json.TryGetProperty("done", out var doneJson) && doneJson.ValueKind == JsonValueKind.Object
                    ? doneJson.EnumerateObject().Take(16).Select(entry => Clean(entry.Name)).ToList() : [];
                if (done.Count == 0) return new ControlAnswer(false, refused != null ? "Refused: " + refused : "The group script did not " + action + " any region.", false);
                var text = (action == "freeze" ? "Asleep now (a join or travel wakes it): " : "Woken: ") + string.Join(", ", done) + ".";
                return new ControlAnswer(true, refused != null ? text + " Refused: " + refused + "." : text, false);
            }
            if (action == "epoch") {
                // {"epoch": ordinal, "name", "mainland", "regions": {id: "set" | "current" | why not}}
                var name = json.TryGetProperty("epoch", out var ordinal) && ordinal.ValueKind == JsonValueKind.Number && ordinal.TryGetInt32(out var index)
                    && index >= 0 && index < EpochNames.Length ? EpochNames[index] : "the chosen epoch";
                var lines = new List<string>();
                if (json.TryGetProperty("regions", out var done) && done.ValueKind == JsonValueKind.Object)
                    foreach (var region in done.EnumerateObject().Take(16)) {
                        var state = region.Value.ValueKind == JsonValueKind.String ? Short(region.Value.GetString()!) : "no answer";
                        lines.Add(Clean(region.Name) + ": " + (state == "set" ? "now " + name : state == "current" ? "already at " + name + " or later" : state));
                    }
                return new ControlAnswer(lines.Count > 0, lines.Count == 0 ? "The group script changed no region's epoch."
                    : "Epoch " + name + ": " + string.Join("; ", lines) + ".", false);
            }
            if (action == "setup") {
                // {"revision", "created": [ids], "regions": [ids], "region", "running": [ids], "enrolled": [...]}
                var created = json.TryGetProperty("created", out var made) && made.ValueKind == JsonValueKind.Array
                    ? made.EnumerateArray().Take(16).Where(item => item.ValueKind == JsonValueKind.String).Select(item => Clean(item.GetString()!)).ToList() : [];
                var which = Str(json, "region") is { } one ? Clean(one) : "every region";
                var text = created.Count > 0 ? "Set up " + string.Join(", ", created) + "." : "Refreshed the config of " + which + ".";
                if (json.TryGetProperty("enrolled", out var enrolled) && enrolled.ValueKind == JsonValueKind.Array && enrolled.GetArrayLength() > 0)
                    text += " Enrolled it for travel with the running agents.";
                if (json.TryGetProperty("running", out var running) && running.ValueKind == JsonValueKind.Array && running.GetArrayLength() > 0)
                    text += " Running regions learn about it at their next restart.";
                return new ControlAnswer(true, text + " Next: Update, then Start.", false);
            }
            // kill finishes at once and lists the regions it stopped under "done"; the others hand off to a worker.
            var acceptedName = action == "kill" ? "done" : "accepted";
            var accepted = json.TryGetProperty(acceptedName, out var acceptedJson) && acceptedJson.ValueKind == JsonValueKind.Object
                ? acceptedJson.EnumerateObject().Select(entry => Clean(entry.Name)).ToList() : [];
            if (accepted.Count == 0) return new ControlAnswer(false, "The group script did not accept " + action + ".", false);
            if (action == "kill") {
                var stopped = "Force-stopped " + string.Join(", ", accepted) + " without saving; the next start loads the last completed save.";
                return new ControlAnswer(true, refused != null ? stopped + " Refused: " + refused + "." : stopped, false);
            }
            var message = action switch {
                "force-restart" => "Force-restarting (no save) and starting from the last completed save:",
                "fresh-world" => "Archiving the old world and starting the installed build fresh:",
                "start" => "Starting",
                "stop" => "Saving, then stopping",
                "restart" => "Saving, then restarting",
                "stage" => "Building the update beside",
                "handover" => "Handing over to the new build (the old world saves one level at a time, holding only the level being saved, the new one loads the save, then players reconnect):",
                _ => "Checking out and compiling",
            } + " " + string.Join(", ", accepted) + "...";
            if (refused != null) message += " Refused: " + refused + ".";
            return new ControlAnswer(true, message, true);
        }
    }

    // A region's staged build ("stage": {"phase", "error", "pending"}) and a standby world loading beside it
    // during a handover ("standby": {"port", "listening"}), for the group status line.
    public static string DescribeStage(JsonElement entry) {
        var text = "";
        if (entry.TryGetProperty("stage", out var stage) && stage.ValueKind == JsonValueKind.Object && Str(stage, "phase") is { } phase) {
            text = phase switch {
                "ready" => Bool(stage, "pending") ? ", update built (ready to hand over)" : "",
                "current" => "",
                "failed" => ", update build failed" + (Str(stage, "error") is { Length: > 0 } failed ? ": " + failed : ""),
                _ => ", building update (" + Words(phase) + ")",
            };
        }
        if (entry.TryGetProperty("standby", out var standby) && standby.ValueKind == JsonValueKind.Object)
            text += Bool(standby, "listening") ? ", new build running beside it" : ", new build starting beside it";
        return text;
    }

    // Lowercase letters, apostrophes and single spaces only (64 at most), for a phase name shown in a line.
    private static string Words(string text) {
        var kept = new string(text.Take(64).Select(c => char.IsAsciiLetterLower(c) || c == '\'' ? c : ' ').ToArray());
        return string.Join(' ', kept.Split(' ', StringSplitOptions.RemoveEmptyEntries));
    }

    // The rest of one region's shard_group.py status, after its state, players and last action: its port, the
    // staged build and standby (DescribeStage), the watchdog's record, the travel agent and whether the world
    // answers as this region. Empty when there is nothing to add.
    public static string RegionDetails(JsonElement entry) {
        var text = OptionalPort(entry, "port") is > 0 and var port ? ", port " + port : "";
        text += DescribeStage(entry);
        var parts = new List<string>();
        if (entry.TryGetProperty("watchdog", out var watchdog) && watchdog.ValueKind == JsonValueKind.Object) {
            var restarts = watchdog.TryGetProperty("restarts", out var list) && list.ValueKind == JsonValueKind.Array ? list.GetArrayLength() : 0;
            var last = Str(watchdog, "last_event") is { } kind ? Lower(kind) : "a crash";
            if (watchdog.TryGetProperty("gave_up", out _))
                parts.Add($"watchdog gave up after repeated restarts ({last}); start it by hand");
            else if (Str(watchdog, "last_refusal") is { Length: > 0 } refusal)
                parts.Add("watchdog could not restart it: " + Short(refusal));
            else if (Bool(watchdog, "cold"))
                parts.Add("watchdog left it asleep (low memory)");
            else if (restarts > 0)
                parts.Add($"watchdog restarted it {restarts} time{(restarts == 1 ? "" : "s")} recently (last: {last})");
        }
        if (entry.TryGetProperty("transfer_agent", out var agent) && agent.ValueKind == JsonValueKind.False) parts.Add("travel agent not running");
        if (entry.TryGetProperty("region_view", out var view) && view.ValueKind == JsonValueKind.Object) {
            if (Str(view, "error") != null) parts.Add("not answering as this region");
            else if (view.TryGetProperty("epoch", out var epoch) && epoch.ValueKind == JsonValueKind.Object && epoch.TryGetProperty("ordinal", out var ordinal)
                    && ordinal.ValueKind == JsonValueKind.Number && ordinal.TryGetInt32(out var index) && index >= 0 && index < EpochNames.Length)
                parts.Add("epoch " + EpochNames[index]);
            // TDM Barracks and battle regions: what the battle is doing.
            if (Str(view, "error") == null && Str(view, "battle_phase") is { Length: > 0 } phase)
                parts.Add("battle " + BattlePhase(phase));
        }
        return parts.Count == 0 ? text : text + ", " + string.Join(", ", parts);
    }

    // shard_group.py region_view battle_phase (code/modules/tdm_barracks): plain words for the Host tab.
    public static string BattlePhase(string phase) => phase switch {
        "pregame" => "forming",
        "playing" => "in progress",
        "finished" => "over, map vote",
        "returning" => "sending players back",
        "rotating" => "building the next map",
        "starting" => "starting up",
        _ => Clean(phase),
    };

    private static string Short(string text) => text.Length > 200 ? text[..200] : text;

    // {"removed": [names], "forced", "server_running", "save": generation | "save_refused": reason}
    public static string DescribeUnlock(JsonElement json) {
        var removed = json.TryGetProperty("removed", out var list) && list.ValueKind == JsonValueKind.Array ? list.GetArrayLength() : 0;
        var text = removed == 0 ? "no lock files." : $"removed {removed} lock file{(removed == 1 ? "" : "s")}.";
        if (Str(json, "save_refused") is { Length: > 0 } refusal) text += " The save still does not load: " + refusal + ".";
        else if (json.TryGetProperty("save", out _)) text += " The save is ready to load.";
        return text;
    }

    private static string? Refusals(JsonElement json) {
        if (!json.TryGetProperty("refused", out var refused)) return null;
        if (refused.ValueKind == JsonValueKind.String) return refused.GetString();
        if (refused.ValueKind != JsonValueKind.Object) return null;
        var reasons = refused.EnumerateObject()
            .Select(entry => Clean(entry.Name) + ": " + (entry.Value.ValueKind == JsonValueKind.String ? entry.Value.GetString() : "refused")).ToList();
        return reasons.Count == 0 ? null : string.Join("; ", reasons);
    }

    private static string Lower(string text) => new(text.Where(char.IsAsciiLetterLower).ToArray());

    // Letters, marks and digits in any script, cut to 64 characters (runes), never mid-character.
    private static string Clean(string name) => string.Concat(name.EnumerateRunes().Where(r => Rune.IsLetterOrDigit(r)
        || Rune.GetUnicodeCategory(r) is UnicodeCategory.NonSpacingMark or UnicodeCategory.SpacingCombiningMark or UnicodeCategory.EnclosingMark
        || (r.IsAscii && " -'().".Contains((char)r.Value))).Take(64).Select(r => r.ToString()));

    // Same wording as the bot's hoststatus line.
    public static string Describe(JsonElement status) {
        var parts = new List<string> { Str(status, "state") switch {
            "asleep" => "Server is asleep (frozen in memory; a join or travel wakes it).",
            "cold" => "Server is asleep (stopped after its last save; a launcher wake or travel starts it).",
            _ => Bool(status, "listening") ? "Server port is open." : "Server is not running.",
        } };
        if (status.TryGetProperty("world", out var world) && world.ValueKind == JsonValueKind.Object) {
            parts.Add(Bool(world, "ready") ? "World ready." : "World not ready.");
            if (world.TryGetProperty("clients", out var clients) && clients.ValueKind == JsonValueKind.Number) parts.Add($"{clients.GetInt32()} players.");
            if (Str(world, "error") is { Length: > 0 } error) parts.Add("Error: " + error + ".");
        }
        if (status.TryGetProperty("operation", out var operation) && operation.ValueKind == JsonValueKind.Object
                && Str(operation, "action") is { } last && Str(operation, "phase") is { } phase) {
            var text = $"Last action: {last} ({phase})";
            if (Str(operation, "error") is { Length: > 0 } failed) text += ": " + failed;
            parts.Add(text + ".");
            if (Str(operation, "archive") is { Length: > 0 } archive) parts.Add("Recovery archive: " + archive + ".");
            if (Str(operation, "validation") is { Length: > 0 } validation) parts.Add(validation + ".");
        }
        var line = string.Join(" ", parts);
        // A region host (Civ13 scripts/shard-group) also lists every region of its group.
        var regions = new List<string>();
        if (status.TryGetProperty("regions", out var list) && list.ValueKind == JsonValueKind.Array) {
            foreach (var region in list.EnumerateArray().Take(16)) {
                if (region.ValueKind != JsonValueKind.Object || Str(region, "name") is not { } name || Str(region, "state") is not { } state) continue;
                var clean = Clean(name);
                var players = region.TryGetProperty("players", out var count) && count.ValueKind == JsonValueKind.Number ? $", {count.GetInt32()} players" : "";
                regions.Add($"{clean}: {Lower(state)}{players}");
            }
        }
        return regions.Count == 0 ? line : line + "\nRegions: " + string.Join("; ", regions) + ".";
    }

    private static string? Str(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
    private static bool Bool(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True;

    // Starts whatever is not already listening; returns one line per component for the console.
    public static IReadOnlyList<string> Run(HostProfile host, string byondBin, Func<int, bool> listening, Action<ProcessStartInfo> start,
            Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var report = new List<string>();
        if (listening(host.Port)) report.Add($"DreamDaemon is already running on port {host.Port}; not updating a live world.");
        else if (host.Control is { } control) {
            var answer = RunControl(control, "start", run);
            report.Add(answer.Message);
            if (!answer.Ok) return report;
        } else {
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
