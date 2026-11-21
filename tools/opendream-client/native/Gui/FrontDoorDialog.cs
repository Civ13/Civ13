using System.ComponentModel;
using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// All regions > More > "Front door and ports…". The front door is the region on the public port: the world
// players and the Discord Play button join, which the bot watches. Choosing another region here is the whole
// job: the host script (Civ13 scripts/shard-group/group_ports.py, GroupPorts.cs) shows what it will do, then
// saves and stops the two worlds, swaps their ports, moves the bot's settings and starts them again, the new
// front door first. The list below shows every port the group uses and which ones the router must forward.
internal sealed class FrontDoorDialog : Form {
    private readonly HostControl control;
    private readonly string? botProfile;
    private readonly Action<string> log;
    private readonly Func<Task>? restartBot;
    private readonly Label summary = new() { AutoSize = true, MaximumSize = new Size(620, 0), Margin = new Padding(0, 0, 0, 8) };
    private readonly ComboBox gatePicker = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 220 };
    private readonly Button moveGate = new() { Text = "Make this the front door", AutoSize = true, Enabled = false };
    private readonly ComboBox portPicker = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 220 };
    private readonly NumericUpDown portNumber = new() { Minimum = 1024, Maximum = 65535, Width = 80 };
    private readonly Button movePort = new() { Text = "Change port", AutoSize = true, Enabled = false };
    private readonly Button addGateway = new() { Text = "Add a gateway world", AutoSize = true, Enabled = false };
    private readonly TextBox result = new() { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, Width = 620, Height = 150 };
    private readonly ListView ports = new() { View = View.Details, FullRowSelect = true, Width = 620, Height = 220, HeaderStyle = ColumnHeaderStyle.Nonclickable };
    private readonly Button refresh = new() { Text = "Refresh", AutoSize = true };
    private readonly System.Windows.Forms.Timer poll = new() { Interval = 3000 };
    private IReadOnlyList<GroupPorts.Choice> choices = [];
    private string? gate;
    private bool busy;
    private bool following;
    private bool botRestarted;

    public FrontDoorDialog(HostControl control, string? botProfile, Action<string> log, Func<Task>? restartBot) {
        this.control = control;
        this.botProfile = botProfile;
        this.log = log;
        this.restartBot = restartBot;
        Text = "Front door and ports";
        StartPosition = FormStartPosition.CenterParent;
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", 9.75f);
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = MaximizeBox = false;

        var layout = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, Padding = new Padding(12) };
        layout.Controls.Add(new Label { AutoSize = true, MaximumSize = new Size(620, 0), Margin = new Padding(0, 0, 0, 8),
            Text = "The front door is the region players join first: the launcher, the hub and the Discord Play button all lead there, " +
                "and it sends each player on to the land their character lives in. Pick another region to move it. The two regions " +
                "are saved, swap places and start again by themselves, so the address players use never changes." });
        layout.Controls.Add(summary);
        var door = new FlowLayoutPanel { AutoSize = true, WrapContents = false };
        door.Controls.Add(new Label { Text = "Front door:", AutoSize = true, Margin = new Padding(0, 7, 6, 0) });
        door.Controls.Add(gatePicker);
        door.Controls.Add(moveGate);
        layout.Controls.Add(door);
        var port = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0, 6, 0, 0) };
        port.Controls.Add(new Label { Text = "Game port of", AutoSize = true, Margin = new Padding(0, 7, 6, 0) });
        port.Controls.Add(portPicker);
        port.Controls.Add(portNumber);
        port.Controls.Add(movePort);
        layout.Controls.Add(port);
        var gateway = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0, 6, 0, 0) };
        gateway.Controls.Add(addGateway);
        gateway.Controls.Add(new Label { AutoSize = true, MaximumSize = new Size(440, 0), Margin = new Padding(6, 0, 0, 0),
            Text = "A small world that keeps the front door's port for good and sends everyone on to their land, so the hub " +
                "listing never drops when a land restarts. Add it, then make it the front door." });
        layout.Controls.Add(gateway);
        result.Margin = new Padding(0, 8, 0, 8);
        layout.Controls.Add(result);
        foreach (var (title, width) in new[] { ("Port", 60), ("Used for", 150), ("Region", 170), ("Forward on router", 130), ("In use now", 90) })
            ports.Columns.Add(title, width);
        layout.Controls.Add(ports);
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.Cancel };
        buttons.Controls.Add(refresh);
        buttons.Controls.Add(close);
        layout.Controls.Add(buttons);
        Controls.Add(layout);
        CancelButton = close;

        gatePicker.SelectedIndexChanged += (_, _) => UpdateButtons();
        portPicker.SelectedIndexChanged += (_, _) => {
            if (Picked(portPicker) is { Port: > 0 } choice) portNumber.Value = Math.Clamp(choice.Port, 1024, 65535);
            UpdateButtons();
        };
        portNumber.ValueChanged += (_, _) => UpdateButtons();
        moveGate.Click += async (_, _) => {
            if (Picked(gatePicker) is { } choice)
                await Change("Make " + choice.Name + " the front door", apply => GroupPorts.RunGate(control, choice.Id, apply, botProfile));
        };
        movePort.Click += async (_, _) => {
            if (Picked(portPicker) is { } choice) {
                var number = (int)portNumber.Value;
                await Change("Move " + choice.Name + " to port " + number, apply => GroupPorts.RunPort(control, choice.Id, number, apply, botProfile));
            }
        };
        addGateway.Click += async (_, _) => await AddGateway();
        refresh.Click += async (_, _) => await Reload(true);
        poll.Tick += async (_, _) => await Reload(false);
        Shown += async (_, _) => await Reload(true);
        FormClosed += (_, _) => poll.Dispose();
    }

    private GroupPorts.Choice? Picked(ComboBox picker) => picker.SelectedIndex >= 0 && picker.SelectedIndex < choices.Count ? choices[picker.SelectedIndex] : null;

    private void UpdateButtons() {
        var idle = !busy && !following;
        gatePicker.Enabled = portPicker.Enabled = portNumber.Enabled = refresh.Enabled = idle;
        // The current front door can be chosen again: that only checks its files, the bot and the worlds.
        moveGate.Enabled = idle && gate != null && Picked(gatePicker) != null;
        moveGate.Text = Picked(gatePicker)?.Id == gate ? "Check the front door" : "Make this the front door";
        movePort.Enabled = idle && Picked(portPicker) is { } choice && choice.Port != (int)portNumber.Value;
        addGateway.Enabled = idle && gate != null;
    }

    // Adds and starts a gateway world beside the front door (no ports move yet), then lists it as a front door choice.
    private async Task AddGateway() {
        if (busy || following) return;
        busy = true;
        UpdateButtons();
        try {
            result.Text = "Checking...";
            var plan = await Task.Run(() => GroupPorts.RunAddGateway(control, false));
            result.Text = GroupPorts.Describe(plan);
            if (!plan.Ok || plan.Already || plan.Problems.Count > 0) return;
            if (MessageBox.Show(this, GroupPorts.Describe(plan) + Environment.NewLine + Environment.NewLine + "Continue?", "Add a gateway world",
                    MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            var answer = await Task.Run(() => GroupPorts.RunAddGateway(control, true));
            result.Text = answer.Ok && answer.Accepted
                ? "The gateway is added and starting (its first start compiles it). Once the Host tab shows it running, pick it above and make it the front door."
                : GroupPorts.Describe(answer);
            if (answer.Ok && answer.Accepted) log("Gateway world added and starting.");
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            result.Text = "Could not ask the host script: " + e.Message;
        } finally {
            busy = false;
            UpdateButtons();
        }
        await Reload(true);
    }

    // Reads the ports and the last change. full: also the pickers (not while the operator may be choosing).
    private async Task Reload(bool full) {
        if (busy) return;
        busy = true;
        UpdateButtons();
        try {
            var report = await Task.Run(() => GroupPorts.RunReport(control));
            if (IsDisposed) return;
            summary.Text = GroupPorts.Summary(report);
            if (!report.Ok) { result.Text = report.Error; return; }
            gate = report.Gate;
            ports.BeginUpdate();
            ports.Items.Clear();
            foreach (var row in report.Ports)
                ports.Items.Add(new ListViewItem(new[] { row.Port.ToString(), row.Use + (row.Gate ? " (front door)" : ""), row.Name ?? row.Region ?? "",
                    row.Public ? "Yes" : "", row.Listening switch { true => "Yes", false => "No", null => "" } }));
            ports.EndUpdate();
            if (full) {
                try { choices = GroupPorts.GateChoices(control.Group!); }
                catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.Text.Json.JsonException or InvalidDataException) {
                    result.Text = "Could not read the group config: " + e.Message;
                    choices = [];
                }
                foreach (var picker in new[] { gatePicker, portPicker }) {
                    picker.Items.Clear();
                    foreach (var choice in choices) picker.Items.Add(choice.Name + (choice.Id == gate ? " (front door)" : ""));
                    picker.SelectedIndex = Math.Max(choices.Count > 0 ? 0 : -1, choices.ToList().FindIndex(choice => choice.Id == gate));
                }
            }
            if (report.Problems.Count > 0) result.Text = "Port problems:" + Environment.NewLine + string.Join(Environment.NewLine, report.Problems.Select(problem => "  - " + problem));
            if (report.Change is { } change && (following || change.Running)) {
                result.Text = GroupPorts.Describe(change);
                following = !GroupPorts.Finished(change);
                poll.Enabled = following;
                if (!following) await Finish(change);
            }
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            result.Text = "Could not ask the host script: " + e.Message;
        } finally {
            busy = false;
            if (!IsDisposed) UpdateButtons();
        }
    }

    private async Task Finish(GroupPorts.Change change) {
        log("Front door and ports: " + (change.Phase == "done" ? "done." : "failed: " + (change.Error ?? "no reason recorded")));
        if (change.Phase != "done") return;
        if (change.BotRestart && restartBot != null && !botRestarted) {
            botRestarted = true;
            result.AppendText(Environment.NewLine + "Restarting the bot so it follows the new front door...");
            await restartBot();
        }
        busy = false;
        await Reload(true);
    }

    // Shows the plan, asks once, then starts it and follows its progress.
    private async Task Change(string title, Func<bool, GroupPorts.Plan> run) {
        if (busy || following) return;
        busy = true;
        UpdateButtons();
        var started = false;
        try {
            result.Text = "Checking...";
            var plan = await Task.Run(() => run(false));
            result.Text = GroupPorts.Describe(plan);
            if (!plan.Ok || plan.Problems.Count > 0) return;
            if (MessageBox.Show(this, GroupPorts.Describe(plan) + Environment.NewLine + Environment.NewLine + "Continue?", title,
                    MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
            var answer = await Task.Run(() => run(true));
            result.Text = GroupPorts.Describe(answer);
            if (!answer.Ok || !answer.Accepted) return;
            log(title + ": started.");
            started = true;
            botRestarted = false;
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            result.Text = "Could not ask the host script: " + e.Message;
        } finally {
            busy = false;
            following = started;
            poll.Enabled = started;
            UpdateButtons();
        }
    }
}
