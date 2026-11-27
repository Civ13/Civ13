using System.Text.Json;

namespace Civ13.Launcher;

// The per-region "Ask for help" status. A host can use one Python process for several regional queues.
// (shard_group.py help-status / help-start / help-stop, configured by "player_help" in the group config).
// Wanted: the host service keeps it running (null from an older shard_group.py, which listed only those).
public sealed record HelpRegion(string Id, bool Running, int? Pid, bool Enabled, int? HeartbeatAgeSeconds, string? Log, bool? Wanted = null) {
    // The bridge rewrites health.json every second or so while it runs; an old one means it is stuck.
    public bool Stale => Running && HeartbeatAgeSeconds is > 60;

    public string Describe() {
        if (!Running) return Wanted == false ? "stopped (Start region to run it)" : "not running";
        var line = $"running (PID {Pid})";
        if (HeartbeatAgeSeconds is { } age) line += age > 60 ? $", no heartbeat for {age} s" : ", answering";
        if (Wanted == false) line += ", stopping";
        else if (!Enabled) line += ", not accepting questions";
        return line;
    }
}

public sealed record HelpStatus(bool Ok, bool Configured, bool Stopped, IReadOnlyList<HelpRegion> Regions, string? Error) {
    public bool AnyRunning => Regions.Any(region => region.Running);

    public string Describe() {
        if (!Ok) return "Status unavailable: " + (Error ?? "no answer");
        if (!Configured) return "Not configured: add \"player_help\": {\"config\": \"...\"} to the group config so the host service runs it.";
        var head = Stopped ? "Stopped on request; the host service leaves it stopped until Start." : "Kept running by the host service (a region stopped on request stays stopped).";
        return head + Environment.NewLine + string.Join(Environment.NewLine, Regions.Select(region => $"{region.Id}: {region.Describe()}"));
    }
}

public static class LocalHelp {
    public static HelpStatus ParseStatus(int exit, string output) {
        HelpStatus Fail(string error) => new(false, false, false, [], error);
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{'));
        if (line == null) return Fail(LocalBot.FailureText(exit, output));
        try {
            using var document = JsonDocument.Parse(line);
            var json = document.RootElement;
            if (json.ValueKind != JsonValueKind.Object || !json.TryGetProperty("ok", out var ok) || ok.ValueKind != JsonValueKind.True)
                return Fail(json.ValueKind == JsonValueKind.Object ? LocalBot.Str(json, "error") ?? LocalBot.Str(json, "refused") ?? $"exit {exit}" : $"exit {exit}");
            if (!LocalBot.Bool(json, "configured")) return new HelpStatus(true, false, false, [], null);
            var regions = new List<HelpRegion>();
            if (json.TryGetProperty("regions", out var list) && list.ValueKind == JsonValueKind.Object) {
                foreach (var entry in list.EnumerateObject().Take(LocalHosting.MaxRegions)) {
                    var region = entry.Value;
                    if (region.ValueKind != JsonValueKind.Object) continue;
                    regions.Add(new HelpRegion(entry.Name, LocalBot.Bool(region, "running"), Int(region, "pid"), LocalBot.Bool(region, "enabled"),
                        Int(region, "heartbeat_age_seconds"), LocalBot.Str(region, "log"),
                        region.TryGetProperty("wanted", out var wanted) && wanted.ValueKind is JsonValueKind.True or JsonValueKind.False ? wanted.GetBoolean() : null));
                }
            }
            return new HelpStatus(true, true, LocalBot.Bool(json, "stopped"), regions, null);
        } catch (JsonException) { return Fail($"exit {exit}"); }
    }

    // help-start and help-stop: one line for the window.
    public static string DescribeAction(string action, int exit, string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{'));
        if (line == null) return "Player help: " + LocalBot.FailureText(exit, output);
        try {
            using var document = JsonDocument.Parse(line);
            var json = document.RootElement;
            if (json.ValueKind != JsonValueKind.Object) return $"Player help: exit {exit}";
            if (!LocalBot.Bool(json, "ok")) return "Player help: " + (LocalBot.Str(json, "refused") ?? LocalBot.Str(json, "error") ?? $"exit {exit}");
            if (action == "help-stop") {
                var forced = Names(json, "forced");
                var stopped = Names(json, "stopped");
                var pending = Problems(json, "not_ended");
                var outcome = "Player help stopped" + (stopped.Count > 0 ? " (" + string.Join(", ", stopped) + ")" : "") +
                    (forced.Count > 0 ? "; ended without finishing: " + string.Join(", ", forced) : "") + ".";
                if (pending.Count == 0) return outcome;
                var waiting = "Player help stop pending: " + string.Join("; ", pending) + ".";
                return stopped.Count > 0 || forced.Count > 0 ? waiting + " " + outcome : waiting;
            }
            var errors = Problems(json, "errors");
            var started = Names(json, "started");
            if (started.Count == 0 && errors.Count > 0) return "Player help could not start: " + string.Join("; ", errors) + ".";
            return (started.Count > 0 ? "Player help start requested (" + string.Join(", ", started) + ")." : "Player help settings applied.") +
                (errors.Count > 0 ? " Could not start " + string.Join("; ", errors) + "." : "");
        } catch (JsonException) { return $"Player help: exit {exit}"; }
    }

    private static List<string> Problems(JsonElement json, string name) =>
        json.TryGetProperty(name, out var entries) && entries.ValueKind == JsonValueKind.Object
            ? entries.EnumerateObject().Where(e => e.Value.ValueKind == JsonValueKind.String).Select(e => $"{e.Name}: {e.Value.GetString()}").ToList() : [];

    private static List<string> Names(JsonElement json, string name) =>
        json.TryGetProperty(name, out var list) && list.ValueKind == JsonValueKind.Array
            ? list.EnumerateArray().Where(item => item.ValueKind == JsonValueKind.String).Select(item => item.GetString()!).ToList() : [];

    private static int? Int(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number) ? number : null;
}
