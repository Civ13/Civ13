using System.Text.Json;

namespace Civ13.Launcher;

// The Edge chat translator (tools/edge-translator) that the host service keeps running for the group
// (shard_group.py translator-status / translator-start / translator-stop, configured by "chat_translator"
// in the group config). Every region's config gets its address, so the worlds translate chat through it.
public sealed record TranslatorStatus(bool Ok, bool Configured, bool Running, bool Answering, bool Stopped, int? Pid, int? Port,
    int? StartedSecondsAgo, int? Translated, int? Failed, int? Waiting, string? Log, string? Error) {
    // Edge takes a little while to open; after two minutes a service that does not answer is stuck.
    public bool Stuck => Running && !Answering && StartedSecondsAgo is > 120;

    public string Describe() {
        if (!Ok) return "Status unavailable: " + (Error ?? "no answer");
        if (!Configured) return "Not set up: add \"chat_translator\": {} to the group config so the host service runs it.";
        if (!Running) return Stopped ? "Stopped on request; the host service leaves it stopped until Start. Chat is shown untranslated."
            : "Not running; the host service starts it within a minute.";
        var line = $"Running (PID {Pid}) on port {Port}";
        line += Answering ? ", answering" : Stuck ? ", not answering" : ", opening Edge";
        if (Translated is { } done) line += $". Translated {done} lines" + (Failed is > 0 ? $", {Failed} failed" : "") + (Waiting is > 0 ? $", {Waiting} waiting" : "");
        return line + ".";
    }
}

public static class LocalTranslator {
    public static TranslatorStatus ParseStatus(int exit, string output) {
        TranslatorStatus Fail(string error) => new(false, false, false, false, false, null, null, null, null, null, null, null, error);
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{'));
        if (line == null) return Fail(LocalBot.FailureText(exit, output));
        try {
            using var document = JsonDocument.Parse(line);
            var json = document.RootElement;
            if (json.ValueKind != JsonValueKind.Object || !json.TryGetProperty("ok", out var ok) || ok.ValueKind != JsonValueKind.True)
                return Fail(json.ValueKind == JsonValueKind.Object ? LocalBot.Str(json, "error") ?? LocalBot.Str(json, "refused") ?? $"exit {exit}" : $"exit {exit}");
            if (!LocalBot.Bool(json, "configured")) return new TranslatorStatus(true, false, false, false, false, null, null, null, null, null, null, null, null);
            int? stat(string name) => json.TryGetProperty("stats", out var stats) && stats.ValueKind == JsonValueKind.Object ? Int(stats, name) : null;
            return new TranslatorStatus(true, true, LocalBot.Bool(json, "running"), LocalBot.Bool(json, "answering"), LocalBot.Bool(json, "stopped"),
                Int(json, "pid"), Int(json, "port"), Int(json, "started_seconds_ago"), stat("translated"), stat("failed"), stat("waiting"), LocalBot.Str(json, "log"), null);
        } catch (JsonException) { return Fail($"exit {exit}"); }
    }

    // translator-start and translator-stop: one line for the window.
    public static string DescribeAction(string action, int exit, string output) {
        var line = output.Split('\n').Select(text => text.Trim()).LastOrDefault(text => text.StartsWith('{'));
        if (line == null) return "Chat translator: " + LocalBot.FailureText(exit, output);
        try {
            using var document = JsonDocument.Parse(line);
            var json = document.RootElement;
            if (json.ValueKind != JsonValueKind.Object) return $"Chat translator: exit {exit}";
            if (!LocalBot.Bool(json, "ok")) return "Chat translator: " + (LocalBot.Str(json, "refused") ?? LocalBot.Str(json, "error") ?? $"exit {exit}");
            if (action == "translator-stop")
                return LocalBot.Str(json, "not_ended") is { } refused ? "Chat translator kept stopped, but its process was not ended: " + refused
                    : LocalBot.Bool(json, "stopped") ? "Chat translator stopped." : "Chat translator was not running; it stays stopped.";
            return LocalBot.Bool(json, "started") ? "Chat translator started; Edge opens in the background." : "Chat translator is running.";
        } catch (JsonException) { return $"Chat translator: exit {exit}"; }
    }

    private static int? Int(JsonElement json, string name) =>
        json.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var number) ? number : null;
}
