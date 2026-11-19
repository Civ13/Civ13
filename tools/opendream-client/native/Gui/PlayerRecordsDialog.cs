using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// All regions > More > "Player records…": the notes, warnings, bans, watchlist and memos every region shares
// (PlayerRecords.cs, shard_group.py records). Read-only: a summary with each region's copy of its old files,
// every record about one player, a search (a key, words or an IP), and an export of every record to a JSON file.
internal sealed class PlayerRecordsDialog : Form {
    private readonly HostControl control;
    private readonly TextBox entry = new() { Width = 300, PlaceholderText = "Player key, or words to search for" };
    private readonly Label summary = new() { AutoSize = true, MaximumSize = new Size(760, 0), Margin = new Padding(0, 8, 0, 8) };
    private readonly TextBox report = new() { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Both, WordWrap = false,
        Width = 760, Height = 440, Font = new Font(FontFamily.GenericMonospace, 9f) };
    private readonly Button lookUp = new() { Text = "Player", AutoSize = true };
    private readonly Button search = new() { Text = "Search", AutoSize = true };
    private readonly Button overview = new() { Text = "Summary", AutoSize = true };
    private readonly Button export = new() { Text = "Export…", AutoSize = true };
    private readonly Button copy = new() { Text = "Copy", AutoSize = true };

    public PlayerRecordsDialog(HostControl control) {
        this.control = control;
        Text = "Player records";
        StartPosition = FormStartPosition.CenterParent;
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", 9.75f);
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = MaximizeBox = false;

        var layout = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, Padding = new Padding(12) };
        layout.Controls.Add(new Label { AutoSize = true, MaximumSize = new Size(760, 0),
            Text = "Admin notes, warnings, bans, the watchlist and memos, shared by every region. Staff add and remove them in game " +
                "on any region; this window only reads them." });
        var finding = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        finding.Controls.Add(entry);
        finding.Controls.Add(lookUp);
        finding.Controls.Add(search);
        finding.Controls.Add(overview);
        layout.Controls.Add(finding);
        layout.Controls.Add(summary);
        layout.Controls.Add(report);
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.Cancel };
        buttons.Controls.Add(export);
        buttons.Controls.Add(copy);
        buttons.Controls.Add(close);
        layout.Controls.Add(buttons);
        Controls.Add(layout);
        CancelButton = close;
        AcceptButton = lookUp;

        lookUp.Click += async (_, _) => {
            if (entry.Text.Trim().Length == 0) { summary.Text = "Type a player key."; return; }
            await Fill("Player " + entry.Text.Trim(), () => PlayerRecords.Run(control, ckey: entry.Text));
        };
        search.Click += async (_, _) => {
            if (entry.Text.Trim().Length == 0) { summary.Text = "Type something to search for."; return; }
            await Fill("Search for " + entry.Text.Trim(), () => PlayerRecords.Run(control, search: entry.Text));
        };
        overview.Click += async (_, _) => await Fill("Summary", () => PlayerRecords.Run(control));
        export.Click += async (_, _) => {
            using var save = new SaveFileDialog { Filter = "JSON files (*.json)|*.json", FileName = $"player-records-{DateTime.Now:yyyy-MM-dd}.json",
                Title = "Export every player record" };
            if (save.ShowDialog(this) != DialogResult.OK) return;
            await Fill("Export", () => PlayerRecords.Run(control, export: save.FileName));
        };
        copy.Click += (_, _) => { if (report.TextLength > 0) Clipboard.SetText(report.Text); };
        Shown += async (_, _) => await Fill("Summary", () => PlayerRecords.Run(control));
    }

    private async Task Fill(string what, Func<PlayerRecords.Answer> ask) {
        lookUp.Enabled = search.Enabled = overview.Enabled = export.Enabled = false;
        summary.Text = "Reading the player records…";
        try {
            var answer = await Task.Run(ask);
            summary.Text = answer.Ok ? what + (answer.File != null ? $": {answer.Exported} records written to {answer.File}" : "") : answer.Error ?? "No answer.";
            if (answer.Ok) report.Text = answer.Text;
        } catch (ArgumentException e) {
            summary.Text = e.Message;
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException) {
            summary.Text = "The request failed: " + e.Message;
        } finally {
            lookUp.Enabled = search.Enabled = overview.Enabled = export.Enabled = true;
        }
    }
}
