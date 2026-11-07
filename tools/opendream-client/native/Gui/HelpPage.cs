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
    private Button? helpStart, helpStop;
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
        helpStart = new Button { Text = "Start", AutoSize = true, Enabled = false, Margin = new Padding(0, 6, 0, 6) };
        helpStart.Click += async (_, _) => await RunHelp(control, "help-start");
        helpStop = new Button { Text = "Stop", AutoSize = true, Enabled = false, Margin = new Padding(8, 6, 0, 6) };
        helpStop.Click += async (_, _) => {
            if (MessageBox.Show(this, "Stop player help? Players are told help is unavailable until it is started again.", "Civ13 Launcher",
                    MessageBoxButtons.OKCancel, MessageBoxIcon.Question) == DialogResult.OK) await RunHelp(control, "help-stop");
        };
        buttons.Controls.Add(helpStart);
        buttons.Controls.Add(helpStop);
        helpLogChoice = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 160, Margin = new Padding(12, 8, 0, 6) };
        helpLogChoice.SelectedIndexChanged += (_, _) => RefreshHelpLog(true);
        buttons.Controls.Add(helpLogChoice);
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
                helpLogChoice.Items.Clear();
                helpLogChoice.Items.AddRange(names);
                if (names.Length > 0) helpLogChoice.SelectedIndex = 0;
            }
        }
        UpdateHelpButtons();
    }

    private void UpdateHelpButtons() {
        var status = helpStatus;
        var usable = !helpBusy && status is { Ok: true, Configured: true };
        if (helpStart != null) helpStart.Enabled = usable && (status!.Stopped || status.Regions.Any(region => !region.Running));
        if (helpStop != null) helpStop.Enabled = usable && (!status!.Stopped || status.AnyRunning);
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

    private async Task RunHelp(HostControl control, string action) {
        if (helpBusy || helpState == null) return;
        helpBusy = true;
        UpdateHelpButtons();
        helpState.Text = action == "help-stop" ? "Stopping player help (waits for answers in progress)..." : "Starting player help...";
        string line;
        try {
            var (exit, output) = await Task.Run(() => LocalHosting.RunCaptured(LocalHosting.GroupStep(control, action)));
            line = LocalHelp.DescribeAction(action, exit, output);
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) { line = "Player help: " + e.Message; }
        Console.WriteLine(line);
        helpBusy = false;
        await RefreshHelp(control);
        helpState.Text = line + Environment.NewLine + helpState.Text;
        RefreshHelpLog(true);
    }
}
