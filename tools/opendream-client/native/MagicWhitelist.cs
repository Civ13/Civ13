using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Civ13.Launcher;

// The Host tab's Magic whitelist dialog (All regions > More): who may follow a god and learn magic on
// persistent worlds (Civ13 code/modules/divine/magic_whitelist.dm). shard_group.py magic-whitelist lists,
// adds and removes keys in the one file every region reads; worlds reread it within 30 seconds.
public static class MagicWhitelist {
    public sealed record Answer(bool Ok, string? Error, IReadOnlyList<string> Keys, IReadOnlyList<string> Added, IReadOnlyList<string> Removed, string? File);

    // shard_group.py CKEY_LIST for one key; at most 20 keys per change.
    private static readonly Regex Key = new("^[A-Za-z0-9_ .@-]{1,32}$");
    private static readonly Regex Ckey = new("^[a-z0-9@]{1,32}$");

    // add/remove: null to leave alone. Neither: only list.
    public static ProcessStartInfo Step(HostControl control, IReadOnlyList<string>? add = null, IReadOnlyList<string>? remove = null) {
        var group = control.Group ?? throw new InvalidOperationException("No region group configured.");
        var step = new ProcessStartInfo(control.Python) { UseShellExecute = false, CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(group.ShardScript)!, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "-I", "-B", group.ShardScript, "--config", group.Config, "magic-whitelist" }) step.ArgumentList.Add(argument);
        foreach (var (flag, keys) in new[] { ("--add", add), ("--remove", remove) }) {
            if (keys == null) continue;
            if (keys.Count is < 1 or > 20 || keys.Any(key => !Key.IsMatch(key) || key.Trim().Length == 0 || key.StartsWith('-')))
                throw new ArgumentException("Give 1 to 20 player keys (letters, digits, spaces, _ . @ -).", nameof(keys));
            step.ArgumentList.Add(flag);
            step.ArgumentList.Add(string.Join(",", keys.Select(key => key.Trim())));
        }
        return step;
    }

    // Player keys typed into one box, separated by commas or new lines (a BYOND key may hold spaces).
    public static List<string> SplitKeys(string text) =>
        text.Split(new[] { ',', '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries).Select(key => key.Trim()).Where(key => key.Length > 0).Distinct().ToList();

    // shard_group.py magic-whitelist: {"ok", "file", "keys": [ckey], "added": [ckey], "removed": [ckey]}
    public static Answer Parse(int exit, string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{')) ?? "";
        JsonDocument? document;
        try { document = JsonDocument.Parse(line); } catch (JsonException) { document = null; }
        using (document) {
            if (document == null || document.RootElement.ValueKind != JsonValueKind.Object)
                return new Answer(false, $"The group script gave no answer (exit {exit}).", [], [], [], null);
            var json = document.RootElement;
            if (!(json.TryGetProperty("ok", out var ok) && ok.ValueKind == JsonValueKind.True))
                return new Answer(false, "Refused: " + Short(Str(json, "refused") ?? Str(json, "error") ?? "no reason given"), [], [], [], null);
            return new Answer(true, null, Keys(json, "keys"), Keys(json, "added"), Keys(json, "removed"), Str(json, "file") is { } file ? Short(file) : null);
        }
    }

    public static Answer Run(HostControl control, IReadOnlyList<string>? add = null, IReadOnlyList<string>? remove = null,
            Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var (exit, output) = (run ?? LocalHosting.RunCaptured)(Step(control, add, remove));
        return Parse(exit, output);
    }

    private static List<string> Keys(JsonElement json, string name) =>
        json.TryGetProperty(name, out var list) && list.ValueKind == JsonValueKind.Array
            ? list.EnumerateArray().Where(k => k.ValueKind == JsonValueKind.String && Ckey.IsMatch(k.GetString()!)).Select(k => k.GetString()!).Take(2000).ToList() : [];

    private static string Short(string text) {
        var clean = new StringBuilder();
        foreach (var c in text) if (!char.IsControl(c)) clean.Append(c);
        return clean.Length > 300 ? clean.ToString(0, 300) : clean.ToString();
    }
    private static string? Str(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
}
