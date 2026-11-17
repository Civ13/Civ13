using System.Diagnostics;
using System.Globalization;
using System.Text;
using System.Text.Json;

namespace Civ13.Launcher;

// The Host tab's AI characters window (All regions > More): the autopilot watchers on this host (Ada and other
// agent-driven characters, Civ13 docs/agent-control.md), each run's status, latest needs and log, and Stop run /
// Restart watcher. shard_group.py agents (scripts/shard-group/agent_runs.py) finds them by command line.
public static class AgentRuns {
    public sealed record Run(int Pid, string Character, bool Stalled, int? IdleSeconds, string Needs);
    public sealed record Watcher(int Pid, string Agent, string Port, bool Restartable, IReadOnlyList<Run> Runs);
    public sealed record Answer(bool Ok, string? Error, IReadOnlyList<Watcher> Watchers, string Text);

    private const int MaxText = 60000;

    // stopRun / restartWatcher: a pid from the last answer, or null to only read the status.
    public static ProcessStartInfo Step(HostControl control, int? stopRun = null, int? restartWatcher = null) {
        var group = control.Group ?? throw new InvalidOperationException("No region group configured.");
        if (stopRun is <= 0 || restartWatcher is <= 0 || (stopRun != null && restartWatcher != null))
            throw new ArgumentException("Stop one run or restart one watcher at a time.");
        var step = new ProcessStartInfo(control.Python) { UseShellExecute = false, CreateNoWindow = true,
            WorkingDirectory = Path.GetDirectoryName(group.ShardScript)!, RedirectStandardInput = true, RedirectStandardOutput = true, RedirectStandardError = true };
        foreach (var argument in new[] { "-I", "-B", group.ShardScript, "--config", group.Config, "agents" }) step.ArgumentList.Add(argument);
        if (stopRun is { } run) { step.ArgumentList.Add("--stop-run"); step.ArgumentList.Add(run.ToString(CultureInfo.InvariantCulture)); }
        if (restartWatcher is { } watcher) { step.ArgumentList.Add("--restart-watcher"); step.ArgumentList.Add(watcher.ToString(CultureInfo.InvariantCulture)); }
        return step;
    }

    // shard_group.py agents: {"ok", "watchers": [{"pid", "agent", "port", "restartable", "runs": [{"pid", "character",
    // "stalled", "idle_s", "needs"}]}], "text"}; a stop or restart answers {"ok", "text"}.
    public static Answer Parse(int exit, string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{')) ?? "";
        JsonDocument? document;
        try { document = JsonDocument.Parse(line); } catch (JsonException) { document = null; }
        using (document) {
            if (document == null || document.RootElement.ValueKind != JsonValueKind.Object)
                return new Answer(false, $"The group script gave no answer (exit {exit}).", [], "");
            var json = document.RootElement;
            if (!(json.TryGetProperty("ok", out var ok) && ok.ValueKind == JsonValueKind.True))
                return new Answer(false, "Refused: " + Clean(Str(json, "refused") ?? Str(json, "error") ?? "no reason given", 300, false), [], "");
            var watchers = new List<Watcher>();
            if (json.TryGetProperty("watchers", out var list) && list.ValueKind == JsonValueKind.Array) {
                foreach (var w in list.EnumerateArray().Take(16)) {
                    if (w.ValueKind != JsonValueKind.Object || Int(w, "pid") is not { } pid) continue;
                    var runs = new List<Run>();
                    if (w.TryGetProperty("runs", out var rl) && rl.ValueKind == JsonValueKind.Array)
                        foreach (var r in rl.EnumerateArray().Take(32))
                            if (r.ValueKind == JsonValueKind.Object && Int(r, "pid") is { } runPid)
                                runs.Add(new Run(runPid, Clean(Str(r, "character") ?? "?", 40, false),
                                    r.TryGetProperty("stalled", out var s) && s.ValueKind == JsonValueKind.True, Int(r, "idle_s"),
                                    Clean(Str(r, "needs") ?? "", 300, false)));
                    watchers.Add(new Watcher(pid, Clean(Str(w, "agent") ?? "", 40, false), Clean(Str(w, "port") ?? "", 8, false),
                        w.TryGetProperty("restartable", out var re) && re.ValueKind == JsonValueKind.True, runs));
                }
            }
            return new Answer(true, null, watchers, Clean(Str(json, "text") ?? "", MaxText, true));
        }
    }

    public static Answer Request(HostControl control, int? stopRun = null, int? restartWatcher = null,
            Func<ProcessStartInfo, (int Exit, string Output)>? run = null) {
        var (exit, output) = (run ?? LocalHosting.RunCaptured)(Step(control, stopRun, restartWatcher));
        return Parse(exit, output);
    }

    public static string Label(Watcher watcher, Run run) =>
        $"{(watcher.Agent.Length > 0 ? watcher.Agent : "agent")} {run.Character} (pid {run.Pid}){(run.Stalled ? " - stalled" : "")}";

    private static int? Int(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var n) && n >= 0 ? n : null;

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
