using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// All regions > More > "Player activity…": the host report of who is active and what they do (PlayerActivity.cs,
// shard_group.py activity, Civ13 docs/player-activity.md). Read-only; opening it reads new lines from every region.
internal sealed class PlayerActivityDialog : Form {
    private readonly HostControl control;
    private readonly Label summary = new() { AutoSize = true, MaximumSize = new Size(720, 0), Margin = new Padding(0, 0, 0, 8) };
    private readonly TextBox report = new() { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Both, WordWrap = false,
        Width = 720, Height = 440, Font = new Font(FontFamily.GenericMonospace, 9f) };
    private readonly Button refresh = new() { Text = "Refresh", AutoSize = true };
    private readonly Button copy = new() { Text = "Copy", AutoSize = true };

    public PlayerActivityDialog(HostControl control) {
        this.control = control;
        Text = "Player activity";
        StartPosition = FormStartPosition.CenterParent;
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", 9.75f);
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = MaximizeBox = false;

        var layout = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, Padding = new Padding(12) };
        layout.Controls.Add(summary);
        layout.Controls.Add(report);
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.Cancel };
        buttons.Controls.Add(refresh);
        buttons.Controls.Add(copy);
        buttons.Controls.Add(close);
        layout.Controls.Add(buttons);
        Controls.Add(layout);
        CancelButton = close;

        refresh.Click += async (_, _) => await Fill();
        copy.Click += (_, _) => { if (report.TextLength > 0) Clipboard.SetText(report.Text); };
        Shown += async (_, _) => await Fill();
    }

    private async Task Fill() {
        refresh.Enabled = false;
        summary.Text = "Reading every region…";
        try {
            var answer = await Task.Run(() => PlayerActivity.Run(control));
            summary.Text = PlayerActivity.Describe(answer);
            report.Text = answer.Ok ? answer.Text : "";
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException) {
            summary.Text = "The request failed: " + e.Message;
        } finally {
            refresh.Enabled = true;
        }
    }
}
