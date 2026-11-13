using System.Globalization;
using System.Text;
using System.Text.Json;

namespace Civ13.Launcher;

// What the Host server tab's region board shows for each server: three separate answers an operator
// needs at a glance. Is it running (Run), is its build current (Build), and is anything wrong (Problem).
// Parsed from the same shard_group.py / gaia_host.py status and check-update lines as the text status.
public enum RegionRun { Running, Asleep, Stopped, Working, Unknown }
public enum RegionBuild { Unknown, Current, Behind, Built, Building, Failed }

// RunText and BuildText are the short labels ("Running", "3 behind"); Activity is what a working region is
// doing right now ("update: compiling"); Notes is the quiet rest of the status (port, epoch, last action);
// Problem is null unless something needs the operator.
public sealed record RegionCard(string Id, string Name, bool Mainland, RegionRun Run, string RunText, int? Players,
    RegionBuild Build, string BuildText, string? Activity, string Notes, string? Problem) {
    // Everything on one line, for a tooltip, the log and screen readers.
    public string Describe() {
        var text = Name + ": " + RunText.ToLowerInvariant();
        if (Activity != null) text += " (" + Activity + ")";
        if (Players is { } players) text += ", " + (players == 1 ? "1 player" : players + " players");
        text += ", build " + BuildText.ToLowerInvariant();
        if (Notes.Length > 0) text += ", " + Notes;
        return Problem == null ? text + "." : text + ". " + Problem;
    }
}

public sealed record BoardCount(string Kind, int Count, string Text);

public static class HostBoard {
    // check-update's "regions": how many commits each region's build is behind the group revision.
    // Empty when the line is missing or refused, so the board says "Not checked" instead of guessing.
    public static IReadOnlyDictionary<string, int> RegionsBehind(string checkOutput) {
        var behind = new Dictionary<string, int>();
        if (LastObject(checkOutput) is not { } document) return behind;
        using (document) {
            var json = document.RootElement;
            if (!Bool(json, "ok") || !json.TryGetProperty("regions", out var regions) || regions.ValueKind != JsonValueKind.Object) return behind;
            foreach (var region in regions.EnumerateObject().Take(16))
                if (region.Value.ValueKind == JsonValueKind.Object && region.Value.TryGetProperty("behind", out var count)
                        && count.ValueKind == JsonValueKind.Number && count.TryGetInt32(out var commits) && commits >= 0)
                    behind[region.Name] = commits;
        }
        return behind;
    }

    // One card per region of shard_group.py status, in the group's order. mainland: that region's id.
    // behind: RegionsBehind of the last check-update, or null before any check has answered.
    public static IReadOnlyList<RegionCard> Regions(string statusOutput, IReadOnlyDictionary<string, int>? behind, string? mainland = null) {
        var cards = new List<RegionCard>();
        if (LastObject(statusOutput) is not { } document) return cards;
        using (document) {
            var json = document.RootElement;
            if (!Bool(json, "ok") || !json.TryGetProperty("regions", out var regions) || regions.ValueKind != JsonValueKind.Object) return cards;
            foreach (var region in regions.EnumerateObject().Take(16)) {
                if (region.Value.ValueKind != JsonValueKind.Object) continue;
                int? commits = behind != null && behind.TryGetValue(region.Name, out var count) ? count : null;
                cards.Add(Card(region.Name, Clean(Str(region.Value, "name") ?? region.Name), region.Name == mainland, region.Value, commits));
            }
        }
        return cards;
    }

    // The single server of gaia_host.py status (no region group), or null when the line is not a status.
    public static RegionCard? Server(string name, string statusOutput, int? behind) {
        if (LastObject(statusOutput) is not { } document) return null;
        using (document) {
            var json = document.RootElement;
            return Bool(json, "ok") && Str(json, "state") != null ? Card("server", Clean(name), false, json, behind) : null;
        }
    }

    // False while the group has travel and its coordinator is down; null when the group has no travel.
    public static bool? Coordinator(string statusOutput) {
        if (LastObject(statusOutput) is not { } document) return null;
        using (document)
            return document.RootElement.TryGetProperty("coordinator", out var value) && value.ValueKind is JsonValueKind.True or JsonValueKind.False
                ? value.GetBoolean() : null;
    }

    public static RegionCard Card(string id, string name, bool mainland, JsonElement entry, int? behind) {
        var state = Str(entry, "state") ?? "unknown";
        var listening = Bool(entry, "listening") || state == "awake";
        var problems = new List<string>();
        var notes = new List<string>();
        int? players = null;
        var loading = false;
        if (entry.TryGetProperty("world", out var world) && world.ValueKind == JsonValueKind.Object) {
            if (world.TryGetProperty("clients", out var clients) && clients.ValueKind == JsonValueKind.Number && clients.TryGetInt32(out var count)) players = count;
            if (Str(world, "error") is { Length: > 0 } worldError) problems.Add("World error: " + Short(worldError));
            // gaia_host.py reports ready as 1/0 or true/false.
            loading = world.TryGetProperty("ready", out var ready) && (ready.ValueKind == JsonValueKind.False
                || (ready.ValueKind == JsonValueKind.Number && ready.TryGetInt32(out var flag) && flag == 0));
        }
        if (Str(entry, "error") is { Length: > 0 } statusError) problems.Add("Status unavailable: " + Short(statusError));

        string? working = null;
        if (entry.TryGetProperty("operation", out var operation) && operation.ValueKind == JsonValueKind.Object
                && Str(operation, "action") is { } action && Str(operation, "phase") is { } phase) {
            var act = Words(action);
            if (Str(operation, "error") is { Length: > 0 } failed) problems.Add(Capital(act) + " failed: " + Short(failed));
            else if (Bool(entry, "busy")) working = act + ": " + Words(phase);
            else notes.Add("last " + act + " " + Words(phase));
        } else if (Bool(entry, "busy")) working = "an action is running";
        if (entry.TryGetProperty("standby", out var standby) && standby.ValueKind == JsonValueKind.Object) {
            working ??= "handing over";
            notes.Add(Bool(standby, "listening") ? "new build running beside it" : "new build starting beside it");
        }

        var (build, buildText) = Build(entry, behind, problems, notes);

        if (entry.TryGetProperty("watchdog", out var watchdog) && watchdog.ValueKind == JsonValueKind.Object) {
            var restarts = watchdog.TryGetProperty("restarts", out var list) && list.ValueKind == JsonValueKind.Array ? list.GetArrayLength() : 0;
            var last = Str(watchdog, "last_event") is { } kind ? Words(kind) : "a crash";
            if (watchdog.TryGetProperty("gave_up", out _)) problems.Add($"Watchdog gave up after repeated restarts ({last}); start it by hand");
            else if (!listening && Str(watchdog, "last_refusal") is { Length: > 0 } refusal) problems.Add("Watchdog could not restart it: " + Short(refusal));
            else if (Bool(watchdog, "cold")) notes.Add("watchdog left it asleep (low memory)");
            else if (restarts > 0) notes.Add($"watchdog restarted it {restarts} time{(restarts == 1 ? "" : "s")} recently (last: {last})");
        }
        if (entry.TryGetProperty("transfer_agent", out var agent) && agent.ValueKind == JsonValueKind.False) {
            // A world that is up without its travel agent strands travellers; a stopped one just has none yet.
            if (listening) problems.Add("Travel agent not running");
            else notes.Add("travel agent not running");
        }
        if (entry.TryGetProperty("region_view", out var view) && view.ValueKind == JsonValueKind.Object) {
            if (Str(view, "error") != null) problems.Add("Not answering as this region");
            else {
                if (view.TryGetProperty("epoch", out var epoch) && epoch.ValueKind == JsonValueKind.Object && epoch.TryGetProperty("ordinal", out var ordinal)
                        && ordinal.ValueKind == JsonValueKind.Number && ordinal.TryGetInt32(out var index) && index >= 0 && index < LocalHosting.EpochNames.Length)
                    notes.Insert(0, "epoch " + LocalHosting.EpochNames[index]);
                if (Str(view, "battle_phase") is { Length: > 0 } battle) notes.Insert(0, "battle " + LocalHosting.BattlePhase(battle));
            }
        }
        if (entry.TryGetProperty("port", out var portValue) && portValue.ValueKind == JsonValueKind.Number && portValue.TryGetInt32(out var port) && port is > 0 and < 65536)
            notes.Insert(0, "port " + port);

        if (working == null && state == "awake" && loading) working = "loading the world";
        var (run, runText) = working != null ? (RegionRun.Working, "Working") : state switch {
            "awake" => (RegionRun.Running, "Running"),
            "asleep" => (RegionRun.Asleep, "Asleep"),
            "cold" => (RegionRun.Asleep, "Asleep (saved)"),
            "stopped" => (RegionRun.Stopped, "Stopped"),
            _ => (RegionRun.Unknown, "Unknown"),
        };
        if (state == "cold") notes.Add("stopped after its last save; a wake or travel starts it");
        return new RegionCard(id, name, mainland, run, runText, players, build, buildText, working, string.Join(", ", notes),
            problems.Count == 0 ? null : string.Join(". ", problems) + ".");
    }

    // The staged build wins over the commit count: it is what the operator acts on next.
    private static (RegionBuild, string) Build(JsonElement entry, int? behind, List<string> problems, List<string> notes) {
        if (entry.TryGetProperty("stage", out var stage) && stage.ValueKind == JsonValueKind.Object && Str(stage, "phase") is { } phase) {
            if (phase == "failed") {
                problems.Add("Update build failed" + (Str(stage, "error") is { Length: > 0 } failed ? ": " + Short(failed) : ""));
                return (RegionBuild.Failed, "Build failed");
            }
            if (phase == "ready" && Bool(stage, "pending")) {
                notes.Add(Str(stage, "install") is { } install && install.StartsWith("not installed") ? Short(install) : "ready to hand over");
                return (RegionBuild.Built, "Update built");
            }
            if (phase is not ("ready" or "current")) {
                notes.Add("building update: " + Words(phase));
                return (RegionBuild.Building, "Building");
            }
        }
        return behind switch {
            null => (RegionBuild.Unknown, "Not checked"),
            0 => (RegionBuild.Current, "Up to date"),
            { } commits => (RegionBuild.Behind, commits + " behind"),
        };
    }

    // The counts above the board, most urgent first; kinds: problem, working, behind, running, asleep, stopped, players.
    public static IReadOnlyList<BoardCount> Summary(IReadOnlyList<RegionCard> cards) {
        var counts = new List<BoardCount>();
        void Add(string kind, int count, string text) { if (count > 0) counts.Add(new BoardCount(kind, count, text)); }
        var problems = cards.Count(card => card.Problem != null);
        Add("problem", problems, problems == 1 ? "1 problem" : problems + " problems");
        Add("working", cards.Count(card => card.Run == RegionRun.Working), cards.Count(card => card.Run == RegionRun.Working) + " working");
        var behind = cards.Count(card => card.Build is RegionBuild.Behind or RegionBuild.Built or RegionBuild.Failed or RegionBuild.Building);
        Add("behind", behind, behind + " out of date");
        Add("running", cards.Count(card => card.Run == RegionRun.Running), cards.Count(card => card.Run == RegionRun.Running) + " running");
        Add("asleep", cards.Count(card => card.Run == RegionRun.Asleep), cards.Count(card => card.Run == RegionRun.Asleep) + " asleep");
        Add("stopped", cards.Count(card => card.Run == RegionRun.Stopped), cards.Count(card => card.Run == RegionRun.Stopped) + " stopped");
        var unknown = cards.Count(card => card.Run == RegionRun.Unknown);
        Add("unknown", unknown, unknown + " unknown");
        var players = cards.Sum(card => card.Players ?? 0);
        Add("players", players, players == 1 ? "1 player online" : players + " players online");
        return counts;
    }

    private static JsonDocument? LastObject(string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{'));
        if (line == null) return null;
        try {
            var document = JsonDocument.Parse(line);
            if (document.RootElement.ValueKind == JsonValueKind.Object) return document;
            document.Dispose();
        } catch (JsonException) { }
        return null;
    }

    private static string? Str(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
    private static bool Bool(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True;
    private static string Short(string text) {
        text = string.Join(' ', text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries)).TrimEnd('.');
        return text.Length > 200 ? text[..200] : text;
    }
    private static string Capital(string text) => text.Length == 0 ? text : char.ToUpperInvariant(text[0]) + text[1..];

    // Lowercase letters, apostrophes and single spaces only (64 at most), as LocalHosting shows a phase name.
    private static string Words(string text) {
        var kept = new string(text.Take(64).Select(c => char.IsAsciiLetterLower(c) || c == '\'' ? c : ' ').ToArray());
        return string.Join(' ', kept.Split(' ', StringSplitOptions.RemoveEmptyEntries));
    }

    private static string Clean(string name) => string.Concat(name.EnumerateRunes().Where(r => Rune.IsLetterOrDigit(r)
        || Rune.GetUnicodeCategory(r) is UnicodeCategory.NonSpacingMark or UnicodeCategory.SpacingCombiningMark or UnicodeCategory.EnclosingMark
        || (r.IsAscii && " -'().".Contains((char)r.Value))).Take(64).Select(r => r.ToString()));
}
