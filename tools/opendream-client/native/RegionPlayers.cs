using System.Diagnostics;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Civ13.Launcher;

// The Host tab's Players dialog: who is online in one region, and Send Player to Region from the
// launcher (Civ13 code/modules/persistence/region_admin_send.dm, shard_group.py players and
// send-players). A send always shows the world's dry run first; only "Send" passes --send.
// A real send holds (freezes) the chosen players at once, checks them again and answers with
// the rows of that second check; anyone who fails is released. Held shows who is frozen.
public static class RegionPlayers {
    public sealed record Player(string Ckey, string Name, bool Playing, string? Aboard, string? At, bool Held = false);
    public sealed record Destination(string Label, string Id);
    public sealed record Roster(bool Ok, string? Error, IReadOnlyList<Player> Players, IReadOnlyList<Destination> Destinations, IReadOnlyList<string> Recent, bool Running);
    public sealed record SendRow(string Ckey, string Name, bool Ok, string? Reason, IReadOnlyList<string> Warnings);
    // Send: "dry_run", "started" or "refused:why" from the world; Error when the script refused before asking it.
    public sealed record SendAnswer(bool Ok, string? Error, string Send, IReadOnlyList<SendRow> Rows) {
        public bool Started => Ok && Send == "started";
        public int Ready => Rows.Count(row => row.Ok);
    }

    // shard_group.py SEND_LANDINGS, with the wording the dialog shows.
    public static readonly (string Id, string Label)[] Landings = [("shore", "Nearest dry shore"), ("coords", "Exact coordinates"), ("arrival", "Normal arrival point")];
    private static readonly Regex RegionId = new("^[a-z0-9][a-z0-9_-]{0,31}$");
    // shard_group.py CKEY_LIST for one key; at most 20 keys per send.
    private static readonly Regex Key = new("^[A-Za-z0-9_ .@-]{1,32}$");
    private static readonly Regex Coords = new("^[0-9]{1,5},[0-9]{1,5},[0-9]{1,5}$");

    private static ProcessStartInfo Step(HostControl control, string action, string region) {
        var group = control.Group ?? throw new InvalidOperationException("No region group configured.");
        if (!RegionId.IsMatch(region)) throw new ArgumentException("Not a region id.", nameof(region));
        var step = new ProcessStartInfo(control.Python) { UseShellExecute = false, CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(group.ShardScript)!, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "-I", "-B", group.ShardScript, "--config", group.Config, action, "--region", region }) step.ArgumentList.Add(argument);
        return step;
    }

    public static ProcessStartInfo PlayersStep(HostControl control, string region) => Step(control, "players", region);

    // send false: only the dry run. at: "x,y,z" for the coords landing only.
    public static ProcessStartInfo SendStep(HostControl control, string region, IReadOnlyList<string> keys, string to, string landing, string? at, bool ship, bool send) {
        if (keys.Count is < 1 or > 20 || keys.Any(key => !Key.IsMatch(key) || key.Trim().Length == 0 || key.StartsWith('-')))
            throw new ArgumentException("Choose 1 to 20 players.", nameof(keys));
        if (!RegionId.IsMatch(to) || to == region) throw new ArgumentException("Choose another region.", nameof(to));
        if (!Landings.Any(entry => entry.Id == landing)) throw new ArgumentException("Unknown landing.", nameof(landing));
        if ((landing == "coords") != (at != null) || (at != null && !Coords.IsMatch(at))) throw new ArgumentException("Coordinates are x,y,z, for the coordinates landing only.", nameof(at));
        var step = Step(control, "send-players", region);
        foreach (var argument in new[] { "--players", string.Join(",", keys.Select(key => key.Trim())), "--to", to, "--landing", landing }) step.ArgumentList.Add(argument);
        if (at != null) { step.ArgumentList.Add("--at"); step.ArgumentList.Add(at); }
        if (ship) step.ArgumentList.Add("--ship");
        if (send) step.ArgumentList.Add("--send");
        return step;
    }

    private static JsonDocument? LastJson(string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{')) ?? "";
        try { return JsonDocument.Parse(line); } catch (JsonException) { return null; }
    }

    private static string? Refusal(JsonElement json) =>
        json.TryGetProperty("ok", out var ok) && ok.ValueKind == JsonValueKind.True ? null
        : Str(json, "refused") ?? Str(json, "error") ?? "no reason given";

    // shard_group.py players: {"ok", "players": [{"ckey", "name", "playing", "at": [x, y, z], "aboard", "held"}],
    //  "destinations": {"Name (state)": id}, "recent": [{"time", "text"}], "running"}
    public static Roster ParseRoster(int exit, string output) {
        using var document = LastJson(output);
        if (document == null || document.RootElement.ValueKind != JsonValueKind.Object)
            return new Roster(false, $"The group script gave no answer (exit {exit}).", [], [], [], false);
        var json = document.RootElement;
        if (Refusal(json) is { } refused) return new Roster(false, "Refused: " + Short(refused), [], [], [], false);
        var players = new List<Player>();
        if (json.TryGetProperty("players", out var list) && list.ValueKind == JsonValueKind.Array)
            foreach (var entry in list.EnumerateArray().Take(500)) {
                if (entry.ValueKind != JsonValueKind.Object || Str(entry, "ckey") is not { } ckey || !Key.IsMatch(ckey)) continue;
                string? at = null;
                if (entry.TryGetProperty("at", out var spot) && spot.ValueKind == JsonValueKind.Array && spot.GetArrayLength() == 3
                        && spot.EnumerateArray().All(n => n.ValueKind == JsonValueKind.Number))
                    at = string.Join(",", spot.EnumerateArray().Select(n => n.GetInt32()));
                players.Add(new Player(ckey, Short(Str(entry, "name") ?? "(in the lobby)"), Bool(entry, "playing"), Str(entry, "aboard") is { } ship ? Short(ship) : null, at, Bool(entry, "held")));
            }
        var destinations = new List<Destination>();
        if (json.TryGetProperty("destinations", out var places) && places.ValueKind == JsonValueKind.Object)
            foreach (var place in places.EnumerateObject().Take(LocalHosting.MaxRegions))
                if (place.Value.ValueKind == JsonValueKind.String && RegionId.IsMatch(place.Value.GetString()!))
                    destinations.Add(new Destination(Short(place.Name), place.Value.GetString()!));
        var recent = new List<string>();
        if (json.TryGetProperty("recent", out var notes) && notes.ValueKind == JsonValueKind.Array)
            foreach (var note in notes.EnumerateArray().Take(20))
                if (note.ValueKind == JsonValueKind.Object && Str(note, "text") is { } text) recent.Add(Short(text));
        return new Roster(true, null, players, destinations, recent, Bool(json, "running"));
    }

    // shard_group.py send-players: {"ok", "send": "dry_run" | "started" | "refused:why",
    //  "rows": [{"ckey", "name", "ok", "reason", "warnings": [text]}]}
    public static SendAnswer ParseSend(int exit, string output) {
        using var document = LastJson(output);
        if (document == null || document.RootElement.ValueKind != JsonValueKind.Object)
            return new SendAnswer(false, $"The group script gave no answer (exit {exit}).", "", []);
        var json = document.RootElement;
        if (Refusal(json) is { } refused) return new SendAnswer(false, "Refused: " + Short(refused), "", []);
        var rows = new List<SendRow>();
        if (json.TryGetProperty("rows", out var list) && list.ValueKind == JsonValueKind.Array)
            foreach (var entry in list.EnumerateArray().Take(50)) {
                if (entry.ValueKind != JsonValueKind.Object) continue;
                var warnings = entry.TryGetProperty("warnings", out var notes) && notes.ValueKind == JsonValueKind.Array
                    ? notes.EnumerateArray().Where(n => n.ValueKind == JsonValueKind.String).Take(8).Select(n => Short(n.GetString()!)).ToList() : [];
                rows.Add(new SendRow(Short(Str(entry, "ckey") ?? "?"), Short(Str(entry, "name") ?? ""), Bool(entry, "ok"), Str(entry, "reason") is { } why ? Short(why) : null, warnings));
            }
        return new SendAnswer(true, null, Short(Str(json, "send") ?? ""), rows);
    }

    // The dry run (or the send's answer) as lines for the dialog and the host log.
    // A started send's rows are the world's second check, made while the players are frozen.
    public static string Describe(SendAnswer answer) {
        if (!answer.Ok) return answer.Error ?? "No answer.";
        var lines = new List<string>();
        foreach (var row in answer.Rows) {
            var who = row.Ckey + (row.Name.Length > 0 ? " (" + row.Name + ")" : "");
            lines.Add(row.Ok ? (answer.Started ? "Sending: " : "Ready: ") + who + (row.Warnings.Count > 0 ? ": " + string.Join("; ", row.Warnings) : "")
                : "Refused: " + who + ": " + (row.Reason ?? "no reason given"));
        }
        lines.Add(answer.Send switch {
            "dry_run" => answer.Ready == 0 ? "Nobody can be sent now." : $"{answer.Ready} of {answer.Rows.Count} can be sent. Nothing has moved yet.",
            "started" => (answer.Ready > 0 ? $"Sending {answer.Ready} now" : "Sending now") + ", one at a time. They are frozen until they leave; anyone not ready was released.",
            var other when other.StartsWith("refused:") => "Not sent: " + other["refused:".Length..] + ". Anyone frozen for it was released.",
            _ => "The world gave no send answer.",
        });
        return string.Join(Environment.NewLine, lines);
    }

    // Recent lines in now that before did not have, oldest first. The same text twice counts twice.
    public static IReadOnlyList<string> NewRecent(IReadOnlyList<string> before, IReadOnlyList<string> now) {
        var old = before.ToList();
        return now.Where(line => !old.Remove(line)).ToList();
    }

    public enum FollowState { Running, Ended, TimedOut }

    // The dialog's text while it follows a started send: the send's answer, how it stands, and the
    // transfer lines that appeared since before (the Recent list from before the send).
    public static string DescribeFollow(SendAnswer sent, Roster? latest, IReadOnlyList<string> before, int seconds, FollowState state) {
        var lines = new List<string> { Describe(sent), "" };
        var here = latest is { Ok: true } ? latest.Players : null;
        if (state == FollowState.Running) {
            lines.Add($"Sending... ({seconds}s)");
            if (latest is { Ok: false }) lines.Add("The region did not answer the last look (" + (latest.Error ?? "no answer") + "). Still trying.");
            if (here?.Where(player => player.Held).Select(player => player.Ckey).ToList() is { Count: > 0 } held) lines.Add("Frozen now: " + string.Join(", ", held) + ".");
        } else if (state == FollowState.Ended) {
            lines.Add($"The send has ended ({seconds}s). Nobody is frozen by it any more.");
            var stayed = here == null ? [] : sent.Rows.Where(row => row.Ok && here.Any(player => string.Equals(player.Ckey, row.Ckey, StringComparison.OrdinalIgnoreCase))).Select(row => row.Ckey).ToList();
            if (here != null) lines.Add(stayed.Count > 0 ? "Still here: " + string.Join(", ", stayed) + ". The lines below say why."
                : "None of the players sent are in this region now.");
        } else {
            lines.Add("Stopped following after 15 minutes. The world releases anyone still frozen by itself; Refresh shows where it stands.");
        }
        var fresh = latest is { Ok: true } ? NewRecent(before, latest.Recent) : [];
        if (fresh.Count > 0) { lines.Add("Transfers since the send, newest first:"); lines.AddRange(fresh.AsEnumerable().Reverse()); }
        else if (state == FollowState.Running) lines.Add("No outcome yet.");
        return string.Join(Environment.NewLine, lines);
    }

    public static Roster RunPlayers(HostControl control, string region, Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var (exit, output) = (run ?? LocalHosting.RunCaptured)(PlayersStep(control, region));
        return ParseRoster(exit, output);
    }

    public static SendAnswer RunSend(HostControl control, string region, IReadOnlyList<string> keys, string to, string landing, string? at, bool ship, bool send,
            Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var (exit, output) = (run ?? LocalHosting.RunCaptured)(SendStep(control, region, keys, to, landing, at, ship, send));
        return ParseSend(exit, output);
    }

    // World text can hold anything: keep printable characters only, cut to 200.
    private static string Short(string text) {
        var clean = new StringBuilder();
        foreach (var c in text) if (!char.IsControl(c)) clean.Append(c);
        return clean.Length > 200 ? clean.ToString(0, 200) : clean.ToString();
    }
    private static string? Str(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
    // BYOND's json_encode writes TRUE and FALSE as 1 and 0.
    private static bool Bool(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && (value.ValueKind == JsonValueKind.True
            || (value.ValueKind == JsonValueKind.Number && value.TryGetDouble(out var number) && number != 0));
}
