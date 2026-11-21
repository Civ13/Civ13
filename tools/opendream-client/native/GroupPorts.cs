using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Civ13.Launcher;

// The Host tab's "Front door and ports" window (All regions > More). The front door is the region on the
// public port: the world players and the Discord Play button join, which the bot watches. Civ13's
// scripts/shard-group/group_ports.py does the work (shard_group.py ports / set-gate / set-port): it answers
// with a plan first, and only "apply" saves and stops the two worlds, swaps their ports and starts them again.
public static class GroupPorts {
    public sealed record PortRow(int Port, string Use, string? Region, string? Name, bool Public, bool Gate, bool? Listening);
    // The last port change (<root>/port-change.json): Phase is "done", "failed" or the step under way.
    public sealed record Change(string Kind, string Phase, string? Error, bool Running, bool Changed, IReadOnlyList<string> Log,
        IReadOnlyList<string> RestartNeeded, bool BotRestart);
    public sealed record Report(bool Ok, string? Error, string? Gate, string? PublicHost, IReadOnlyList<int> PublicPorts,
        IReadOnlyList<PortRow> Ports, IReadOnlyList<string> Problems, string HostService, Change? Change);
    public sealed record Plan(bool Ok, string? Error, bool Accepted, bool Already, IReadOnlyList<string> Steps,
        IReadOnlyList<string> Problems, IReadOnlyList<string> Warnings, IReadOnlyList<int> PublicPorts, bool BotRestart);
    public sealed record Choice(string Id, string Name, int Port);

    // shard_group.py ids, never starting with "-" so one cannot read as an option.
    private static readonly Regex RegionId = new("^[a-z0-9][a-z0-9_-]{0,31}$");
    // Kinds nobody lives in, so none can be the front door (group_ports.py GATE_REFUSED_KINDS).
    private static readonly string[] NoGateKinds = ["RAID", "EVENT", "TUTORIAL", "EXPEDITION"];

    // action: "ports" (read only), "set-gate" (region), "set-port" (region and port) or "add-gateway" (nothing else).
    // apply: carry the plan out; without it the script only answers with the plan. botProfile: the bot profile.json
    // to repoint with the gate.
    public static ProcessStartInfo Step(HostControl control, string action, string? region = null, int? port = null, bool apply = false, string? botProfile = null) {
        var group = control.Group ?? throw new InvalidOperationException("No region group configured.");
        if (action is not ("ports" or "set-gate" or "set-port" or "add-gateway")) throw new ArgumentException("Unsupported ports action.", nameof(action));
        if ((action is "ports" or "add-gateway") != (region == null) || (region != null && !RegionId.IsMatch(region))) throw new ArgumentException("Not a region id.", nameof(region));
        if (action == "add-gateway" && botProfile != null) throw new ArgumentException("add-gateway moves no bot.", nameof(botProfile));
        if ((action == "set-port") != (port != null) || port is < 1024 or > 65535) throw new ArgumentException("A port is a whole number from 1024 to 65535.", nameof(port));
        if (action == "ports" && (apply || botProfile != null)) throw new ArgumentException("ports only lists.", nameof(apply));
        if (botProfile != null && (botProfile.Length == 0 || botProfile.StartsWith('-') || botProfile.Any(char.IsControl)))
            throw new ArgumentException("Not a profile path.", nameof(botProfile));
        var step = new ProcessStartInfo(control.Python) { UseShellExecute = false, CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(group.ShardScript)!, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "-I", "-B", group.ShardScript, "--config", group.Config, action }) step.ArgumentList.Add(argument);
        if (region != null) { step.ArgumentList.Add("--region"); step.ArgumentList.Add(region); }
        if (port is { } number) { step.ArgumentList.Add("--port"); step.ArgumentList.Add(number.ToString(CultureInfo.InvariantCulture)); }
        if (botProfile != null) { step.ArgumentList.Add("--bot-profile"); step.ArgumentList.Add(botProfile); }
        if (apply) step.ArgumentList.Add("--apply");
        return step;
    }

    // The regions that can be the front door, in the group's order, with their game ports.
    public static IReadOnlyList<Choice> GateChoices(HostGroup group) {
        using var document = JsonDocument.Parse(File.ReadAllText(group.Config));
        var json = document.RootElement;
        if (json.ValueKind != JsonValueKind.Object || !json.TryGetProperty("regions", out var list) || list.ValueKind != JsonValueKind.Array)
            throw new InvalidDataException("The group config lists no regions.");
        var choices = new List<Choice>();
        foreach (var region in list.EnumerateArray().Take(16)) {
            if (region.ValueKind != JsonValueKind.Object || Str(region, "id") is not { } id || !RegionId.IsMatch(id)) continue;
            if (NoGateKinds.Contains(Str(region, "kind") ?? "")) continue;
            choices.Add(new Choice(id, Clean(Str(region, "name") ?? id, 64), Int(region, "port") ?? 0));
        }
        return choices;
    }

    public static Report ParseReport(int exit, string output) {
        Report Fail(string error) => new(false, error, null, null, [], [], [], "none", null);
        using var document = Last(output);
        if (document == null) return Fail($"The group script gave no answer (exit {exit}).");
        var json = document.RootElement;
        if (!True(json, "ok")) return Fail("Refused: " + Clean(Str(json, "refused") ?? Str(json, "error") ?? "no reason given"));
        var rows = new List<PortRow>();
        if (json.TryGetProperty("ports", out var ports) && ports.ValueKind == JsonValueKind.Array)
            foreach (var row in ports.EnumerateArray().Take(128)) {
                if (row.ValueKind != JsonValueKind.Object || Int(row, "port") is not { } port) continue;
                bool? listening = row.TryGetProperty("listening", out var up) && up.ValueKind is JsonValueKind.True or JsonValueKind.False ? up.GetBoolean() : null;
                rows.Add(new PortRow(port, Clean(Str(row, "use") ?? "", 40), Str(row, "region") is { } id && RegionId.IsMatch(id) ? id : null,
                    Str(row, "name") is { } name ? Clean(name, 64) : null, True(row, "public"), True(row, "gate"), listening));
            }
        return new Report(true, null, Str(json, "gate") is { } gate && RegionId.IsMatch(gate) ? gate : null,
            Str(json, "public_host") is { } host ? Clean(host, 64) : null, Ints(json, "public_ports"), rows, Texts(json, "problems"),
            Clean(Str(json, "host_service") ?? "none", 16), json.TryGetProperty("change", out var change) && change.ValueKind == JsonValueKind.Object ? ParseChange(change) : null);
    }

    private static Change ParseChange(JsonElement json) =>
        new(Clean(Str(json, "kind") ?? "", 16), Clean(Str(json, "phase") ?? "", 24), Str(json, "error") is { } error ? Clean(error) : null,
            True(json, "running"), True(json, "changed"), Texts(json, "log"), Texts(json, "restart_needed"),
            json.TryGetProperty("bot", out var bot) && bot.ValueKind == JsonValueKind.Object && True(bot, "restart"));

    // set-gate / set-port: {"plan": {...}, "applied": false} or, with apply, {"accepted": true, "plan": {...}}.
    public static Plan ParsePlan(int exit, string output) {
        Plan Fail(string error) => new(false, error, false, false, [], [], [], [], false);
        using var document = Last(output);
        if (document == null) return Fail($"The group script gave no answer (exit {exit}).");
        var json = document.RootElement;
        if (!True(json, "ok")) return Fail(Clean(Str(json, "refused") ?? Str(json, "error") ?? "no reason given", 900));
        if (!json.TryGetProperty("plan", out var plan) || plan.ValueKind != JsonValueKind.Object) return Fail("The group script sent no plan (an older Civ13 checkout?).");
        return new Plan(true, null, True(json, "accepted"), True(plan, "already"), Texts(plan, "steps"), Texts(plan, "problems"), Texts(plan, "warnings"),
            Ints(plan, "public_ports"), plan.TryGetProperty("bot", out var bot) && bot.ValueKind == JsonValueKind.Object && True(bot, "restart"));
    }

    public static Report RunReport(HostControl control, Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var (exit, output) = (run ?? LocalHosting.RunCaptured)(Step(control, "ports"));
        return ParseReport(exit, output);
    }

    public static Plan RunGate(HostControl control, string region, bool apply, string? botProfile = null, Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var (exit, output) = (run ?? LocalHosting.RunCaptured)(Step(control, "set-gate", region, null, apply, botProfile));
        return ParsePlan(exit, output);
    }

    // A gateway world (shard_group.py add-gateway): an always-up world that takes the front door's port for good and
    // sends every player on to their land, so the hub listing never follows a game world's restarts. Applying adds,
    // sets up and starts it beside the current front door; "Make this the front door" on it then swaps the ports.
    public static Plan RunAddGateway(HostControl control, bool apply, Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var (exit, output) = (run ?? LocalHosting.RunCaptured)(Step(control, "add-gateway", null, null, apply));
        return ParsePlan(exit, output);
    }

    public static Plan RunPort(HostControl control, string region, int port, bool apply, string? botProfile = null, Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var (exit, output) = (run ?? LocalHosting.RunCaptured)(Step(control, "set-port", region, port, apply, botProfile));
        return ParsePlan(exit, output);
    }

    // The front door in one sentence, with what the router must forward.
    public static string Summary(Report report) {
        if (!report.Ok) return report.Error ?? "No answer.";
        var gate = report.Ports.FirstOrDefault(row => row.Gate);
        var text = gate == null
            ? "This group has no routing relay: every region is joined on its own port."
            : $"Front door: {gate.Name ?? gate.Region} on port {gate.Port}. Players and the Discord Play button join here.";
        if (report.PublicPorts.Count > 0)
            text += " Ports to forward on the router: " + string.Join(", ", report.PublicPorts) + ".";
        return text;
    }

    // The plan as the dialog shows it before anything changes.
    public static string Describe(Plan plan) {
        if (!plan.Ok) return "Cannot do that: " + plan.Error;
        var text = new StringBuilder();
        if (plan.Problems.Count > 0) {
            text.AppendLine("This cannot run yet:");
            foreach (var problem in plan.Problems) text.AppendLine("  - " + problem);
            text.AppendLine();
        }
        text.AppendLine(plan.Accepted ? "Started. What happens:" : "What will happen:");
        foreach (var step in plan.Steps) text.AppendLine("  - " + step);
        foreach (var warning in plan.Warnings) text.AppendLine("Note: " + warning);
        if (!plan.Accepted && plan.Problems.Count == 0) text.AppendLine("Nothing has changed yet.");
        return text.ToString().TrimEnd();
    }

    private static readonly Dictionary<string, string> Phases = new() {
        ["accepted"] = "Starting...", ["stopping"] = "Saving and stopping the worlds that move...", ["writing"] = "Writing the new settings...",
        ["host service"] = "Waiting for the host service to load the new ports...", ["starting"] = "Starting the worlds on their new ports...",
        ["telling"] = "Telling the running worlds...", ["done"] = "Done.", ["failed"] = "Failed.",
    };

    // The running or last change in plain words, for the dialog's progress box.
    public static string Describe(Change change) {
        var text = new StringBuilder(Phases.GetValueOrDefault(change.Phase, change.Phase));
        if (change.Phase == "failed") {
            text.Append(' ').Append(change.Error ?? "No reason was recorded.");
            text.AppendLine().Append(change.Changed
                ? "The new settings are written. Fix the cause and press the button again: it carries on from here."
                : "Nothing was changed.");
        } else if (!change.Running && change.Phase != "done")
            text.AppendLine().Append("Its worker is no longer running. Press the button again to carry on.");
        foreach (var line in change.Log) text.AppendLine().Append("  - ").Append(line);
        if (change.Phase == "done" && change.RestartNeeded.Count > 0)
            text.AppendLine().Append("These regions run an older build and learn the new ports at their next restart: " + string.Join(", ", change.RestartNeeded) + ".");
        return text.ToString();
    }

    public static bool Finished(Change? change) => change == null || change.Phase is "done" or "failed" || !change.Running;

    private static JsonDocument? Last(string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{')) ?? "";
        try {
            var document = JsonDocument.Parse(line);
            if (document.RootElement.ValueKind == JsonValueKind.Object) return document;
            document.Dispose();
        } catch (JsonException) { }
        return null;
    }

    private static List<string> Texts(JsonElement json, string name) =>
        json.TryGetProperty(name, out var list) && list.ValueKind == JsonValueKind.Array
            ? list.EnumerateArray().Where(item => item.ValueKind == JsonValueKind.String).Select(item => Clean(item.GetString()!, 600)).Take(64).ToList() : [];

    private static List<int> Ints(JsonElement json, string name) =>
        json.TryGetProperty(name, out var list) && list.ValueKind == JsonValueKind.Array
            ? list.EnumerateArray().Where(item => item.ValueKind == JsonValueKind.Number && item.TryGetInt32(out var port) && port is > 0 and < 65536)
                .Select(item => item.GetInt32()).Take(64).ToList() : [];

    private static int? Int(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var port) && port is > 0 and < 65536 ? port : null;

    private static bool True(JsonElement json, string name) => json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True;

    private static string Clean(string text, int limit = 300) {
        var clean = new StringBuilder();
        foreach (var c in text) if (!char.IsControl(c)) clean.Append(c);
        return clean.Length > limit ? clean.ToString(0, limit) : clean.ToString();
    }

    private static string? Str(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
}
