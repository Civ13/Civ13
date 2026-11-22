using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Players in one region (the Host tab's selected region, "Players…"), and Send Player to Region:
// tick players, choose a region and a landing, Check (the world's dry run, nothing moves), then Send.
// The world checks everything again as it sends, one player at a time, through the ordinary travel
// record (Civ13 region_admin_send.dm); arrivals are confirmed in admin chat and under Recent transfers.
// Send freezes the chosen players at once (Val, 2026-11-22); the dialog then follows the send until it
// ends, so whoever was released or left is shown here. The hint line says why Send is off.
internal sealed class PlayersDialog : Form {
    private readonly HostControl control;
    private readonly string region;
    private readonly Action<string> log;
    private readonly CheckedListBox players = new() { Width = 520, Height = 180, CheckOnClick = true };
    private readonly ComboBox destination = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 260 };
    private readonly ComboBox landing = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 200 };
    private readonly TextBox at = new() { Width = 120, PlaceholderText = "x,y,z", Enabled = false };
    private readonly CheckBox ship = new() { Text = "Send the ship the first ticked player is aboard, with everyone aboard", AutoSize = true };
    private readonly TextBox result = new() { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, Width = 520, Height = 150 };
    private readonly Button refresh = new() { Text = "Refresh", AutoSize = true };
    private readonly Button check = new() { Text = "Check (dry run)", AutoSize = true };
    private readonly Button send = new() { Text = "Send", AutoSize = true, Enabled = false };
    private readonly Label hint = new() { AutoSize = true, MaximumSize = new Size(520, 0), Margin = new Padding(3, 4, 0, 6) };
    private readonly ToolTip tip = new() { AutoPopDelay = 30000, InitialDelay = 400, ReshowDelay = 100 };
    // Stops following a send when the dialog closes.
    private readonly CancellationTokenSource closed = new();
    private static readonly TimeSpan FollowEvery = TimeSpan.FromSeconds(3), FollowFor = TimeSpan.FromMinutes(15);
    private IReadOnlyList<RegionPlayers.Player> roster = [];
    private IReadOnlyList<RegionPlayers.Destination> places = [];
    // The request the last dry run answered; Send stays off until it matches the form again.
    private string? checkedRequest;
    private int checkedReady;
    // Recent transfers as last listed, so a followed send shows only what came after.
    private IReadOnlyList<string> recentBefore = [];
    private bool busy, following;

    public PlayersDialog(HostControl control, string region, string regionName, Action<string> log) {
        this.control = control;
        this.region = region;
        this.log = log;
        Text = "Players in " + regionName;
        StartPosition = FormStartPosition.CenterParent;
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", 9.75f);
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MinimizeBox = MaximizeBox = false;

        var layout = new TableLayoutPanel { AutoSize = true, ColumnCount = 1, Padding = new Padding(12) };
        layout.Controls.Add(new Label { AutoSize = true, MaximumSize = new Size(520, 0), Margin = new Padding(0, 0, 0, 8),
            Text = "Send players to another region with everything they wear and carry, their skills, research and languages, " +
                "exactly as on a trail." + Environment.NewLine +
                "Check is a dry run: it shows who can go and why anyone cannot. Nothing moves and nobody is frozen." + Environment.NewLine +
                "Send freezes the chosen players in place at once, checks them again, and only those still ready leave, one at a time. " +
                "Anyone no longer ready is released, and the reason is shown here." });
        layout.Controls.Add(players);
        var where = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        where.Controls.Add(new Label { Text = "To", AutoSize = true, Margin = new Padding(0, 7, 4, 0) });
        where.Controls.Add(destination);
        where.Controls.Add(new Label { Text = "Landing", AutoSize = true, Margin = new Padding(12, 7, 4, 0) });
        foreach (var (_, label) in RegionPlayers.Landings) landing.Items.Add(label);
        landing.SelectedIndex = 0;
        where.Controls.Add(landing);
        where.Controls.Add(at);
        layout.Controls.Add(where);
        layout.Controls.Add(ship);
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 8, 0, 0) };
        var close = new Button { Text = "Close", AutoSize = true, DialogResult = DialogResult.Cancel };
        buttons.Controls.Add(refresh);
        buttons.Controls.Add(check);
        buttons.Controls.Add(send);
        buttons.Controls.Add(close);
        layout.Controls.Add(buttons);
        layout.Controls.Add(hint);
        layout.Controls.Add(result);
        Controls.Add(layout);
        CancelButton = close;
        tip.SetToolTip(refresh, "List who is online here again. This clears the last Check.");
        tip.SetToolTip(check, "Dry run: asks the world who could go and why anyone could not. Nothing moves and nobody is frozen.");
        tip.SetToolTip(send, "Freezes the ticked players in place at once, checks them again, and sends those still ready one at a time. "
            + "Unlocks after a Check with at least one player ready, for the same choices.");
        UpdateHint();

        landing.SelectedIndexChanged += (_, _) => { at.Enabled = Landing() == "coords" && !ship.Checked; FormChanged(); };
        ship.CheckedChanged += (_, _) => { landing.Enabled = !ship.Checked; at.Enabled = Landing() == "coords" && !ship.Checked; FormChanged(); };
        destination.SelectedIndexChanged += (_, _) => FormChanged();
        at.TextChanged += (_, _) => FormChanged();
        players.ItemCheck += (_, _) => BeginInvoke(FormChanged);
        refresh.Click += async (_, _) => await LoadRoster();
        check.Click += async (_, _) => await Run(false);
        send.Click += async (_, _) => await Run(true);
        Shown += async (_, _) => await LoadRoster();
        FormClosed += (_, _) => { closed.Cancel(); tip.Dispose(); };
    }

    private string Landing() => RegionPlayers.Landings[Math.Max(0, landing.SelectedIndex)].Id;

    private void FormChanged() {
        if (checkedRequest != null && checkedRequest != Request()) {
            checkedRequest = null;
            send.Enabled = false;
        }
        UpdateHint();
    }

    // Why Send is on or off, in one line under the buttons (a disabled button shows no tooltip).
    private void UpdateHint() {
        hint.Text = following ? "Sending. The players stay frozen until they leave; this window follows the send until it ends."
            : busy ? "Asking the world..."
            : Keys().Count == 0 ? "Tick players, then Check."
            : To() == null ? "There is no other region to send to."
            : checkedRequest != null && checkedRequest == Request() ? $"Ready to send {checkedReady}. Send freezes them at once and checks them again."
            : "Check first: Send unlocks after a dry run with at least one player ready.";
    }

    private void SetBusy(bool now) {
        busy = now;
        if (IsDisposed) return;
        refresh.Enabled = check.Enabled = !now;
        send.Enabled = !now && checkedRequest != null;
        UpdateHint();
    }

    private void ShowRoster(RegionPlayers.Roster answer) {
        roster = answer.Players;
        players.Items.Clear();
        foreach (var player in roster)
            players.Items.Add(player.Ckey + " - " + player.Name + (player.Playing ? "" : " (not playing)") + (player.Aboard != null ? ", aboard the " + player.Aboard : "")
                + (player.At != null ? " at " + player.At : "") + (player.Held ? " (frozen for a send)" : ""));
        var keep = To();
        places = answer.Destinations;
        destination.Items.Clear();
        foreach (var place in places) destination.Items.Add(place.Label);
        var index = places.ToList().FindIndex(place => place.Id == keep);
        if (destination.Items.Count > 0) destination.SelectedIndex = Math.Max(0, index);
    }

    private List<string> Keys() => players.CheckedIndices.Cast<int>().Where(index => index < roster.Count).Select(index => roster[index].Ckey).ToList();

    private string? To() => destination.SelectedIndex >= 0 && destination.SelectedIndex < places.Count ? places[destination.SelectedIndex].Id : null;

    private string Request() => string.Join(",", Keys()) + "|" + To() + "|" + (ship.Checked ? "ship" : Landing() + "|" + at.Text.Trim());

    private async Task LoadRoster() {
        checkedRequest = null;
        SetBusy(true);
        try {
            var answer = await Task.Run(() => RegionPlayers.RunPlayers(control, region));
            if (IsDisposed) return;
            if (!answer.Ok) { result.Text = answer.Error ?? "No answer."; return; }
            ShowRoster(answer);
            recentBefore = answer.Recent;
            var lines = new List<string> { roster.Count == 0 ? "Nobody is online here." : roster.Count + " online." };
            if (answer.Running) lines.Add("A transfer is still running here. Players marked frozen are waiting to leave.");
            lines.Add(answer.Recent.Count == 0 ? "No transfers from or to here since the world started." : "Recent transfers:");
            lines.AddRange(answer.Recent.AsEnumerable().Reverse());
            result.Text = string.Join(Environment.NewLine, lines);
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException) {
            result.Text = "Could not list the players: " + e.Message;
        } finally {
            SetBusy(false);
        }
    }

    // After a send the world started: look every few seconds until it ends, the dialog closes or
    // 15 minutes pass (the world's hold lapses by itself by then). The list shows who is still frozen.
    private async Task Follow(RegionPlayers.SendAnswer sent, string to) {
        var stop = closed.Token;
        var clock = System.Diagnostics.Stopwatch.StartNew();
        RegionPlayers.Roster? latest = null;
        var state = RegionPlayers.FollowState.Running;
        following = true;
        players.Enabled = false;
        UpdateHint();
        try {
            while (state == RegionPlayers.FollowState.Running) {
                result.Text = RegionPlayers.DescribeFollow(sent, latest, recentBefore, (int)clock.Elapsed.TotalSeconds, state);
                try { await Task.Delay(FollowEvery, stop); } catch (OperationCanceledException) { return; }
                try {
                    latest = await Task.Run(() => RegionPlayers.RunPlayers(control, region));
                } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException) {
                    latest = new RegionPlayers.Roster(false, e.Message, [], [], [], false);
                }
                if (stop.IsCancellationRequested || IsDisposed) return;
                if (latest.Ok) {
                    ShowRoster(latest);
                    if (!latest.Running) state = RegionPlayers.FollowState.Ended;
                }
                if (state == RegionPlayers.FollowState.Running && clock.Elapsed >= FollowFor) state = RegionPlayers.FollowState.TimedOut;
            }
            result.Text = RegionPlayers.DescribeFollow(sent, latest, recentBefore, (int)clock.Elapsed.TotalSeconds, state);
            var fresh = latest is { Ok: true } ? RegionPlayers.NewRecent(recentBefore, latest.Recent) : [];
            log("Send Player to Region (" + region + " to " + to + ") " + (state == RegionPlayers.FollowState.Ended ? "ended" : "not followed further")
                + (fresh.Count > 0 ? ": " + string.Join("; ", fresh) : "."));
            if (latest is { Ok: true }) recentBefore = latest.Recent;
        } finally {
            following = false;
            if (!IsDisposed) players.Enabled = true;
        }
    }

    private async Task Run(bool really) {
        var keys = Keys();
        if (keys.Count == 0) { result.Text = "Tick at least one player."; return; }
        if (To() is not { } to) { result.Text = "Choose the region to send them to."; return; }
        if (ship.Checked) keys = keys.Take(1).ToList();
        var mode = ship.Checked ? "arrival" : Landing();
        string? spot = mode == "coords" ? at.Text.Trim().Replace(" ", "") : null;
        var request = Request();
        if (really && request != checkedRequest) { result.Text = "Check again first: the choice changed since the dry run."; send.Enabled = false; return; }
        if (really && MessageBox.Show(this, "Send them now?" + Environment.NewLine + Environment.NewLine
                    + "They are frozen in place immediately (no moving, interacting or using items) and checked again. Those still ready stay frozen until they leave, "
                    + "one at a time, with everything they carry, and continue in the other region. Anyone no longer ready is released at once.",
                "Send Player to Region", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
        var withShip = ship.Checked;
        SetBusy(true);
        try {
            var answer = await Task.Run(() => RegionPlayers.RunSend(control, region, keys, to, mode, spot, withShip, really));
            if (IsDisposed) return;
            result.Text = RegionPlayers.Describe(answer);
            if (really) {
                log("Send Player to Region (" + region + " to " + to + "): " + RegionPlayers.Describe(answer).Replace(Environment.NewLine, " "));
                checkedRequest = null;
                if (answer.Started) await Follow(answer, to);
            } else if (answer.Ok && answer.Send == "dry_run" && answer.Ready > 0) {
                checkedRequest = request;
                checkedReady = answer.Ready;
            }
        } catch (ArgumentException e) {
            result.Text = e.Message;
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException) {
            result.Text = "The request failed: " + e.Message;
        } finally {
            SetBusy(false);
        }
    }
}
