using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
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

    // The countdown players online get before a Save and stop, Restart or Save, update and restart
    // saves (the group config's shutdown_warning_seconds; shard_group.py reads it at each action).
    public const int DefaultShutdownWarningSeconds = 120;
    public const int MaxShutdownWarningSeconds = 3600;

    public static int ShutdownWarningSeconds(HostGroup group) {
        var root = JsonNode.Parse(File.ReadAllText(group.Config));
        return root?["shutdown_warning_seconds"] is JsonValue value && value.TryGetValue<int>(out var seconds)
            && seconds is >= 0 and <= MaxShutdownWarningSeconds ? seconds : DefaultShutdownWarningSeconds;
    }

    // Rewrites the group config with the new value, keeping every other setting.
    public static void SetShutdownWarningSeconds(HostGroup group, int seconds) {
        if (seconds is < 0 or > MaxShutdownWarningSeconds) throw new InvalidDataException("The players' warning must be 0 to 3600 seconds.");
        if (JsonNode.Parse(File.ReadAllText(group.Config)) is not JsonObject root) throw new InvalidDataException(group.Config + " is not a JSON object.");
        root["shutdown_warning_seconds"] = seconds;
        WriteGroup(group, root);
    }
    // The group config is replaced whole, and the host service and every host script read it: Windows refuses
    // the replace while one of them has it open, which lost the setting with an access-denied error. Tried again
    // for a second, as gaia_host.py replace_file does for the status files.
    internal static void WriteGroup(HostGroup group, JsonObject root) {
        // Taken right after the caller's read: a retry must never install that read over a newer file.
        var read = File.GetLastWriteTimeUtc(group.Config);
        var temporary = group.Config + ".tmp";
        File.WriteAllText(temporary, root.ToJsonString(new JsonSerializerOptions { WriteIndented = true }) + "\n");
        ReplaceFile(temporary, group.Config, () => File.GetLastWriteTimeUtc(group.Config) == read);
    }

    // unchanged: asked before each further attempt; false means someone else (a port change, another setting)
    // wrote the file while this write waited, so it is given up instead of undoing theirs.
    internal static void ReplaceFile(string temporary, string path, Func<bool>? unchanged = null, int attempts = 20) {
        for (var attempt = 1; ; attempt++) {
            try { File.Move(temporary, path, true); return; }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException && attempt < attempts && File.Exists(temporary)) {
                Thread.Sleep(50);
                if (unchanged != null && !unchanged()) {
                    try { File.Delete(temporary); } catch (Exception inner) when (inner is IOException or UnauthorizedAccessException) { }
                    throw new IOException(Path.GetFileName(path) + " was changed by something else while saving. Nothing was saved; try again.");
                }
            }
        }
    }

    // Update when empty: a region whose last player left and which has saved since builds the latest
    // revision beside itself and attempts a standby handover (the group config's update_when_empty, on unless
    // set false; shard_group.py RegionHost reads it at each check). New commits are only seen when the
    // group fetches its remote, so turning it on also points a group that does not at origin/master.
    public static bool UpdateWhenEmpty(HostGroup group) {
        var root = JsonNode.Parse(File.ReadAllText(group.Config));
        return root?["update_when_empty"] is not JsonValue value || !value.TryGetValue<bool>(out var on) || on;
    }

    // Whether the group fetches a remote before resolving its revision (shard_group.py fetch_remote).
    public static bool FollowsRemote(HostGroup group) {
        var root = JsonNode.Parse(File.ReadAllText(group.Config));
        return root?["fetch"] is JsonValue value && value.TryGetValue<string>(out var remote) && remote.Length > 0;
    }

    // Returns true when turning it on also set "fetch": "origin" and "revision": "origin/master".
    public static bool SetUpdateWhenEmpty(HostGroup group, bool on) {
        if (JsonNode.Parse(File.ReadAllText(group.Config)) is not JsonObject root) throw new InvalidDataException(group.Config + " is not a JSON object.");
        root["update_when_empty"] = on;
        var followed = false;
        if (on && !(root["fetch"] is JsonValue fetch && fetch.TryGetValue<string>(out var remote) && remote.Length > 0)) {
            root["fetch"] = "origin";
            root["revision"] = "origin/master";
            followed = true;
        }
        WriteGroup(group, root);
        return followed;
    }

    // Daily maintenance (the group config's "maintenance"; scripts/shard-group/daily_maintenance.py): at Time, host local
    // time, the host service builds one revision beside every region, counts down WarningMinutes for the players of every
    // occupied region at once, then hands each running region over to it; asleep and stopped regions install it without
    // waking, and the gateway stays on its port. On unless set false for the live group that saves and follows a remote.
    public sealed record Maintenance(bool Enabled, string Time, int WarningMinutes, bool Persistent);
    public const string DefaultMaintenanceTime = "03:00";
    public const int DefaultMaintenanceWarningMinutes = 10;
    public const int MaxMaintenanceWarningMinutes = 60;
    private static readonly Regex MaintenanceTime = new("^([01][0-9]|2[0-3]):[0-5][0-9]$");

    public static Maintenance DailyMaintenance(HostGroup group) {
        if (JsonNode.Parse(File.ReadAllText(group.Config)) is not JsonObject root) throw new InvalidDataException(group.Config + " is not a JSON object.");
        static bool Flag(JsonNode? node, bool fallback) => node is JsonValue value && value.TryGetValue<bool>(out var on) ? on : fallback;
        var persistent = Flag(root["persistent"], true);
        var follows = root["fetch"] is JsonValue fetch && fetch.TryGetValue<string>(out var remote) && remote.Length > 0;
        var settings = root["maintenance"] as JsonObject;
        var enabled = Flag(settings?["enabled"], persistent && Flag(root["live"], false) && follows);
        var time = settings?["time"] is JsonValue at && at.TryGetValue<string>(out var text) && MaintenanceTime.IsMatch(text) ? text : DefaultMaintenanceTime;
        var warning = settings?["warning_minutes"] is JsonValue minutes && minutes.TryGetValue<int>(out var count)
            && count is >= 0 and <= MaxMaintenanceWarningMinutes ? count : DefaultMaintenanceWarningMinutes;
        return new Maintenance(enabled, time, warning, persistent);
    }

    // Keeps the group's other maintenance keys (late_minutes) and every other setting.
    public static void SetDailyMaintenance(HostGroup group, bool enabled, string time, int warningMinutes) {
        if (!MaintenanceTime.IsMatch(time)) throw new InvalidDataException("The maintenance time must be HH:MM (24-hour).");
        if (warningMinutes is < 0 or > MaxMaintenanceWarningMinutes) throw new InvalidDataException("The players' countdown must be 0 to 60 minutes.");
        if (JsonNode.Parse(File.ReadAllText(group.Config)) is not JsonObject root) throw new InvalidDataException(group.Config + " is not a JSON object.");
        if (root["maintenance"] is not JsonObject settings) root["maintenance"] = settings = new JsonObject();
        settings["enabled"] = enabled;
        settings["time"] = time;
        settings["warning_minutes"] = warningMinutes;
        WriteGroup(group, root);
    }

    // Start region: where new characters start, and fallen ones whose bed does not keep their home (the group
    // config's start_region; shard_group.py restarts the group coordinator on it at its next helper check, and
    // running worlds pick it up within a minute). The mainland stays the era source and bot link either way.
    public sealed record StartChoice(string Id, string Name);
    // Kinds nobody can start in, as shard_group.py START_REGION_REFUSED_KINDS.
    private static readonly string[] NoStartKinds = ["RAID", "ORBIT", "BATTLE", "EVENT", "EXPEDITION", "TUTORIAL", "GATEWAY"];

    // The mainland, the current start region (the mainland unless start_region names another) and every region
    // a new character may start in, in the group's order.
    public static (string Mainland, string Current, IReadOnlyList<StartChoice> Choices) StartRegion(HostGroup group) {
        if (JsonNode.Parse(File.ReadAllText(group.Config)) is not JsonObject root || root["regions"] is not JsonArray regions)
            throw new InvalidDataException("The group config lists no regions.");
        var choices = new List<StartChoice>();
        string? first = null;
        foreach (var node in regions) {
            if (node is not JsonObject region || Text(region["id"]) is not { } id || !RegionId.IsMatch(id)) continue;
            first ??= id;
            if (NoStartKinds.Contains(Text(region["kind"]) ?? "")) continue;
            choices.Add(new StartChoice(id, Text(region["name"]) is { Length: > 0 } name ? name : id));
        }
        if (first == null) throw new InvalidDataException("The group config lists no regions.");
        var mainland = Text(root["mainland"]) ?? first;
        var current = Text(root["start_region"]) ?? mainland;
        return (mainland, current, choices);
    }

    // Rewrites the group config with the new start region, keeping every other setting. Choosing the mainland
    // removes the key, so the start follows the mainland again if it ever moves.
    public static void SetStartRegion(HostGroup group, string id) {
        var (mainland, _, choices) = StartRegion(group);
        if (!choices.Any(choice => choice.Id == id)) throw new InvalidDataException(id + " is not a region new characters can start in.");
        if (JsonNode.Parse(File.ReadAllText(group.Config)) is not JsonObject root) throw new InvalidDataException(group.Config + " is not a JSON object.");
        if (id == mainland) root.Remove("start_region");
        else root["start_region"] = id;
        WriteGroup(group, root);
    }

    // Travel starts: a traveller bound for a land that is not running starts it, the way one bound for a sleeping
    // land wakes it (Val, 2026-11-22). A region kept down (its group config entry's keep_down) is never started that
    // way; the doorman and shard_group.py read it at each request, so a change applies at once. The gateway is left
    // out: travellers never go there, and the host service alone starts it.
    public sealed record TravelStart(string Id, string Name, bool KeptDown);

    public static IReadOnlyList<TravelStart> TravelStarts(HostGroup group) {
        if (JsonNode.Parse(File.ReadAllText(group.Config)) is not JsonObject root || root["regions"] is not JsonArray regions)
            throw new InvalidDataException("The group config lists no regions.");
        var list = new List<TravelStart>();
        foreach (var node in regions) {
            if (node is not JsonObject region || Text(region["id"]) is not { } id || !RegionId.IsMatch(id)) continue;
            if (Text(region["kind"]) == "GATEWAY") continue;
            var kept = region["keep_down"] is JsonValue value && value.TryGetValue<bool>(out var on) && on;
            list.Add(new TravelStart(id, Text(region["name"]) is { Length: > 0 } name ? name : id, kept));
        }
        return list;
    }

    // Rewrites the group config with keep_down set on the named regions and removed from the rest, keeping every
    // other setting.
    public static void SetKeptDown(HostGroup group, IReadOnlyCollection<string> keptDown) {
        if (JsonNode.Parse(File.ReadAllText(group.Config)) is not JsonObject root || root["regions"] is not JsonArray regions)
            throw new InvalidDataException(group.Config + " lists no regions.");
        foreach (var node in regions) {
            if (node is not JsonObject region || Text(region["id"]) is not { } id) continue;
            if (keptDown.Contains(id) && Text(region["kind"]) != "GATEWAY") region["keep_down"] = true;
            else region.Remove("keep_down");
        }
        WriteGroup(group, root);
    }

    // Ready lands (group config ready_neighbours, default on, and cold_after_minutes, default 15; Val, 2026-11-22): a land
    // next to one with players stays suspended in memory and is started ahead from cold storage, so a traveller wakes it in
    // seconds; a land with nobody next door goes to cold storage after cold_after_minutes (0 = never). Gaia and the oceans
    // around it are always kept ready. The host service reads both at each check.
    public const int DefaultColdAfterMinutes = 15;
    public const int MaxColdAfterMinutes = 1440;

    public static (bool On, int ColdAfterMinutes) Readiness(HostGroup group) {
        var root = JsonNode.Parse(File.ReadAllText(group.Config));
        var on = root?["ready_neighbours"] is not JsonValue flag || !flag.TryGetValue<bool>(out var value) || value;
        var minutes = root?["cold_after_minutes"] is JsonValue number && number.TryGetValue<int>(out var read)
            && read is >= 0 and <= MaxColdAfterMinutes ? read : DefaultColdAfterMinutes;
        return (on, minutes);
    }

    public static void SetReadiness(HostGroup group, bool on, int coldAfterMinutes) {
        if (coldAfterMinutes is < 0 or > MaxColdAfterMinutes) throw new InvalidDataException("Cold storage must be 0 to 1440 minutes.");
        if (JsonNode.Parse(File.ReadAllText(group.Config)) is not JsonObject root) throw new InvalidDataException(group.Config + " is not a JSON object.");
        root["ready_neighbours"] = on;
        root["cold_after_minutes"] = coldAfterMinutes;
        WriteGroup(group, root);
    }

    private static string? Text(JsonNode? node) => node is JsonValue value && value.TryGetValue<string>(out var text) ? text : null;

    public static readonly string[] Offered = [LocalConfig, "config/host.txt"];
    // Earlier versions an overlay keeps (shard_group.py KEPT_COPY); they are never offered or copied.
    private static readonly Regex Kept = new(@"\.(previous|migrated)$|\.bak(-|$)");
    // Files shard_group.py setup writes for each region; an overlay must not hold them (GENERATED).
    private static readonly string[] Generated = ["config/shard_region.json", "config/lifecycle-token.txt", "config/lifecycle-revision.txt",
        "config/transfer-token.txt", "config/transfer_agent.json", "config/relay-token.txt", "config/tdm-token.txt",
        "config/shard_build.json", "config/server-build.json"];
    private static readonly Regex SettingName = new("^[A-Za-z][A-Za-z0-9_]*$");
    private static readonly Regex RegionId = new("^[a-z0-9][a-z0-9_-]{0,31}$");

    // The group overlay first (if the group config names one), then each region's, in the config's order.
    public static IReadOnlyList<Location> Locations(HostGroup group) {
        using var document = JsonDocument.Parse(File.ReadAllText(group.Config));
        var json = document.RootElement;
        var found = new List<Location>();
        if (Overlay(json) is { } shared) found.Add(new Location("Every region (shared)", shared, null));
        if (json.TryGetProperty("regions", out var regions) && regions.ValueKind == JsonValueKind.Array)
            foreach (var region in regions.EnumerateArray().Take(LocalHosting.MaxRegions)) {
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
            "Secrets such as WEBHOOK_KEY, BUG_REPORT_GITHUB_TOKEN and BUG_REPORT_SCREENSHOT_TOKEN belong here, never in the repository.",
        "config/host.txt" => "The BYOND key of the host (read when a player logs in).",
        "config/config.txt" => "A whole copy of config.txt (the old way): it hides master's new settings. " +
            "Run config-migrate.bat once to turn it into config.local.txt.",
        _ => "Copied into the region on every update and config apply.",
    };

    public const string BugReportToken = "BUG_REPORT_GITHUB_TOKEN";
    // Uploads bug report screenshots to BUG_REPORT_SCREENSHOT_REPO (code/modules/bug_reports/bug_report_screenshot.dm).
    public const string ScreenshotToken = "BUG_REPORT_SCREENSHOT_TOKEN";
    public static readonly string[] SecretSettings = [BugReportToken, ScreenshotToken];
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

    // The hub name: SERVER_NAME is the bold title of the world's BYOND hub entry and its window title
    // (code/world.dm update_status, customserver_name()); each world reads it once at startup.
    public const string ServerName = "SERVER_NAME";
    public const string DefaultServerName = "Civilization 13";
    public const int ServerNameLength = 60;

    // Why the name cannot be the hub name, or null. Empty means "no line here" (follow the shared or
    // repository value). Quotes would break the window-title winset and the config line.
    public static string? ServerNameProblem(string name) {
        var text = name.Trim();
        if (text.Length == 0) return null;
        if (text.Length > ServerNameLength) return $"Keep the name to {ServerNameLength} characters.";
        if (text.Any(char.IsControl)) return "The name cannot hold control characters.";
        if (text.IndexOfAny(['\'', '"', '\\', '<', '>']) >= 0) return "Leave out quotes, backslashes and < > in the name.";
        if (text.StartsWith('#')) return "The name cannot start with #.";
        return null;
    }

    // The value the config text gives a setting, as the game reads it: the last active "KEY value"
    // line wins; null when no active line names it. "#KEY" lines and comments are skipped.
    public static string? SettingValue(string text, string name) {
        string? found = null;
        foreach (var raw in text.Replace("\r\n", "\n").Split('\n')) {
            var line = raw.Trim();
            if (line.Length == 0 || line.StartsWith('#')) continue;
            var parts = line.Split(' ', 2);
            if (string.Equals(parts[0], name, StringComparison.OrdinalIgnoreCase)) found = parts.Length > 1 ? parts[1].Trim() : "";
        }
        return found;
    }

    // config.local.txt text with every line for the setting ("KEY value" or "#KEY") removed, so it
    // follows the shared overlay or the repository again.
    public static string WithoutSetting(string text, string name) {
        if (!SettingName.IsMatch(name)) throw new InvalidDataException("Not a setting: " + name);
        var kept = text.Replace("\r\n", "\n").Split('\n').Where(raw => {
            var line = raw.Trim();
            if (line.StartsWith('#') && line.Contains(' ')) return true; // a comment
            return !string.Equals(line.TrimStart('#').Split(' ', 2)[0], name, StringComparison.OrdinalIgnoreCase);
        }).ToList();
        while (kept.Count > 0 && kept[^1].Length == 0) kept.RemoveAt(kept.Count - 1);
        return kept.Count == 0 ? "" : string.Join("\n", kept) + "\n";
    }

    // config.local.txt text with the hub name set, or its line removed when name is empty.
    public static string WithServerName(string text, string name) {
        if (ServerNameProblem(name) is { } problem) throw new InvalidDataException(problem);
        return name.Trim().Length == 0 ? WithoutSetting(text, ServerName) : WithSetting(text, ServerName, name);
    }

    // The hub name a region's world uses now: the SERVER_NAME in the region's merged config/config.txt
    // (written on its last update or config apply), or null when the region folder has none yet.
    public static string? RegionServerName(HostGroup group, string region) {
        if (!RegionId.IsMatch(region)) throw new ArgumentException("Not a region id.", nameof(region));
        using var document = JsonDocument.Parse(File.ReadAllText(group.Config));
        if (document.RootElement.ValueKind != JsonValueKind.Object || !document.RootElement.TryGetProperty("root", out var rootJson)
            || rootJson.ValueKind != JsonValueKind.String || rootJson.GetString() is not { Length: > 0 } root) return null;
        var path = Path.Combine(Path.GetFullPath(root), region, "config", "config.txt");
        if (!File.Exists(path)) return null;
        return SettingValue(File.ReadAllText(path), ServerName) is { Length: > 0 } name ? name : DefaultServerName;
    }

    // The editor never shows a token: its line reads "BUG_REPORT_GITHUB_TOKEN (hidden)".
    public const string Hidden = "(hidden)";

    public static string HideSecrets(string text) => string.Join("\n", text.Replace("\r\n", "\n").Split('\n').Select(line =>
        SecretName(line) is { } name ? name + " " + Hidden : line));

    // The shown text with each hidden line given back its value from actual (the file as read or set).
    public static string RestoreSecrets(string shown, string actual) {
        var secrets = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var line in actual.Replace("\r\n", "\n").Split('\n'))
            if (SecretName(line) is { } name && !secrets.ContainsKey(name)) secrets[name] = line;
        return string.Join("\n", shown.Replace("\r\n", "\n").Split('\n').Select(line => {
            var parts = line.Trim().Split(' ', 2);
            return parts.Length == 2 && parts[1].Trim() == Hidden && secrets.TryGetValue(parts[0], out var secret) ? secret : line;
        }));
    }

    // The secret setting a "KEY value" line sets (as SecretSettings spells it), or null.
    private static string? SecretName(string line) {
        var parts = line.Trim().Split(' ', 2);
        if (parts.Length != 2 || parts[1].Trim() == Hidden) return null;
        return SecretSettings.FirstOrDefault(name => parts[0].Equals(name, StringComparison.OrdinalIgnoreCase));
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
        ReplaceFile(temporary, path);
    }
}
