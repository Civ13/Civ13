using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// All regions > More > "Windows process check (experimental)…" (WmiHealth.cs): whether Windows' WMI service
// answers, and the usual repairs, one button each. Checking only reads. Every repair needs administrator
// rights and runs only when clicked, after a confirmation and Windows' own elevation prompt.
internal sealed class WmiHealthDialog : Form {
    private readonly string root;
    private readonly Label summary = new() { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(0, 0, 0, 8) };
    private readonly TextBox log = new() { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, Width = 640, Height = 200,
        Font = new Font(FontFamily.GenericMonospace, 9f) };
    private readonly CheckBox watch = new() { AutoSize = true, Text = "Check automatically and warn on the host board (experimental)" };
    private readonly Button check = new() { Text = "Check now", AutoSize = true };
    private readonly List<Button> repairs = [];
    private WmiHealth.Diagnosis? last;

    public WmiHealthDialog(string root) {
        this.root = root;
        Text = "Windows process check (experimental)";
        StartPosition = FormStartPosition.CenterParent;
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", 9.75f);
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = MaximizeBox = false;

        var layout = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, Padding = new Padding(12) };
        layout.Controls.Add(new Label { AutoSize = true, MaximumSize = new Size(640, 0), Margin = new Padding(0, 0, 0, 8),
            Text = "When Windows' management service (WMI) stops answering, process tools such as tasklist hang, the host can fail " +
                "to start worlds, and Windows restarts can stick on \"Restarting\". Work through the steps in order and check again after each." });
        layout.Controls.Add(summary);
        foreach (var step in WmiHealth.Steps) {
            var button = new Button { Text = step.Title + "…", AutoSize = true, Enabled = false, Margin = new Padding(0, 2, 0, 0) };
            var tip = new ToolTip();
            tip.SetToolTip(button, step.Explanation);
            button.Disposed += (_, _) => tip.Dispose();
            button.Click += async (_, _) => await Repair(step);
            repairs.Add(button);
            layout.Controls.Add(button);
        }
        layout.Controls.Add(log);
        watch.Checked = WmiHealth.Enabled(root);
        watch.CheckedChanged += (_, _) => {
            try { WmiHealth.SetEnabled(root, watch.Checked); }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { Line("Could not save the setting: " + e.Message); }
        };
        layout.Controls.Add(watch);
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.Cancel };
        buttons.Controls.Add(check);
        buttons.Controls.Add(close);
        layout.Controls.Add(buttons);
        Controls.Add(layout);
        CancelButton = close;

        check.Click += async (_, _) => await Check();
        Shown += async (_, _) => await Check();
    }

    private void Line(string text) => log.AppendText($"[{DateTime.Now:T}] {text}{Environment.NewLine}");

    private void Busy(bool busy) {
        check.Enabled = !busy;
        foreach (var button in repairs) button.Enabled = !busy;
    }

    private async Task Check() {
        Busy(true);
        summary.Text = "Asking WMI (up to " + WmiHealth.QueryLimit.TotalSeconds.ToString("0") + " s)…";
        try {
            last = await Task.Run(() => WmiHealth.Check());
            summary.Text = WmiHealth.Describe(last);
            Line(last.State + ": " + last.Summary);
        } finally { Busy(false); }
    }

    private async Task Repair(WmiHealth.Step step) {
        if (step.NeedsServicePid && last?.ServicePid is not > 0) {
            MessageBox.Show(this, "The WMI service host's process id is not known yet. Click Check now first.", Text, MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }
        var question = step.Title + "?\n\n" + step.Explanation + "\n\nIt runs as administrator: Windows asks you to confirm.\n\n" +
            step.Command.Replace("{pid}", last?.ServicePid?.ToString() ?? "");
        if (MessageBox.Show(this, question, Text, MessageBoxButtons.OKCancel, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button2) != DialogResult.OK) return;
        Busy(true);
        Line("Running: " + step.Title);
        try {
            var output = await Task.Run(() => WmiHealth.RunElevated(step, last?.ServicePid));
            Line(output);
        } catch (System.ComponentModel.Win32Exception e) {
            Line("Not run: " + e.Message);
        } catch (Exception e) when (e is IOException or InvalidOperationException or InvalidDataException) {
            Line("Failed: " + e.Message);
        } finally { Busy(false); }
        await Check();
    }
}
