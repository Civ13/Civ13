using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// All regions > More > "AI characters…": Ada and other agent-driven characters on this host (AgentRuns.cs,
// shard_group.py agents). Shows each watcher and run with its latest needs and log, refreshes every 15 seconds,
// and can stop a hung run (its watcher plays the character again) or restart a watcher as it was started.
internal sealed class AgentRunsDialog : Form {
    private readonly HostControl control;
    private readonly Label summary = new() { AutoSize = true, MaximumSize = new Size(760, 0), Margin = new Padding(0, 0, 0, 8) };
    private readonly TextBox report = new() { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Both, WordWrap = false,
        Width = 760, Height = 420, Font = new Font(FontFamily.GenericMonospace, 9f) };
    private readonly ComboBox runs = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 420 };
    private readonly Button stop = new() { Text = "Stop run", AutoSize = true };
    private readonly Button restart = new() { Text = "Restart watcher", AutoSize = true };
    private readonly Button refresh = new() { Text = "Refresh", AutoSize = true };
    private readonly System.Windows.Forms.Timer timer = new() { Interval = 15000 };
    private bool busy;

    private sealed record Choice(AgentRuns.Watcher Watcher, AgentRuns.Run? Run, string Text) {
        public override string ToString() => Text;
    }

    public AgentRunsDialog(HostControl control) {
        this.control = control;
        Text = "AI characters";
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
        var pick = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        pick.Controls.Add(runs);
        pick.Controls.Add(stop);
        pick.Controls.Add(restart);
        layout.Controls.Add(pick);
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.Cancel };
        buttons.Controls.Add(refresh);
        buttons.Controls.Add(close);
        layout.Controls.Add(buttons);
        Controls.Add(layout);
        CancelButton = close;

        runs.SelectedIndexChanged += (_, _) => Enable();
        refresh.Click += async (_, _) => await Fill();
        stop.Click += async (_, _) => {
            if (runs.SelectedItem is not Choice { Run: { } run } choice) return;
            if (MessageBox.Show(this, $"Stop the run for {run.Character}? Its watcher plays the character again within a few minutes.",
                    "Stop run", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            await Act(() => AgentRuns.Request(control, stopRun: run.Pid));
        };
        restart.Click += async (_, _) => {
            if (runs.SelectedItem is not Choice choice) return;
            if (MessageBox.Show(this, $"Restart the watcher for agent {choice.Watcher.Agent}? Its runs stop and start again.",
                    "Restart watcher", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            await Act(() => AgentRuns.Request(control, restartWatcher: choice.Watcher.Pid));
        };
        timer.Tick += async (_, _) => { if (!busy) await Fill(); };
        Shown += async (_, _) => { await Fill(); timer.Start(); };
        FormClosed += (_, _) => timer.Dispose();
    }

    private void Enable() {
        var choice = runs.SelectedItem as Choice;
        stop.Enabled = !busy && choice?.Run != null;
        restart.Enabled = !busy && choice != null && choice.Watcher.Restartable;
        refresh.Enabled = !busy;
    }

    private async Task Act(Func<AgentRuns.Answer> action) {
        busy = true;
        Enable();
        summary.Text = "Working…";
        try {
            var answer = await Task.Run(action);
            summary.Text = answer.Ok ? answer.Text.Trim() : answer.Error ?? "No answer.";
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException or ArgumentException) {
            summary.Text = "The request failed: " + e.Message;
        } finally {
            busy = false;
        }
        await Fill(keepSummary: true);
    }

    private async Task Fill(bool keepSummary = false) {
        busy = true;
        Enable();
        if (!keepSummary) summary.Text = "Reading AI character runs…";
        try {
            var answer = await Task.Run(() => AgentRuns.Request(control));
            if (!answer.Ok) { if (!keepSummary) summary.Text = answer.Error ?? "No answer."; return; }
            report.Text = answer.Text;
            var selected = (runs.SelectedItem as Choice)?.Text;
            runs.Items.Clear();
            foreach (var watcher in answer.Watchers) {
                if (watcher.Runs.Count == 0)
                    runs.Items.Add(new Choice(watcher, null, $"{(watcher.Agent.Length > 0 ? watcher.Agent : "agent")} watcher (pid {watcher.Pid}), no character"));
                foreach (var run in watcher.Runs) runs.Items.Add(new Choice(watcher, run, AgentRuns.Label(watcher, run)));
            }
            var again = runs.Items.Cast<Choice>().FirstOrDefault(c => c.Text == selected);
            if (again != null) runs.SelectedItem = again; else if (runs.Items.Count > 0) runs.SelectedIndex = 0;
            if (!keepSummary) {
                var stalled = answer.Watchers.SelectMany(w => w.Runs).Count(r => r.Stalled);
                summary.Text = answer.Watchers.Count == 0 ? "No AI character watcher is running on this host."
                    : $"{answer.Watchers.Count} watcher(s), {answer.Watchers.Sum(w => w.Runs.Count)} character(s) being played"
                      + (stalled > 0 ? $", {stalled} stalled: select it and press Stop run." : ".");
            }
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException) {
            summary.Text = "The request failed: " + e.Message;
        } finally {
            busy = false;
            Enable();
        }
    }
}
