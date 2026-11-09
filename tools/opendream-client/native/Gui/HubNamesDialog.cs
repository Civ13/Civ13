using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// The name each world shows on the BYOND hub (SERVER_NAME), one box per overlay: the shared one for
// every region, then each region's own. It writes only the SERVER_NAME line of that overlay's
// config.local.txt (HostSettings.WithServerName); an empty box removes the line, so the region
// follows the shared name, then the repository's. Save and apply runs config-apply for the group;
// each running world shows the new name from its next restart or handover.
internal sealed class HubNamesDialog : Form {
    private readonly HostControl control;
    private readonly IReadOnlyList<HostSettings.Location> locations;
    private readonly List<TextBox> boxes = [];
    private readonly List<string> loaded = [];
    private readonly Label result = new() { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(0, 8, 0, 0) };
    private readonly Button apply = new() { Text = "Save and apply to every region", AutoSize = true };

    public HubNamesDialog(HostControl control, IReadOnlyList<HostSettings.Location> locations) {
        this.control = control;
        this.locations = locations;
        Text = "Hub names";
        StartPosition = FormStartPosition.CenterParent;
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", 9.75f);
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = MaximizeBox = false;

        var layout = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, Padding = new Padding(12) };
        layout.Controls.Add(new Label {
            AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(0, 0, 0, 8),
            Text = "The name each world shows in bold on the BYOND hub and in the game window's title (SERVER_NAME). " +
                "Leave a region empty to use the shared name, or \"" + HostSettings.DefaultServerName + "\" from the repository. " +
                "Quotes, backslashes and < > are not allowed. Running worlds show a new name from their next restart or handover."
        });
        var grid = new TableLayoutPanel { AutoSize = true, ColumnCount = 3, Margin = new Padding(0) };
        foreach (var location in locations) {
            string current;
            try { current = HostSettings.SettingValue(HostSettings.Read(location, HostSettings.LocalConfig), HostSettings.ServerName) ?? ""; }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException or InvalidDataException) { current = ""; result.Text = "Could not read " + location.Folder + ": " + e.Message; }
            var box = new TextBox { Width = 300, Text = current, MaxLength = HostSettings.ServerNameLength, Margin = new Padding(8, 4, 0, 4) };
            boxes.Add(box);
            loaded.Add(current);
            grid.Controls.Add(new Label { Text = location.Region == null ? "Every region" : location.Label.Replace(" only", ""), AutoSize = true, Margin = new Padding(0, 8, 0, 0) });
            grid.Controls.Add(box);
            grid.Controls.Add(new Label { Text = NowText(location), AutoSize = true, ForeColor = SystemColors.GrayText, Margin = new Padding(8, 8, 0, 0) });
        }
        layout.Controls.Add(grid);
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.Cancel };
        var fill = new LinkLabel { Text = "Name each region after itself", AutoSize = true, Margin = new Padding(12, 9, 0, 0) };
        buttons.Controls.Add(apply);
        buttons.Controls.Add(close);
        buttons.Controls.Add(fill);
        layout.Controls.Add(buttons);
        layout.Controls.Add(result);
        Controls.Add(layout);
        CancelButton = close;

        apply.Click += async (_, _) => { if (Save()) await Apply(); };
        fill.LinkClicked += (_, _) => FillRegionNames();
    }

    private string NowText(HostSettings.Location location) {
        if (location.Region == null) return "";
        try { return HostSettings.RegionServerName(control.Group!, location.Region) is { } name ? "now: " + name : "not set up yet"; }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.Text.Json.JsonException or ArgumentException) { return ""; }
    }

    // "<shared name> - <region>" in every region box, from the shared box (or the default name).
    private void FillRegionNames() {
        var shared = locations.Select((location, index) => (location, index)).FirstOrDefault(pair => pair.location.Region == null);
        var stem = shared.location != null && boxes[shared.index].Text.Trim() is { Length: > 0 } text ? text : HostSettings.DefaultServerName;
        for (var index = 0; index < locations.Count; index++)
            if (locations[index].Region != null) {
                var name = stem + " - " + locations[index].Label.Replace(" only", "");
                boxes[index].Text = name.Length > HostSettings.ServerNameLength ? name[..HostSettings.ServerNameLength].TrimEnd() : name;
            }
        result.Text = "Filled in; press Save and apply to keep them.";
    }

    private bool Save() {
        for (var index = 0; index < locations.Count; index++)
            if (HostSettings.ServerNameProblem(boxes[index].Text) is { } problem) {
                result.Text = (locations[index].Region == null ? "Every region" : locations[index].Label.Replace(" only", "")) + ": " + problem + " Nothing saved.";
                boxes[index].Focus();
                return false;
            }
        var saved = 0;
        for (var index = 0; index < locations.Count; index++) {
            var name = boxes[index].Text.Trim();
            if (name == loaded[index]) continue;
            var location = locations[index];
            try {
                var text = HostSettings.Read(location, HostSettings.LocalConfig).Replace("\r\n", "\n");
                HostSettings.Save(location, HostSettings.LocalConfig, HostSettings.WithServerName(text, name));
                loaded[index] = name;
                saved++;
            } catch (Exception e) when (e is IOException or UnauthorizedAccessException or InvalidDataException) {
                result.Text = "Not saved for " + location.Label.ToLowerInvariant() + ": " + e.Message;
                return false;
            }
        }
        result.Text = saved == 0 ? "No names changed; applying anyway..." : "Saved " + saved + " name" + (saved == 1 ? "" : "s") + "; applying...";
        return true;
    }

    private async Task Apply() {
        apply.Enabled = false;
        try {
            var answer = await Task.Run(() => LocalHosting.RunGroup(control, "config-apply"));
            result.Text = answer.Message + " Running worlds show the new name from their next restart or handover.";
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException) {
            result.Text = "Apply failed: " + e.Message;
        } finally {
            apply.Enabled = true;
        }
    }
}
