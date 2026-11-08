using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Civ13.Launcher;

// The host's own settings for a region group: the files its overlays keep outside git
// (scripts/shard-group/README.md, "Host config settings"). The repository's config/config.txt
// stays the default; an overlay's config/config.local.txt holds only this host's lines, and
// shard_group.py merges the group overlay's, then the region's, over it on every update and on
// config-apply. Editing here never touches the checkout, so a pull or update cannot clobber it.
public static class HostSettings {
    // Region null: the group overlay, shared by every region.
    public sealed record Location(string Label, string Folder, string? Region);

    public const string LocalConfig = "config/config.local.txt";
    public static readonly string[] Offered = [LocalConfig, "config/host.txt"];
    // Earlier versions an overlay keeps (shard_group.py KEPT_COPY); they are never offered or copied.
    private static readonly Regex Kept = new(@"\.(previous|migrated)$|\.bak(-|$)");
    // Files shard_group.py setup writes for each region; an overlay must not hold them (GENERATED).
    private static readonly string[] Generated = ["config/shard_region.json", "config/lifecycle-token.txt", "config/lifecycle-revision.txt",
        "config/transfer-token.txt", "config/transfer_agent.json", "config/relay-token.txt"];
    private static readonly Regex SettingName = new("^[A-Za-z][A-Za-z0-9_]*$");
    private static readonly Regex RegionId = new("^[a-z0-9][a-z0-9_-]{0,31}$");

    // The group overlay first (if the group config names one), then each region's, in the config's order.
    public static IReadOnlyList<Location> Locations(HostGroup group) {
        using var document = JsonDocument.Parse(File.ReadAllText(group.Config));
        var json = document.RootElement;
        var found = new List<Location>();
        if (Overlay(json) is { } shared) found.Add(new Location("Every region (shared)", shared, null));
        if (json.TryGetProperty("regions", out var regions) && regions.ValueKind == JsonValueKind.Array)
            foreach (var region in regions.EnumerateArray().Take(16)) {
                if (region.ValueKind != JsonValueKind.Object || !region.TryGetProperty("id", out var idJson) || idJson.ValueKind != JsonValueKind.String) continue;
                var id = idJson.GetString()!;
                if (!RegionId.IsMatch(id) || Overlay(region) is not { } folder) continue;
                var name = region.TryGetProperty("name", out var nameJson) && nameJson.ValueKind == JsonValueKind.String ? nameJson.GetString()! : id;
                found.Add(new Location(Clean(name) + " only", folder, id));
            }
        return found;
    }

    private static string? Overlay(JsonElement json) =>
        json.TryGetProperty("overlay", out var overlay) && overlay.ValueKind == JsonValueKind.String
            && overlay.GetString() is { Length: > 0 } text && Path.IsPathFullyQualified(text) ? Path.GetFullPath(text) : null;

    private static string Clean(string text) => new(text.Where(character => !char.IsControl(character)).Take(64).ToArray());

    // config.local.txt and host.txt always (created on save), then the other text and JSON
    // settings already in the overlay's config folder, such as account_signin.json.
    public static IReadOnlyList<string> Files(Location location) {
        var files = new List<string>(Offered);
        var config = Path.Combine(location.Folder, "config");
        if (Directory.Exists(config))
            foreach (var path in Directory.EnumerateFiles(config).Order(StringComparer.OrdinalIgnoreCase)) {
                var relative = "config/" + Path.GetFileName(path);
                if (files.Contains(relative) || Kept.IsMatch(relative) || Generated.Contains(relative)) continue;
                if (Path.GetExtension(path).ToLowerInvariant() is ".txt" or ".json") files.Add(relative);
            }
        return files;
    }

    private static string FullPath(Location location, string relative) {
        if (!Files(location).Contains(relative)) throw new InvalidDataException(relative + " is not a host setting file of " + location.Label + ".");
        return Path.Combine(location.Folder, relative.Replace('/', Path.DirectorySeparatorChar));
    }

    public static string Read(Location location, string relative) {
        var path = FullPath(location, relative);
        return File.Exists(path) ? File.ReadAllText(path) : "";
    }

    public static string Describe(string relative) => relative switch {
        LocalConfig => "Only the lines this host changes in the repository's config/config.txt. \"KEY value\" sets a setting, " +
            "\"#KEY\" turns it off, other lines starting with # are comments. Everything else follows master. " +
            "Secrets such as WEBHOOK_KEY and BUG_REPORT_GITHUB_TOKEN belong here, never in the repository.",
        "config/host.txt" => "The BYOND key of the host (read when a player logs in).",
        "config/config.txt" => "A whole copy of config.txt (the old way): it hides master's new settings. " +
            "Run config-migrate.bat once to turn it into config.local.txt.",
        _ => "Copied into the region on every update and config apply.",
    };

    public const string BugReportToken = "BUG_REPORT_GITHUB_TOKEN";
    private static readonly Regex TokenText = new("^[A-Za-z0-9_]{20,255}$");

    // A GitHub token as the game accepts it (code/modules/bug_reports/bug_report_format.dm).
    public static bool TokenValid(string token) => TokenText.IsMatch(token);

    // config.local.txt text with one setting set: an existing "KEY value" or "#KEY" line for it is
    // replaced in place (the first one; later ones are dropped), otherwise the line is added at the end.
    public static string WithSetting(string text, string name, string value) {
        if (!SettingName.IsMatch(name) || value.Any(char.IsControl)) throw new InvalidDataException("Not a setting: " + name);
        var setting = name + " " + value.Trim();
        var lines = text.Replace("\r\n", "\n").Split('\n').ToList();
        if (lines.Count > 0 && lines[^1].Length == 0) lines.RemoveAt(lines.Count - 1);
        var placed = false;
        var result = new List<string>();
        foreach (var raw in lines) {
            var key = raw.Trim().TrimStart('#').Split(' ', 2)[0];
            if (string.Equals(key, name, StringComparison.OrdinalIgnoreCase)) {
                if (!placed) result.Add(setting);
                placed = true;
            } else result.Add(raw);
        }
        if (!placed) result.Add(setting);
        return string.Join("\n", result) + "\n";
    }

    // Why the text cannot be saved, or null. config.local.txt follows shard_group.py merge_config.
    public static string? Problem(string relative, string text) {
        if (relative == LocalConfig) {
            var number = 0;
            foreach (var raw in text.Split('\n')) {
                number++;
                var line = raw.Trim();
                if (line.Length == 0 || line.StartsWith('#')) continue;
                if (!SettingName.IsMatch(line.Split(' ', 2)[0])) return $"Line {number} is not a setting (\"KEY value\", \"KEY\" or \"#KEY\").";
            }
        } else if (relative.EndsWith(".json", StringComparison.OrdinalIgnoreCase)) {
            try { using var _ = JsonDocument.Parse(text); }
            catch (JsonException e) { return "Not valid JSON: " + e.Message; }
        }
        return null;
    }

    // Writes the file into the overlay (never the checkout). The version it replaces is kept beside
    // it as <name>.previous, which shard_group.py never copies into a region.
    public static void Save(Location location, string relative, string text) {
        if (Problem(relative, text) is { } problem) throw new InvalidDataException(problem);
        var path = FullPath(location, relative);
        // Saving unchanged text must not replace the kept .previous with a copy of itself.
        if (File.Exists(path) && File.ReadAllText(path) == text) return;
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary = path + ".saving";
        File.WriteAllText(temporary, text, new UTF8Encoding(false));
        if (File.Exists(path)) File.Copy(path, path + ".previous", true);
        File.Move(temporary, path, true);
    }
}
