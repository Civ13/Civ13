using System.Diagnostics;

namespace Civ13.Launcher;

public static class CommunityLinks {
    public static readonly IReadOnlyDictionary<string, (string Label, string Url)> Items =
        new Dictionary<string, (string, string)> {
            ["5"] = ("Website", "https://civ13.com/"),
            ["6"] = ("Wiki", "https://civ13.github.io/civ13-wiki/"),
            ["7"] = ("Discord", "https://civ13.com/discord"),
            ["8"] = ("GitHub", "https://github.com/civ13/civ13/")
        };

    public static bool TryOpen(string choice, Action<ProcessStartInfo> open, TextWriter output) {
        if (!Items.TryGetValue(choice, out var link)) return false;
        try {
            open(new ProcessStartInfo(link.Url) { UseShellExecute = true });
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or InvalidOperationException or IOException) {
            output.WriteLine($"Could not open {link.Label}: {e.Message}");
            output.WriteLine($"Open this address in your browser: {link.Url}");
        }
        return true;
    }
}
