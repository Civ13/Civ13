using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Player help tab: the "Ask for help" bridges the host service keeps running, one per region. Stop asks
// them to finish their answers and keeps them stopped (the host service will not restart them) until Start.
// Unlike the bot, they belong to the host service, so closing the launcher leaves them as they are.
internal sealed partial class LauncherWindow {
    private Label? helpState;
    private TextBox? helpLog;
    private ComboBox? helpLogChoice;
    private Button? helpStart, helpStop, helpRegionStart, helpRegionStop;
    private HelpStatus? helpStatus;
    private bool helpBusy;

    private TabPage BuildHelpPage(HostControl control) {
        var page = new TabPage("Player help") { Padding = new Padding(10) };
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1 };
        layout.Controls.Add(new Label { AutoSize = true, Margin = new Padding(0, 3, 0, 6),
            Text = "\"Ask for help\" answers players through the local model. The host service starts it with the server and restarts it if it exits." });
        helpState = new Label { AutoSize = true, Margin = new Padding(0, 4, 0, 6), Text = "Checking..." };
        layout.Controls.Add(helpState);
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0) };
        helpStart = new Button { Text = "Start all", AutoSize = true, Enabled = false, Margin = new Padding(0, 6, 0, 6) };
        helpStart.Click += async (_, _) => await RunHelp(control, "help-start");
        helpStop = new Button { Text = "Stop all", AutoSize = true, Enabled = false, Margin = new Padding(8, 6, 0, 6) };
        helpStop.Click += async (_, _) => {
            if (MessageBox.Show(this, "Stop player help? Players are told help is unavailable until it is started again.", "Civ13 Launcher",
                    MessageBoxButtons.OKCancel, MessageBoxIcon.Question) == DialogResult.OK) await RunHelp(control, "help-stop");
        };
        buttons.Controls.Add(helpStart);
        buttons.Controls.Add(helpStop);
        // One region: the list holds every region of the group; its log is shown below.
        buttons.Controls.Add(new Label { Text = "Region:", AutoSize = true, Margin = new Padding(16, 11, 0, 6) });
        helpLogChoice = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 160, Margin = new Padding(6, 8, 0, 6) };
        helpLogChoice.SelectedIndexChanged += (_, _) => { RefreshHelpLog(true); UpdateHelpButtons(); };
        buttons.Controls.Add(helpLogChoice);
        helpRegionStart = new Button { Text = "Start region", AutoSize = true, Enabled = false, Margin = new Padding(8, 6, 0, 6) };
        helpRegionStart.Click += async (_, _) => { if (helpLogChoice.SelectedItem is string id) await RunHelp(control, "help-start", id); };
        helpRegionStop = new Button { Text = "Stop region", AutoSize = true, Enabled = false, Margin = new Padding(8, 6, 0, 6) };
        helpRegionStop.Click += async (_, _) => {
            if (helpLogChoice.SelectedItem is string id && MessageBox.Show(this, $"Stop player help in {id}? Its players are told help is unavailable until it is started again.",
                    "Civ13 Launcher", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) == DialogResult.OK) await RunHelp(control, "help-stop", id);
        };
        buttons.Controls.Add(helpRegionStart);
        buttons.Controls.Add(helpRegionStop);
        var folder = new LinkLabel { Text = "Open log folder", AutoSize = true, Margin = new Padding(12, 11, 0, 6) };
        folder.LinkClicked += (_, _) => {
            if (helpStatus?.Regions.FirstOrDefault()?.Log is { } log && Path.GetDirectoryName(log) is { } dir && Directory.Exists(dir))
                Open(new ProcessStartInfo(dir) { UseShellExecute = true }, "the player help log folder");
        };
        buttons.Controls.Add(folder);
        layout.Controls.Add(buttons);
        helpLog = new TextBox { Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Both, WordWrap = false,
            Font = new Font(FontFamily.GenericMonospace, 9f) };
        layout.Controls.Add(helpLog);
        for (var row = 0; row < 3; row++) layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        page.Controls.Add(layout);
        var poll = new System.Windows.Forms.Timer { Interval = 5000, Enabled = true };
        poll.Tick += async (_, _) => { if (tabs.SelectedTab == page) { await RefreshHelp(control); RefreshHelpLog(false); } };
        page.Enter += async (_, _) => { await RefreshHelp(control); RefreshHelpLog(true); };
        _ = RefreshHelp(control);
        return page;
    }

    private async Task RefreshHelp(HostControl control) {
        if (helpState == null) return;
        HelpStatus status;
        try {
            var (exit, output) = await Task.Run(() => LocalHosting.RunCaptured(LocalHosting.GroupStep(control, "help-status")));
            status = LocalHelp.ParseStatus(exit, output);
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            status = new HelpStatus(false, false, false, [], e.Message);
        }
        helpStatus = status;
        if (!helpBusy) helpState.Text = status.Describe();
        if (helpLogChoice != null) {
            var names = status.Regions.Select(region => region.Id).ToArray();
            if (!names.SequenceEqual(helpLogChoice.Items.Cast<string>())) {
                var keep = helpLogChoice.SelectedItem as string;
                helpLogChoice.Items.Clear();
                helpLogChoice.Items.AddRange(names);
                if (names.Length > 0) helpLogChoice.SelectedIndex = Math.Max(0, Array.IndexOf(names, keep));
            }
        }
        UpdateHelpButtons();
    }

    private void UpdateHelpButtons() {
        var status = helpStatus;
        var usable = !helpBusy && status is { Ok: true, Configured: true };
        if (helpStart != null) helpStart.Enabled = usable && (status!.Stopped || status.Regions.Any(region => !region.Running));
        if (helpStop != null) helpStop.Enabled = usable && (!status!.Stopped || status.AnyRunning);
        var chosen = usable && helpLogChoice?.SelectedItem is string id ? status!.Regions.FirstOrDefault(region => region.Id == id) : null;
        if (helpRegionStart != null) helpRegionStart.Enabled = chosen != null && (!chosen.Running || chosen.Wanted == false);
        if (helpRegionStop != null) helpRegionStop.Enabled = chosen != null && (chosen.Running || chosen.Wanted != false);
    }

    private void RefreshHelpLog(bool force) {
        if (helpLog == null || helpLogChoice?.SelectedItem is not string id || helpStatus == null) return;
        var path = helpStatus.Regions.FirstOrDefault(region => region.Id == id)?.Log;
        string text;
        try { text = path == null ? "" : LocalBot.Tail(path); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { text = "Could not read the log: " + e.Message; }
        if (!force && text == helpLog.Text) return;
        var atEnd = force || helpLog.SelectionStart >= helpLog.TextLength - 1;
        helpLog.Text = text;
        if (atEnd) { helpLog.SelectionStart = helpLog.TextLength; helpLog.ScrollToCaret(); }
    }

    // region: one region id, or null for every region of the group.
    private async Task RunHelp(HostControl control, string action, string? region = null) {
        if (helpBusy || helpState == null) return;
        helpBusy = true;
        UpdateHelpButtons();
        var which = region == null ? "" : " in " + region;
        helpState.Text = action == "help-stop" ? $"Stopping player help{which} (waits for answers in progress)..." : $"Starting player help{which}...";
        string line;
        try {
            var (exit, output) = await Task.Run(() => LocalHosting.RunCaptured(LocalHosting.GroupStep(control, action, region)));
            line = LocalHelp.DescribeAction(action, exit, output);
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) { line = "Player help: " + e.Message; }
        Console.WriteLine(line);
        helpBusy = false;
        await RefreshHelp(control);
        helpState.Text = line + Environment.NewLine + helpState.Text;
        RefreshHelpLog(true);
    }
}
