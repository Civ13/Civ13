using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Civ13.Launcher;

// The Host tab's Player records window (All regions > More): the shared player records every region reads
// (notes, warnings, bans, watchlist, memos; Civ13 tools/transfer_storage/records.py). shard_group.py records
// answers a summary, every record about one player key, a search, or writes an export file. Read-only:
// staff add and remove records in game, on any region.
public static class PlayerRecords {
    public sealed record Answer(bool Ok, string? Error, string Text, int Exported, string? File);

    // A BYOND key (shard_group.py canonical_ckey keeps letters, digits and @); a search of 1 to 64 printable characters.
    private static readonly Regex Key = new("^[A-Za-z0-9_ .@-]{1,32}$");
    private const int MaxText = 200000;

    // At most one of ckey, search or export. None: the summary.
    public static ProcessStartInfo Step(HostControl control, string? ckey = null, string? search = null, string? export = null) {
        var group = control.Group ?? throw new InvalidOperationException("No region group configured.");
        if (new[] { ckey, search, export }.Count(value => value != null) > 1)
            throw new ArgumentException("Look up one player, search, or export: one at a time.");
        var step = new ProcessStartInfo(control.Python) { UseShellExecute = false, CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(group.ShardScript)!, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "-I", "-B", group.ShardScript, "--config", group.Config, "records" }) step.ArgumentList.Add(argument);
        if (ckey != null) {
            ckey = ckey.Trim();
            if (!Key.IsMatch(ckey) || ckey.StartsWith('-')) throw new ArgumentException("Type one player key (letters, digits, spaces, _ . @ -).", nameof(ckey));
            step.ArgumentList.Add("--ckey");
            step.ArgumentList.Add(ckey);
        } else if (search != null) {
            search = search.Trim();
            if (search.Length is < 1 or > 64 || search.Any(char.IsControl) || search.StartsWith('-'))
                throw new ArgumentException("Search for 1 to 64 characters.", nameof(search));
            step.ArgumentList.Add("--search");
            step.ArgumentList.Add(search);
        } else if (export != null) {
            if (!Path.IsPathRooted(export) || !export.EndsWith(".json", StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Export to a full path ending in .json.", nameof(export));
            step.ArgumentList.Add("--export");
            step.ArgumentList.Add(export);
        }
        return step;
    }

    // shard_group.py records: {"ok", "db", "regions": {...}, "text", ["exported", "file"]}
    public static Answer Parse(int exit, string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{')) ?? "";
        JsonDocument? document;
        try { document = JsonDocument.Parse(line); } catch (JsonException) { document = null; }
        using (document) {
            if (document == null || document.RootElement.ValueKind != JsonValueKind.Object)
                return new Answer(false, $"The group script gave no answer (exit {exit}).", "", 0, null);
            var json = document.RootElement;
            if (!(json.TryGetProperty("ok", out var ok) && ok.ValueKind == JsonValueKind.True))
                return new Answer(false, "Refused: " + Clean(Str(json, "refused") ?? Str(json, "error") ?? "no reason given", 300, false), "", 0, null);
            var exported = json.TryGetProperty("exported", out var n) && n.ValueKind == JsonValueKind.Number && n.TryGetInt32(out var count) ? Math.Max(0, count) : 0;
            return new Answer(true, null, Clean(Str(json, "text") ?? "", MaxText, true), exported, Str(json, "file") is { } file ? Clean(file, 300, false) : null);
        }
    }

    public static Answer Run(HostControl control, string? ckey = null, string? search = null, string? export = null,
            Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var (exit, output) = (run ?? LocalHosting.RunCaptured)(Step(control, ckey, search, export));
        return Parse(exit, output);
    }

    // Plain text for a TextBox: keep new lines (as Windows line ends), drop other control characters.
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
