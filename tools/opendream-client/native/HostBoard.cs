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
    // The region's local time on the shared world calendar, or null when it does not report one.
    public RegionClock? Clock { get; init; }

    // Each problem of Problem on its own, with what to do about it (BoardAdvice). Problem joins their texts.
    public IReadOnlyList<RegionProblem> Problems { get; init; } = [];

    // Everything on one line, for a tooltip, the log and screen readers.
    public string Describe() {
        var text = Name + ": " + RunText.ToLowerInvariant();
        if (Activity != null) text += " (" + Activity + ")";
        if (Players is { } players) text += ", " + (players == 1 ? "1 player" : players + " players");
        if (Clock != null) text += ", " + Clock.Describe();
        text += ", build " + BuildText.ToLowerInvariant();
        if (Notes.Length > 0) text += ", " + Notes;
        return Problem == null ? text + "." : text + ". " + Problem;
    }
}

// A region's local time on the shared world calendar (code/modules/1713/world_calendar.dm): the game
// clock ("06:40 AM"), its phase of the day, the local season, the time zone in whole hours from UTC and
// the real minutes left in the season when known.
public sealed record RegionClock(string Time, string Phase, string Season, int Zone, int? SeasonLeft) {
    public bool Daylight => Phase is "Early Morning" or "Morning" or "Midday" or "Afternoon";
    public string SeasonText => Season switch {
        "SPRING" => "Spring", "SUMMER" => "Summer", "FALL" => "Fall", "WINTER" => "Winter", _ => Season,
    };
    public string ZoneText => Zone == 0 ? "UTC" : "UTC" + (Zone > 0 ? "+" : "\u2212") + Math.Abs(Zone);
    public string Describe() => $"{Time} {Phase.ToLowerInvariant()}, {SeasonText.ToLowerInvariant()}"
        + (SeasonLeft is { } left ? $" ({left} min left)" : "") + ", " + ZoneText.Replace('\u2212', '-');

    private static readonly string[] Phases = ["Early Morning", "Morning", "Midday", "Afternoon", "Evening", "Night"];
    private static readonly string[] Seasons = ["SPRING", "SUMMER", "FALL", "WINTER", "Wet Season", "Dry Season"];

    // From a status region_view's "calendar"; null when it is missing or does not check out.
    public static RegionClock? From(JsonElement view) {
        if (!view.TryGetProperty("calendar", out var calendar) || calendar.ValueKind != JsonValueKind.Object) return null;
        string? Text(string name) => calendar.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String ? value.GetString() : null;
        var time = Text("clock");
        var phase = Text("phase");
        var season = Text("season");
        if (time is not { Length: 8 } || !char.IsAsciiDigit(time[0]) || !char.IsAsciiDigit(time[1]) || time[2] != ':'
                || !char.IsAsciiDigit(time[3]) || !char.IsAsciiDigit(time[4]) || time[5] != ' ' || (time[6..] is not ("AM" or "PM"))) return null;
        if (phase == null || !Phases.Contains(phase) || season == null || !Seasons.Contains(season)) return null;
        if (!calendar.TryGetProperty("zone", out var zoneValue) || zoneValue.ValueKind != JsonValueKind.Number
                || !zoneValue.TryGetInt32(out var zone) || zone is < -12 or > 14) return null;
        int? left = calendar.TryGetProperty("season_left", out var leftValue) && leftValue.ValueKind == JsonValueKind.Number
            && leftValue.TryGetInt32(out var minutes) && minutes is >= 0 and <= 1440 ? minutes : null;
        return new RegionClock(time, phase, season, zone, left);
    }
}

public sealed record BoardCount(string Kind, int Count, string Text);

// NeedsYou: something the operator must do. Waiting: the host retries by itself; drawn quietly, not as an error.
public enum ProblemSeverity { NeedsYou, Waiting }

// One thing the operator can do about a problem. Action is a region action of shard_group.py / gaia_host.py
// ("start", "stage", "deploy", ...) or one of the launcher's own: OpenLog, CheckStatus, RestartHost.
// Group: it acts on every region, not only this one (the host service), so its button says so.
public sealed record RegionFix(string Label, string Action, bool Group = false) {
    public const string OpenLog = "open-log";
    public const string CheckStatus = "check-status";
    public const string RestartHost = "restart-host";
}

// One problem of a region card: Text is what is wrong (as before), NextStep what to do in plain words, Fixes the
// buttons for it, first one first. Stamp tells one occurrence from the next (the failed operation's time), so a
// dismissed problem that happens again shows again.
public sealed record RegionProblem(string Kind, string Text, string NextStep, IReadOnlyList<RegionFix> Fixes,
    ProblemSeverity Severity = ProblemSeverity.NeedsYou, string Stamp = "") {
    // What a dismissal remembers: the region, the problem and its occurrence.
    public string Key(string region) => region + "\n" + Kind + "\n" + Text + "\n" + Stamp;
}

// The recommended next step and fixes for every problem the board shows, and for the board's own messages.
// Advice reads the raw status fields (the failed action and its error), not the shortened problem text.
public static class BoardAdvice {
    private static readonly RegionFix Log = new("Open world log", RegionFix.OpenLog);
    private static readonly RegionFix Check = new("Check status", RegionFix.CheckStatus);
    private static readonly RegionFix HostService = new("Restart host service (all regions)", RegionFix.RestartHost, true);
    private static readonly RegionFix Deploy = new("Save, update and restart", "deploy");
    private static readonly RegionFix Start = new("Start", "start");
    private static readonly RegionFix Build = new("Build update", "stage");

    // The launcher's button for retrying a failed region action, or null for one that is not offered again
    // from here (forceful ones such as update without saving, and the host's own background jobs).
    public static RegionFix? Retry(string action) => action switch {
        "start" or "start-current" => Start,
        "stop" => new("Save and stop", "stop"),
        "restart" => new("Restart", "restart"),
        "update" => new("Update", "update"),
        "freeze" => new("Sleep now", "freeze"),
        "thaw" => new("Wake", "thaw"),
        "stage" => Build,
        "config-apply" => new("Apply host settings", "config-apply"),
        "setup" => new("Set up", "setup"),
        "handover" or "auto-handover" or "update-handover" => Deploy,
        _ => null,
    };

    public static RegionProblem WorldError(string text, string error) {
        if (error.Contains("did not load", StringComparison.OrdinalIgnoreCase))
            return new("world", text, "The save is kept as it was, untouched. Open the world log to see why it did not load, fix that, then Restart this region. "
                + "Do not start a fresh world unless you mean to lose it.", [Log]);
        return new("world", text, "Open the world log for the full error. Once it is fixed, Restart this region.", [Log]);
    }

    public static RegionProblem StatusUnavailable(string text) =>
        new("status", text, "The host tool could not read this region. Check status again; if it keeps failing, see the launcher log and restart the host service.", [Check]);

    public static RegionProblem ActionFailed(string text, string action, string error, string stamp) {
        var retry = Retry(action);
        string Again(string step) => retry != null ? step + " " + retry.Label + " again." : step;
        if (action is "handover" or "auto-handover" or "update-handover") {
            if (error.Contains("cannot guard an empty handover", StringComparison.OrdinalIgnoreCase))
                return new("handover", text, "This region still runs a build too old to check it is empty before updating itself, so it never updates on its own. "
                    + "Use Save, update and restart on it once; later updates then install by themselves.", [Deploy], ProblemSeverity.NeedsYou, stamp);
            if (error.Contains("no staged build newer", StringComparison.OrdinalIgnoreCase))
                return new("handover", text, "There was no newer build to install. Build update first if this region is behind.", [Build], ProblemSeverity.Waiting, stamp);
            if (error.Contains("deferred", StringComparison.OrdinalIgnoreCase))
                return new("handover", text, "Nothing needed: it installs the update by itself once the region is empty and saved. To update now, use Save, update and restart.",
                    [Deploy], ProblemSeverity.Waiting, stamp);
            if (error.Contains("standby port", StringComparison.OrdinalIgnoreCase))
                return new("handover", text, "Another program holds the standby port. Close it, then use Save, update and restart again.", [Deploy, Log], ProblemSeverity.NeedsYou, stamp);
            return new("handover", text, "The running world kept going, so nobody was kicked. Open the world log to see why, then use Save, update and restart again.",
                [Deploy, Log], ProblemSeverity.NeedsYou, stamp);
        }
        if (error.Contains("BYOND is not signed in", StringComparison.OrdinalIgnoreCase))
            return new("action", text, "Sign in to BYOND in the pager on the host computer. The host starts the region itself once it is signed in.", [Log], ProblemSeverity.NeedsYou, stamp);
        if (error.Contains("compile", StringComparison.OrdinalIgnoreCase) && action is "update" or "stage" or "update-unsaved")
            return new("action", text, Again("The update did not compile; the region keeps the build it had. The compiler errors are in the launcher log. Once master compiles,"),
                retry != null ? [retry] : [Log], ProblemSeverity.NeedsYou, stamp);
        if (error.Contains("save error", StringComparison.OrdinalIgnoreCase) || error.Contains("did not save", StringComparison.OrdinalIgnoreCase))
            return new("action", text, "The world did not save, so it was left as it was. Open the world log, fix the save error, then try again. "
                + "Force stop would lose everything since the last save.", retry != null ? [Log, retry] : [Log], ProblemSeverity.NeedsYou, stamp);
        if (error.Contains("another action is still running", StringComparison.OrdinalIgnoreCase))
            return new("action", text, Again("Another action was running on this region. Wait for it to finish, then"), retry != null ? [retry] : [], ProblemSeverity.Waiting, stamp);
        return new("action", text, Again("Open the world log to see why it failed. Once that is fixed, try"), retry != null ? [retry, Log] : [Log], ProblemSeverity.NeedsYou, stamp);
    }

    public static RegionProblem BuildFailed(string text, string? error) {
        if (error?.Contains("lock", StringComparison.OrdinalIgnoreCase) == true)
            return new("build", text, "Another region's compile held the build lock. Build update again once it has finished.", [Build], ProblemSeverity.Waiting);
        return new("build", text, "The update did not build; this region keeps running the build it has. The compiler errors are in the launcher log. "
            + "Once master compiles, Build update again.", [Build]);
    }

    public static RegionProblem WatchdogGaveUp(string text) =>
        new("watchdog", text, "The watchdog stopped retrying after repeated failures. Open the world log to see why it went down, then Start it.", [Start, Log]);

    public static RegionProblem WatchdogRefused(string text) =>
        new("watchdog", text, "The watchdog tried to restart it and was refused for the reason above. Fix that, then Start it.", [Start, Log]);

    public static RegionProblem TravelAgentDown(string text) =>
        new("travel", text, "Players cannot travel to or from this region. Restarting the host service starts every travel agent; the worlds keep running.", [HostService]);

    public static RegionProblem WrongRegion(string text) =>
        new("region", text, "The world on this port is not running as this region (it may have another region's settings). Apply host settings, then Restart this region.",
            [new("Apply host settings", "config-apply"), new("Restart", "restart")]);

    public static RegionProblem TravelHeld(string text) =>
        new("hold", text, "Nobody can arrive here until the hold lifts. It lifts by itself once every running region's travel agent answers, so restart the host service if one is down. "
            + "If it stays, follow the travel storage recovery steps in the host notes; never delete travel records to clear it.", [HostService, Log]);

    public static RegionProblem Unknown(string text) =>
        new("unknown", text, "The host tool did not say what state this region is in. Check status again; if it stays unknown, see the launcher log.", [Check]);

    // The board's own lines: a status check that failed, and the travel coordinator being down.
    public static string MessageStep(string message) {
        if (message.Contains("did not answer within", StringComparison.Ordinal))
            return "The status check timed out, which usually means Windows' process service is stuck. Run All regions > More > Windows process check, then Check status.";
        if (message.Contains("WMI", StringComparison.Ordinal) || message.Contains("process check", StringComparison.OrdinalIgnoreCase))
            return "Run All regions > More > Windows process check to see what is wrong with Windows' process service, then Check status.";
        return "The rows show the last status that answered. Check status again; if it keeps failing, see the launcher log, then restart the host service.";
    }

    public const string CoordinatorStep = "Travel between regions waits until the coordinator is back. Restarting the host service starts it again; the worlds keep running.";
    public static readonly RegionFix CoordinatorFix = HostService;
    public static readonly RegionFix MessageFix = Check;

    // The single server of host.json (no region group): no host service, region settings or handover deploy.
    public static RegionProblem ForServer(RegionProblem problem) => problem with {
        Fixes = problem.Fixes.Select(fix => fix.Action switch {
            "deploy" => new RegionFix("Update", "update"),
            RegionFix.RestartHost or "config-apply" or "stage" or "freeze" or "thaw" or "setup" => null,
            _ => fix,
        }).OfType<RegionFix>().Distinct().ToList(),
    };
}

public static class HostBoard {
    // check-update's "regions": how many commits each region's build is behind the group revision.
    // Empty when the line is missing or refused, so the board says "Not checked" instead of guessing.
    public static IReadOnlyDictionary<string, int> RegionsBehind(string checkOutput) {
        var behind = new Dictionary<string, int>();
        if (LastObject(checkOutput) is not { } document) return behind;
        using (document) {
            var json = document.RootElement;
            if (!Bool(json, "ok") || !json.TryGetProperty("regions", out var regions) || regions.ValueKind != JsonValueKind.Object) return behind;
            foreach (var region in regions.EnumerateObject().Take(LocalHosting.MaxRegions))
                if (region.Value.ValueKind == JsonValueKind.Object && region.Value.TryGetProperty("behind", out var count)
                        && count.ValueKind == JsonValueKind.Number && count.TryGetInt32(out var commits) && commits >= 0)
                    behind[region.Name] = commits;
        }
        return behind;
    }

    // The regions of shard_group.py status that run an action (their action lock is held) or are being
    // handed over to a new build. Only these are locked in the launcher; every other region stays usable.
    public static IReadOnlySet<string> BusyRegions(string statusOutput) {
        var busy = new HashSet<string>();
        if (LastObject(statusOutput) is not { } document) return busy;
        using (document) {
            var json = document.RootElement;
            if (!Bool(json, "ok") || !json.TryGetProperty("regions", out var regions) || regions.ValueKind != JsonValueKind.Object) return busy;
            foreach (var region in regions.EnumerateObject().Take(LocalHosting.MaxRegions))
                if (region.Value.ValueKind == JsonValueKind.Object && (Bool(region.Value, "busy")
                        || (region.Value.TryGetProperty("standby", out var standby) && standby.ValueKind == JsonValueKind.Object)))
                    busy.Add(region.Name);
        }
        return busy;
    }

    // One card per region of shard_group.py status, in the group's order. mainland: that region's id.
    // behind: RegionsBehind of the last check-update, or null before any check has answered.
    public static IReadOnlyList<RegionCard> Regions(string statusOutput, IReadOnlyDictionary<string, int>? behind, string? mainland = null) {
        var cards = new List<RegionCard>();
        if (LastObject(statusOutput) is not { } document) return cards;
        using (document) {
            var json = document.RootElement;
            if (!Bool(json, "ok") || !json.TryGetProperty("regions", out var regions) || regions.ValueKind != JsonValueKind.Object) return cards;
            foreach (var region in regions.EnumerateObject().Take(LocalHosting.MaxRegions)) {
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
        var problems = new List<RegionProblem>();
        var notes = new List<string>();
        int? players = null;
        var loading = false;
        if (entry.TryGetProperty("world", out var world) && world.ValueKind == JsonValueKind.Object) {
            if (world.TryGetProperty("clients", out var clients) && clients.ValueKind == JsonValueKind.Number && clients.TryGetInt32(out var count)) players = count;
            if (Str(world, "error") is { Length: > 0 } worldError) problems.Add(BoardAdvice.WorldError("World error: " + Short(worldError), worldError));
            // gaia_host.py reports ready as 1/0 or true/false.
            loading = world.TryGetProperty("ready", out var ready) && (ready.ValueKind == JsonValueKind.False
                || (ready.ValueKind == JsonValueKind.Number && ready.TryGetInt32(out var flag) && flag == 0));
        }
        if (Str(entry, "error") is { Length: > 0 } statusError) problems.Add(BoardAdvice.StatusUnavailable("Status unavailable: " + Short(statusError)));

        string? working = null;
        if (entry.TryGetProperty("operation", out var operation) && operation.ValueKind == JsonValueKind.Object
                && Str(operation, "action") is { } action && Str(operation, "phase") is { } phase) {
            var act = Words(action);
            if (Str(operation, "error") is { Length: > 0 } failed)
                problems.Add(BoardAdvice.ActionFailed(Capital(act) + " failed: " + Short(failed), action, failed, Stamp(operation)));
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
            if (watchdog.TryGetProperty("gave_up", out _)) problems.Add(BoardAdvice.WatchdogGaveUp($"Watchdog gave up after repeated restarts ({last}); start it by hand"));
            else if (!listening && Str(watchdog, "last_refusal") is { Length: > 0 } refusal) problems.Add(BoardAdvice.WatchdogRefused("Watchdog could not restart it: " + Short(refusal)));
            else if (Bool(watchdog, "cold")) notes.Add("watchdog left it asleep (low memory)");
            else if (restarts > 0) notes.Add($"watchdog restarted it {restarts} time{(restarts == 1 ? "" : "s")} recently (last: {last})");
        }
        if (entry.TryGetProperty("transfer_agent", out var agent) && agent.ValueKind == JsonValueKind.False) {
            // A world that is up without its travel agent strands travellers; a stopped one just has none yet.
            if (listening) problems.Add(BoardAdvice.TravelAgentDown("Travel agent not running"));
            else notes.Add("travel agent not running");
        }
        RegionClock? clock = null;
        if (entry.TryGetProperty("region_view", out var view) && view.ValueKind == JsonValueKind.Object) {
            if (Str(view, "error") != null) problems.Add(BoardAdvice.WrongRegion("Not answering as this region"));
            else {
                if (view.TryGetProperty("epoch", out var epoch) && epoch.ValueKind == JsonValueKind.Object && epoch.TryGetProperty("ordinal", out var ordinal)
                        && ordinal.ValueKind == JsonValueKind.Number && ordinal.TryGetInt32(out var index) && index >= 0 && index < LocalHosting.EpochNames.Length)
                    notes.Insert(0, "epoch " + LocalHosting.EpochNames[index]);
                clock = RegionClock.From(view);
                if (Str(view, "battle_phase") is { Length: > 0 } battle) notes.Insert(0, "battle " + LocalHosting.BattlePhase(battle));
                if (LocalHosting.EventAway(view) is > 0 and var away) notes.Add(LocalHosting.AwayText(away));
                // The land's transfer agent refuses every arrival until an operator clears its hold.
                if (view.TryGetProperty("transfers_held", out var held) && held.ValueKind == JsonValueKind.True) problems.Add(BoardAdvice.TravelHeld("Travel in is on hold: nobody can arrive"));
            }
        }
        if (Str(entry, "kind") == "EVENT") notes.Insert(0, "event region");
        if (Str(entry, "kind") == "GATEWAY") notes.Insert(0, "gateway: sends players on, never sleeps");
        if (LocalHosting.LandText(entry) is { } land) notes.Add(land);
        if (entry.TryGetProperty("port", out var portValue) && portValue.ValueKind == JsonValueKind.Number && portValue.TryGetInt32(out var port) && port is > 0 and < 65536)
            notes.Insert(0, "port " + port);

        if (working == null && state == "awake" && loading) working = "loading the world";
        var (run, runText) = working != null ? (RegionRun.Working, "Working") : state switch {
            "awake" => (RegionRun.Running, "Running"),
            "asleep" => (RegionRun.Asleep, "Asleep"),
            "cold" => (RegionRun.Asleep, "Asleep"),
            "stopped" => (RegionRun.Stopped, "Stopped"),
            _ => (RegionRun.Unknown, "Unknown"),
        };
        if (state == "cold") notes.Insert(0, "saved and shut down; a wake or travel starts it");
        if (run == RegionRun.Unknown && problems.Count == 0) problems.Add(BoardAdvice.Unknown("State unknown"));
        if (id == "server") problems = problems.Select(BoardAdvice.ForServer).ToList();
        return new RegionCard(id, name, mainland, run, runText, players, build, buildText, working, string.Join(", ", notes),
            problems.Count == 0 ? null : string.Join(". ", problems.Select(problem => problem.Text)) + ".") { Clock = clock, Problems = problems };
    }

    // The staged build wins over the commit count: it is what the operator acts on next.
    private static (RegionBuild, string) Build(JsonElement entry, int? behind, List<RegionProblem> problems, List<string> notes) {
        if (entry.TryGetProperty("stage", out var stage) && stage.ValueKind == JsonValueKind.Object && Str(stage, "phase") is { } phase) {
            if (phase == "failed") {
                var error = Str(stage, "error") is { Length: > 0 } failed ? failed : null;
                problems.Add(BoardAdvice.BuildFailed("Update build failed" + (error != null ? ": " + Short(error) : ""), error));
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
    // shown: false for a problem the operator dismissed; only problems that need the operator and are shown count.
    public static IReadOnlyList<BoardCount> Summary(IReadOnlyList<RegionCard> cards, Func<RegionCard, RegionProblem, bool>? shown = null) {
        var counts = new List<BoardCount>();
        void Add(string kind, int count, string text) { if (count > 0) counts.Add(new BoardCount(kind, count, text)); }
        var problems = cards.Count(card => card.Problems.Any(problem => problem.Severity == ProblemSeverity.NeedsYou && (shown == null || shown(card, problem))));
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
    // When the failed operation was last written (gaia_host.py record's "updated"), so the same failure again is new.
    private static string Stamp(JsonElement operation) =>
        operation.TryGetProperty("updated", out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out var seconds) ? seconds.ToString(CultureInfo.InvariantCulture) : "";
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
