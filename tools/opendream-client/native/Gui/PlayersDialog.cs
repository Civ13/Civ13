using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Players in one region (the Host tab's selected region, "Players…"), and Send Player to Region:
// tick players, choose a region and a landing, Check (the world's dry run, nothing moves), then Send.
// The world checks everything again as it sends, one player at a time, through the ordinary travel
// record (Civ13 region_admin_send.dm); arrivals are confirmed in admin chat and under Recent transfers.
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
    private IReadOnlyList<RegionPlayers.Player> roster = [];
    private IReadOnlyList<RegionPlayers.Destination> places = [];
    // The request the last dry run answered; Send stays off until it matches the form again.
    private string? checkedRequest;

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
                "exactly as on a trail. Check shows who can go and why anyone cannot; nothing moves until you press Send." });
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
        layout.Controls.Add(result);
        Controls.Add(layout);
        CancelButton = close;

        landing.SelectedIndexChanged += (_, _) => { at.Enabled = Landing() == "coords" && !ship.Checked; FormChanged(); };
        ship.CheckedChanged += (_, _) => { landing.Enabled = !ship.Checked; at.Enabled = Landing() == "coords" && !ship.Checked; FormChanged(); };
        destination.SelectedIndexChanged += (_, _) => FormChanged();
        at.TextChanged += (_, _) => FormChanged();
        players.ItemCheck += (_, _) => BeginInvoke(FormChanged);
        refresh.Click += async (_, _) => await LoadRoster();
        check.Click += async (_, _) => await Run(false);
        send.Click += async (_, _) => await Run(true);
        Shown += async (_, _) => await LoadRoster();
    }

    private string Landing() => RegionPlayers.Landings[Math.Max(0, landing.SelectedIndex)].Id;

    private void FormChanged() {
        if (checkedRequest != null && checkedRequest != Request()) {
            checkedRequest = null;
            send.Enabled = false;
        }
    }

    private List<string> Keys() => players.CheckedIndices.Cast<int>().Where(index => index < roster.Count).Select(index => roster[index].Ckey).ToList();

    private string? To() => destination.SelectedIndex >= 0 && destination.SelectedIndex < places.Count ? places[destination.SelectedIndex].Id : null;

    private string Request() => string.Join(",", Keys()) + "|" + To() + "|" + (ship.Checked ? "ship" : Landing() + "|" + at.Text.Trim());

    private async Task LoadRoster() {
        refresh.Enabled = check.Enabled = send.Enabled = false;
        checkedRequest = null;
        try {
            var answer = await Task.Run(() => RegionPlayers.RunPlayers(control, region));
            if (!answer.Ok) { result.Text = answer.Error ?? "No answer."; return; }
            roster = answer.Players;
            players.Items.Clear();
            foreach (var player in roster)
                players.Items.Add(player.Ckey + " - " + player.Name + (player.Playing ? "" : " (not playing)") + (player.Aboard != null ? ", aboard the " + player.Aboard : "")
                    + (player.At != null ? " at " + player.At : ""));
            var keep = To();
            places = answer.Destinations;
            destination.Items.Clear();
            foreach (var place in places) destination.Items.Add(place.Label);
            var index = places.ToList().FindIndex(place => place.Id == keep);
            if (destination.Items.Count > 0) destination.SelectedIndex = Math.Max(0, index);
            var lines = new List<string> { roster.Count == 0 ? "Nobody is online here." : roster.Count + " online." };
            if (answer.Running) lines.Add("A transfer is still running here.");
            lines.Add(answer.Recent.Count == 0 ? "No transfers from or to here since the world started." : "Recent transfers:");
            lines.AddRange(answer.Recent.AsEnumerable().Reverse());
            result.Text = string.Join(Environment.NewLine, lines);
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException) {
            result.Text = "Could not list the players: " + e.Message;
        } finally {
            refresh.Enabled = check.Enabled = true;
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
        if (really && MessageBox.Show(this, "Send them now? Each one leaves this region with everything they carry and continues in the other.",
                "Send Player to Region", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
        refresh.Enabled = check.Enabled = send.Enabled = false;
        try {
            var answer = await Task.Run(() => RegionPlayers.RunSend(control, region, keys, to, mode, spot, ship.Checked, really));
            result.Text = RegionPlayers.Describe(answer);
            if (really) {
                log("Send Player to Region (" + region + " to " + to + "): " + RegionPlayers.Describe(answer).Replace(Environment.NewLine, " "));
                checkedRequest = null;
            } else if (answer.Ok && answer.Send == "dry_run" && answer.Ready > 0) {
                checkedRequest = request;
            }
        } catch (ArgumentException e) {
            result.Text = e.Message;
        } catch (Exception e) when (e is System.ComponentModel.Win32Exception or IOException or InvalidOperationException) {
            result.Text = "The request failed: " + e.Message;
        } finally {
            refresh.Enabled = check.Enabled = true;
            send.Enabled = checkedRequest != null;
        }
    }
}
