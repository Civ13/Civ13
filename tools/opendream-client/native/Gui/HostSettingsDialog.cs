using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Edits the host's own settings in the region group's overlays (HostSettings): config.local.txt,
// host.txt and the other config files kept outside git. Save writes the overlay only; Save and
// apply also runs shard_group.py config-apply so the regions get them without a rebuild, and
// each running world uses the new config from its next restart.
internal sealed class HostSettingsDialog : Form {
    private readonly HostControl control;
    private readonly IReadOnlyList<HostSettings.Location> locations;
    private readonly ComboBox place = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 260 };
    private readonly ComboBox file = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 260 };
    private readonly Label hint = new() { AutoSize = true, MaximumSize = new Size(720, 0), Margin = new Padding(0, 6, 0, 6) };
    private readonly TextBox editor = new() {
        Dock = DockStyle.Fill, Multiline = true, AcceptsReturn = true, AcceptsTab = true, ScrollBars = ScrollBars.Both, WordWrap = false,
        Font = new Font(FontFamily.GenericMonospace, 9.5f)
    };
    private readonly Label result = new() { AutoSize = true, MaximumSize = new Size(720, 0), Margin = new Padding(0, 6, 0, 0) };
    private readonly Button save = new() { Text = "Save", AutoSize = true };
    private readonly Button apply = new() { Text = "Save and apply to regions", AutoSize = true };
    private (int Place, int File) shown = (-1, -1);
    private string loaded = "";

    public HostSettingsDialog(HostControl control, IReadOnlyList<HostSettings.Location> locations) {
        this.control = control;
        this.locations = locations;
        Text = "Host settings";
        StartPosition = FormStartPosition.CenterParent;
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", 9.75f);
        MinimumSize = new Size(640, 480);
        Size = new Size(780, 600);

        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, Padding = new Padding(12) };
        layout.Controls.Add(new Label {
            AutoSize = true, MaximumSize = new Size(720, 0), Margin = new Padding(0, 0, 0, 8),
            Text = "These files live in the host's overlay folders, not in the Civ13 checkout, so pulls and updates never replace them. " +
                "The repository's config.txt stays the default; config.local.txt holds only this host's changes. Shared settings apply to " +
                "every region and a region's own settings go on top."
        });
        var pickers = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0) };
        pickers.Controls.Add(new Label { Text = "Settings for", AutoSize = true, Margin = new Padding(0, 7, 6, 0) });
        pickers.Controls.Add(place);
        pickers.Controls.Add(new Label { Text = "File", AutoSize = true, Margin = new Padding(12, 7, 6, 0) });
        pickers.Controls.Add(file);
        layout.Controls.Add(pickers);
        layout.Controls.Add(hint);
        layout.Controls.Add(editor);
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.Cancel };
        var folder = new LinkLabel { Text = "Open folder", AutoSize = true, Margin = new Padding(12, 9, 0, 0) };
        var token = new LinkLabel { Text = "Bug report GitHub token...", AutoSize = true, Margin = new Padding(12, 9, 0, 0) };
        buttons.Controls.Add(save);
        buttons.Controls.Add(apply);
        buttons.Controls.Add(close);
        buttons.Controls.Add(folder);
        buttons.Controls.Add(token);
        layout.Controls.Add(buttons);
        layout.Controls.Add(result);
        for (var row = 0; row < 3; row++) layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        Controls.Add(layout);
        CancelButton = close;

        foreach (var location in locations) place.Items.Add(location.Label);
        place.SelectedIndexChanged += (_, _) => ShowPlace();
        file.SelectedIndexChanged += (_, _) => ShowFile();
        save.Click += (_, _) => Save();
        apply.Click += async (_, _) => { if (!Dirty || Save()) await Apply(); };
        folder.LinkClicked += (_, _) => {
            if (Current is not { } location) return;
            try {
                Directory.CreateDirectory(location.Folder);
                System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(location.Folder) { UseShellExecute = true })?.Dispose();
            } catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.ComponentModel.Win32Exception) {
                result.Text = "Could not open " + location.Folder + ": " + e.Message;
            }
        };
        token.LinkClicked += (_, _) => SetBugReportToken();
        FormClosing += (_, e) => { if (!KeepChanges()) e.Cancel = true; };
        if (place.Items.Count > 0) place.SelectedIndex = 0;
    }

    // Puts BUG_REPORT_GITHUB_TOKEN into this place's config.local.txt (the editor shows it, unsaved),
    // so approved in-game bug reports become GitHub issues. Save and apply sends it to the regions.
    private void SetBugReportToken() {
        if (Current is null) return;
        if (CurrentFile != HostSettings.LocalConfig) {
            file.SelectedIndex = file.Items.IndexOf(HostSettings.LocalConfig);
            if (CurrentFile != HostSettings.LocalConfig) return;
        }
        using var ask = new Form {
            Text = "Bug report GitHub token", StartPosition = FormStartPosition.CenterParent, AutoScaleMode = AutoScaleMode.Dpi,
            Font = Font, FormBorderStyle = FormBorderStyle.FixedDialog, MinimizeBox = false, MaximizeBox = false, AutoSize = true,
            AutoSizeMode = AutoSizeMode.GrowAndShrink
        };
        var panel = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, AutoSize = true, Padding = new Padding(12) };
        panel.Controls.Add(new Label {
            AutoSize = true, MaximumSize = new Size(520, 0),
            Text = "Paste a fine-grained GitHub token with Issues: Read and write on the repository in BUG_REPORT_GITHUB_REPO " +
                "(Civ13/Civ13 by default). Approved in-game bug reports then become GitHub issues. It is added to " +
                Current.Label.ToLowerInvariant() + "; press Save and apply afterwards."
        });
        var input = new TextBox { Width = 500, UseSystemPasswordChar = true };
        panel.Controls.Add(input);
        var row = new FlowLayoutPanel { AutoSize = true };
        var ok = new Button { Text = "Add to config.local.txt", AutoSize = true, DialogResult = DialogResult.OK };
        var cancel = new Button { Text = "Cancel", AutoSize = true, DialogResult = DialogResult.Cancel };
        row.Controls.Add(ok);
        row.Controls.Add(cancel);
        panel.Controls.Add(row);
        ask.Controls.Add(panel);
        ask.AcceptButton = ok;
        ask.CancelButton = cancel;
        if (ask.ShowDialog(this) != DialogResult.OK) return;
        var value = input.Text.Trim();
        if (!HostSettings.TokenValid(value)) {
            result.Text = "That does not look like a GitHub token (letters, digits and _ only, at least 20). Nothing changed.";
            return;
        }
        editor.Text = HostSettings.WithSetting(editor.Text, HostSettings.BugReportToken, value).Replace("\n", "\r\n");
        result.Text = "Token added to the editor. Press Save and apply to send it to the regions; running worlds use it for the next report an admin approves.";
    }

    private HostSettings.Location? Current => place.SelectedIndex >= 0 ? locations[place.SelectedIndex] : null;
    private string? CurrentFile => file.SelectedItem as string;
    private bool Dirty => editor.Text.Replace("\r\n", "\n") != loaded;

    // False when the person wants to stay on unsaved changes.
    private bool KeepChanges() {
        if (!Dirty) return true;
        var answer = MessageBox.Show(this, "Save the changes to " + CurrentFile + " first?", "Host settings",
            MessageBoxButtons.YesNoCancel, MessageBoxIcon.Question);
        return answer == DialogResult.No || (answer == DialogResult.Yes && Save());
    }

    private void ShowPlace() {
        if (place.SelectedIndex == shown.Place) return;
        if (!KeepChanges()) { place.SelectedIndex = shown.Place; return; }
        shown = (place.SelectedIndex, -1);
        var previous = CurrentFile;
        file.Items.Clear();
        try {
            foreach (var name in HostSettings.Files(Current!)) file.Items.Add(name);
        } catch (Exception e) when (e is IOException or UnauthorizedAccessException) {
            result.Text = "Could not list " + Current!.Folder + ": " + e.Message;
        }
        var index = previous != null ? file.Items.IndexOf(previous) : -1;
        file.SelectedIndex = file.Items.Count == 0 ? -1 : Math.Max(index, 0);
        apply.Text = Current!.Region == null ? "Save and apply to every region" : "Save and apply to " + Current.Label.Replace(" only", "");
    }

    private void ShowFile() {
        if (file.SelectedIndex == shown.File) return;
        if (shown.File >= 0 && !KeepChanges()) { file.SelectedIndex = shown.File; return; }
        shown = (place.SelectedIndex, file.SelectedIndex);
        if (Current is not { } location || CurrentFile is not { } name) return;
        hint.Text = name + ": " + HostSettings.Describe(name);
        try {
            loaded = HostSettings.Read(location, name).Replace("\r\n", "\n");
            editor.Text = loaded.Replace("\n", "\r\n");
            result.Text = "";
        } catch (Exception e) when (e is IOException or UnauthorizedAccessException or InvalidDataException) {
            loaded = "";
            editor.Text = "";
            result.Text = "Could not read " + name + ": " + e.Message;
        }
    }

    private bool Save() {
        if (Current is not { } location || CurrentFile is not { } name) return false;
        var text = editor.Text.Replace("\r\n", "\n");
        try {
            HostSettings.Save(location, name, text);
            loaded = text;
            result.Text = "Saved " + name + " for " + location.Label.ToLowerInvariant() + ". The previous version is kept as " + Path.GetFileName(name) + ".previous.";
            return true;
        } catch (Exception e) when (e is IOException or UnauthorizedAccessException or InvalidDataException) {
            result.Text = "Not saved: " + e.Message;
            return false;
        }
    }

    private async Task Apply() {
        if (Current is not { } location) return;
        save.Enabled = apply.Enabled = false;
        result.Text = "Applying...";
        try {
            var answer = await Task.Run(() => LocalHosting.RunGroup(control, "config-apply", region: location.Region));
            result.Text = answer.Message;
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException) {
            result.Text = "Apply failed: " + e.Message;
        } finally {
            save.Enabled = apply.Enabled = true;
        }
    }
}
