using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Civ13.Launcher;

// The Host tab's Player activity window (All regions > More): who is active, sessions, retention, deaths,
// travel, research and crafting progress, feature use and lag by player count (Civ13 docs/player-activity.md).
// shard_group.py activity reads new lines from every region into <group root>/player-activity.sqlite, then
// answers with the report text. Account keys only: no IPs, computer ids, chat or positions are recorded.
public static class PlayerActivity {
    public sealed record Answer(bool Ok, string? Error, string Text, IReadOnlyList<string> Recording, IReadOnlyList<string> Off,
        int Read, int ActiveToday, int ActiveWeek, string? Database);

    private static readonly Regex Region = new("^[A-Za-z0-9_-]{1,40}$");
    private const int MaxText = 60000;

    public static ProcessStartInfo Step(HostControl control) {
        var group = control.Group ?? throw new InvalidOperationException("No region group configured.");
        var step = new ProcessStartInfo(control.Python) { UseShellExecute = false, CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(group.ShardScript)!, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "-I", "-B", group.ShardScript, "--config", group.Config, "activity" }) step.ArgumentList.Add(argument);
        return step;
    }

    // shard_group.py activity: {"ok", "db", "read", "recording": [id], "off": [id], "active": {"day", "week", "month"}, "text"}
    public static Answer Parse(int exit, string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{')) ?? "";
        JsonDocument? document;
        try { document = JsonDocument.Parse(line); } catch (JsonException) { document = null; }
        using (document) {
            if (document == null || document.RootElement.ValueKind != JsonValueKind.Object)
                return Failed($"The group script gave no answer (exit {exit}).");
            var json = document.RootElement;
            if (!(json.TryGetProperty("ok", out var ok) && ok.ValueKind == JsonValueKind.True))
                return Failed("Refused: " + Clean(Str(json, "refused") ?? Str(json, "error") ?? "no reason given", 300, false));
            var active = json.TryGetProperty("active", out var a) && a.ValueKind == JsonValueKind.Object ? a : default;
            return new Answer(true, null, Clean(Str(json, "text") ?? "", MaxText, true), Regions(json, "recording"), Regions(json, "off"),
                Int(json, "read"), Int(active, "day"), Int(active, "week"), Str(json, "db") is { } db ? Clean(db, 300, false) : null);
        }
    }

    public static Answer Run(HostControl control, Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var (exit, output) = (run ?? LocalHosting.RunCaptured)(Step(control));
        return Parse(exit, output);
    }

    // One line above the report: which regions record, and how to switch the rest on.
    public static string Describe(Answer answer) {
        if (!answer.Ok) return answer.Error ?? "No answer.";
        var lines = new List<string>();
        lines.Add(answer.Recording.Count == 0
            ? "No region is recording. Add the line PLAYER_ACTIVITY 1 to a region's config/config.local.txt and restart it to start."
            : "Recording: " + string.Join(", ", answer.Recording) + (answer.Off.Count > 0 ? ". Off: " + string.Join(", ", answer.Off) : "") + ".");
        lines.Add($"Active today {answer.ActiveToday}, this week {answer.ActiveWeek}. Read {answer.Read} new lines just now.");
        return string.Join(Environment.NewLine, lines);
    }

    private static Answer Failed(string error) => new(false, error, "", [], [], 0, 0, 0, null);

    private static List<string> Regions(JsonElement json, string name) =>
        json.TryGetProperty(name, out var list) && list.ValueKind == JsonValueKind.Array
            ? list.EnumerateArray().Where(r => r.ValueKind == JsonValueKind.String && Region.IsMatch(r.GetString()!)).Select(r => r.GetString()!).Take(64).ToList() : [];

    private static int Int(JsonElement json, string name) =>
        json.ValueKind == JsonValueKind.Object && json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var n) ? Math.Max(0, n) : 0;

    // The report is plain text: keep new lines (as Windows line ends for a TextBox), drop other control characters.
    private static string Clean(string text, int limit, bool lines) {
        var clean = new StringBuilder();
        foreach (var c in text) {
            if (c == '\n' && lines) clean.Append(Environment.NewLine);
            else if (!char.IsControl(c)) clean.Append(c);
            if (clean.Length >= limit) break;
        }
        return clean.ToString();
    }
    private static string? Str(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
}
