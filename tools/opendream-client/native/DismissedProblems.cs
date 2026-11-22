using System.Text.Json;

namespace Civ13.Launcher;

// Problems the operator dismissed on the Host server tab's board, kept in dismissed-problems.json in the launcher
// data folder. Dismissing only hides a problem in this launcher; nothing on the host changes. A dismissal names
// the region, the problem and its occurrence (RegionProblem.Key), so a problem whose text changes, or the same
// failure happening again, shows again. Once a region answers without the problem, its dismissal is forgotten.
public sealed class DismissedProblems {
    public const string FileName = "dismissed-problems.json";
    private const int MaxKeys = 500;
    private readonly string? path;
    private readonly HashSet<string> keys = new(StringComparer.Ordinal);

    public DismissedProblems(string? root) {
        path = root == null ? null : Path.Combine(root, FileName);
        if (path == null) return;
        try {
            using var document = JsonDocument.Parse(File.ReadAllText(path));
            if (document.RootElement.ValueKind == JsonValueKind.Object && document.RootElement.TryGetProperty("keys", out var list) && list.ValueKind == JsonValueKind.Array)
                foreach (var key in list.EnumerateArray().Take(MaxKeys))
                    if (key.ValueKind == JsonValueKind.String && key.GetString() is { Length: > 0 and <= 2048 } text) keys.Add(text);
        } catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException) { }
    }

    public int Count => keys.Count;

    public bool IsDismissed(RegionCard card, RegionProblem problem) => keys.Contains(problem.Key(card.Id));

    public bool Shown(RegionCard card, RegionProblem problem) => !IsDismissed(card, problem);

    // How many of the board's problems are hidden now.
    public int Hidden(IReadOnlyList<RegionCard> cards) => cards.Sum(card => card.Problems.Count(problem => IsDismissed(card, problem)));

    public void Dismiss(IEnumerable<string> dismissed) {
        var changed = false;
        foreach (var key in dismissed) if (keys.Count < MaxKeys && key.Length <= 2048) changed |= keys.Add(key);
        if (changed) Save();
    }

    public void Restore(IEnumerable<string> restored) {
        var changed = false;
        foreach (var key in restored) changed |= keys.Remove(key);
        if (changed) Save();
    }

    // After a status read that answered: forget the dismissals of problems a region no longer has. A region that
    // is not on the board, or whose own status could not be read, keeps its dismissals until it answers.
    public bool Prune(IReadOnlyList<RegionCard> cards) {
        var stale = new List<string>();
        foreach (var card in cards) {
            if (card.Problems.Any(problem => problem.Kind == "status")) continue;
            var current = card.Problems.Select(problem => problem.Key(card.Id)).ToHashSet(StringComparer.Ordinal);
            stale.AddRange(keys.Where(key => key.StartsWith(card.Id + "\n", StringComparison.Ordinal) && !current.Contains(key)));
        }
        foreach (var key in stale) keys.Remove(key);
        if (stale.Count > 0) Save();
        return stale.Count > 0;
    }

    private void Save() {
        if (path == null) return;
        try {
            var temporary = path + ".tmp";
            File.WriteAllText(temporary, JsonSerializer.Serialize(new { schema = 1, keys = keys.Order(StringComparer.Ordinal).ToArray() }));
            File.Move(temporary, path, true);
        } catch (Exception e) when (e is IOException or UnauthorizedAccessException) {
            Console.WriteLine("Could not save the dismissed problems: " + e.Message);
        }
    }
}
