using System.Text.Json;

namespace Civ13.Launcher;

// The "Ask for help" (Player Help) bridges of the region group, which the host service keeps running
// (shard_group.py help-status / help-start / help-stop, configured by "player_help" in the group config).
// Wanted: the host service keeps it running (null from an older shard_group.py, which listed only those).
public sealed record HelpRegion(string Id, bool Running, int? Pid, bool Enabled, int? HeartbeatAgeSeconds, string? Log, bool? Wanted = null) {
    // The bridge rewrites health.json every second or so while it runs; an old one means it is stuck.
    public bool Stale => Running && HeartbeatAgeSeconds is > 60;

    public string Describe() {
        if (!Running) return Wanted == false ? "stopped (Start region to run it)" : "not running";
        var line = $"running (PID {Pid})";
        if (HeartbeatAgeSeconds is { } age) line += age > 60 ? $", no heartbeat for {age} s" : ", answering";
        if (!Enabled) line += ", help switched off in its config";
        if (Wanted == false) line += ", stopping";
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
                foreach (var entry in list.EnumerateObject().Take(16)) {
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
                return "Player help stopped" + (Names(json, "stopped") is { Count: > 0 } stopped ? " (" + string.Join(", ", stopped) + ")" : "") +
                    (forced.Count > 0 ? "; ended without finishing: " + string.Join(", ", forced) : "") + ".";
            }
            var errors = json.TryGetProperty("errors", out var list) && list.ValueKind == JsonValueKind.Object
                ? list.EnumerateObject().Where(e => e.Value.ValueKind == JsonValueKind.String).Select(e => $"{e.Name}: {e.Value.GetString()}").ToList() : [];
            var started = Names(json, "started");
            return (started.Count > 0 ? "Player help started (" + string.Join(", ", started) + ")." : "Player help is running.") +
                (errors.Count > 0 ? " Could not start " + string.Join("; ", errors) + "." : "");
        } catch (JsonException) { return $"Player help: exit {exit}"; }
    }

    private static List<string> Names(JsonElement json, string name) =>
        json.TryGetProperty(name, out var list) && list.ValueKind == JsonValueKind.Array
            ? list.EnumerateArray().Where(item => item.ValueKind == JsonValueKind.String).Select(item => item.GetString()!).ToList() : [];

    private static int? Int(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number) ? number : null;
}
