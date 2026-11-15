using System.ComponentModel;
using System.Drawing;
using System.Text.Json;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Updates tab: one row per hosted component (the server through gaia_host.py, or shard_group.py for a
// region group; the bot through control.php). Each check-update only fetches; Update uses the
// component's own update path. For a region group that is the whole save, pull, compile and restart
// (deploy.bat), so it is offered while the worlds are running.
// The Launcher row (Val, 2026-11-13) reads the stable launcher channel the startup check uses and installs a
// newer launcher on request: it is downloaded and verified, then the launcher restarts onto it.
// Checks run at startup, when the tab opens, and every 30 minutes while the launcher is open.
internal sealed partial class LauncherWindow {
    private static readonly TimeSpan UpdateCheckEvery = TimeSpan.FromMinutes(30);
    private TabPage? updatesPage;
    private StatusLine? serverUpdate, botUpdate, launcherUpdate;
    private Button? serverUpdateButton, botUpdateButton, launcherUpdateButton;
    private string? launcherLatest; // the stable channel's version when it is newer than this launcher
    private readonly List<Button> checkButtons = [];
    private UpdateCheck? serverCheck, botCheck;
    private DateTime lastUpdateCheckUtc = DateTime.MinValue;
    private bool checkingUpdates;
    private System.Windows.Forms.Timer? updateTimer;

    private TabPage BuildUpdatesPage(HostProfile profile) {
        var page = updatesPage = new TabPage("Updates") { Padding = new Padding(10) };
        var layout = new TableLayoutPanel { Dock = DockStyle.Top, AutoSize = true, ColumnCount = 4 };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        (StatusLine, Button) Row(string name, Func<Task> update) {
            layout.Controls.Add(new Label { Text = name, AutoSize = true, Font = new Font(Font, FontStyle.Bold), Margin = new Padding(0, 9, 12, 3) });
            var state = new StatusLine { Margin = new Padding(0, 6, 12, 3) };
            state.Set(Tone.Idle, Glyph.Dash, "Not checked", "");
            layout.Controls.Add(state);
            var check = new Button { Text = "Check now", AutoSize = true, Margin = new Padding(0, 4, 8, 4) };
            check.Click += async (_, _) => await CheckAllUpdates();
            checkButtons.Add(check);
            layout.Controls.Add(check);
            var button = new Button { Text = "Update", AutoSize = true, Enabled = false, Margin = new Padding(0, 4, 0, 4) };
            button.Click += async (_, _) => await update();
            layout.Controls.Add(button);
            return (state, button);
        }
        (launcherUpdate, launcherUpdateButton) = Row("Launcher", InstallLauncherUpdate);
        launcherUpdateButton!.Text = "Install and restart";
        if (profile.Control?.Group != null) {
            (serverUpdate, serverUpdateButton) = Row("Server", ServerDeploy);
            serverUpdateButton!.Text = "Save, update and restart";
        } else if (profile.Control != null) (serverUpdate, serverUpdateButton) = Row("Server", () => HostAction("update", "Update"));
        if (profile.Bot != null) (botUpdate, botUpdateButton) = Row("Civilizationbot", UpdateBot);
        var note = new Label {
            AutoSize = true, Margin = new Padding(0, 14, 0, 0),
            Text = (profile.Control?.Group != null
                       ? "Checking only fetches; nothing changes until you press a button. Save, update and restart builds the update beside the " +
                         "running worlds, then hands each running region you tick over to it: its players see a frozen world while it saves and the new build loads, then reconnect within seconds. A region that will not save or load keeps running on its old build. "
                       : "Checking only fetches; nothing changes until you press Update. The server must be stopped before it updates. ") +
                   "Updating the bot stops it, pulls main and starts it again."
        };
        layout.Controls.Add(note);
        layout.SetColumnSpan(note, 4);
        page.Controls.Add(layout);
        page.Enter += async (_, _) => { if (DateTime.UtcNow - lastUpdateCheckUtc > TimeSpan.FromMinutes(1)) await CheckAllUpdates(); };
        updateTimer = new System.Windows.Forms.Timer { Interval = (int)UpdateCheckEvery.TotalMilliseconds, Enabled = true };
        updateTimer.Tick += async (_, _) => await CheckAllUpdates();
        return page;
    }

    private async Task CheckAllUpdates() {
        if (checkingUpdates || host == null) return;
        checkingUpdates = true;
        foreach (var button in checkButtons) button.Enabled = false;
        try {
            lastUpdateCheckUtc = DateTime.UtcNow;
            await Task.WhenAll(CheckServerUpdate(), CheckBotUpdate(), CheckLauncherUpdate());
        } finally {
            checkingUpdates = false;
            foreach (var button in checkButtons) button.Enabled = true;
        }
    }

    private async Task CheckServerUpdate() {
        if (host?.Control is not { } control || serverUpdate == null) return;
        if (control.Group != null && groupScriptRunning) return; // a deploy is running; its row says so
        serverUpdate.Set(Tone.Idle, Glyph.Arc, "Checking", "");
        // A group answers for every region, so a region behind the mainland counts too.
        var answer = "";
        serverCheck = await Check("server", () => {
            var result = LocalHosting.RunCaptured(control.Group != null
                ? LocalHosting.GroupStep(control, "check-update") : LocalHosting.ControlStep(control, "check-update"));
            answer = result.Output;
            return result;
        });
        // The Host tab's board shows the same answer per region.
        if (control.Group != null && serverCheck.Ok) regionsBehind = HostBoard.RegionsBehind(answer);
        ShowBoard();
        if (control.Group != null && groupScriptRunning) return; // a deploy started meanwhile; its row says so
        ShowCheck(serverCheck, serverUpdate, serverUpdateButton, control.Group != null);
    }

    private Task ServerDeploy() => ChooseAndDeploy("Save, update and restart");

    // The launcher itself: installed version against the stable channel (the same manifest the startup check reads).
    private async Task CheckLauncherUpdate() {
        if (launcherUpdate == null) return;
        launcherUpdate.Set(Tone.Idle, Glyph.Arc, "Checking", "");
        var installed = version.ToString(3);
        try {
            var manifest = Channel.Read(await transport.Text(Updater.LauncherChannelUrl));
            manifest.Validate(true);
            var latest = Version.Parse(manifest.Version);
            launcherLatest = latest > version ? latest.ToString(3) : null;
            if (launcherLatest != null)
                launcherUpdate.Set(Tone.Busy, Glyph.Down, "Update available", $"Installed {installed}; latest {launcherLatest}. Checked {DateTime.Now:t}.");
            else
                launcherUpdate.Set(Tone.Good, Glyph.Check, "Up to date", $"Installed {installed}; latest published {latest.ToString(3)}. Checked {DateTime.Now:t}.");
        } catch (Exception e) when (e is HttpRequestException or IOException or InvalidDataException or OperationCanceledException or TimeoutException or JsonException or FormatException or ArgumentException) {
            launcherLatest = null;
            launcherUpdate.Set(Tone.Bad, Glyph.Alert, "Check failed", $"Installed {installed}. {Updater.DescribeFailure(e)}");
        }
        if (launcherUpdateButton != null) launcherUpdateButton.Enabled = launcherLatest != null;
        CountUpdates();
    }

    private async Task InstallLauncherUpdate() {
        if (launcherLatest == null) return;
        if (MessageBox.Show(this, $"Download launcher {launcherLatest}, verify it and restart the launcher on it? The game servers keep running; " +
                "a Civilizationbot this launcher started is stopped as it closes, so start it again afterwards.", "Civ13 Launcher",
                MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
        if (launcherUpdateButton != null) launcherUpdateButton.Enabled = false;
        launcherUpdate?.Set(Tone.Busy, Glyph.Arc, "Installing", $"Downloading and verifying launcher {launcherLatest}...");
        try {
            var owner = Updater.Lock(root);
            if (await Program.CheckLauncherUpdate(transport, version, root)) {
                // The update helper waits for this process to exit; never block it with a dialog.
                SetStatus("Launcher update downloaded. Restarting...");
                owner.Dispose();
                Close();
                return;
            }
            owner.Dispose();
            launcherUpdate?.Set(Tone.Bad, Glyph.Alert, "Not installed", "The update was not installed; the launcher log says why.");
        } catch (IOException e) {
            launcherUpdate?.Set(Tone.Bad, Glyph.Alert, "Not installed", e.Message);
        }
        if (launcherUpdateButton != null) launcherUpdateButton.Enabled = launcherLatest != null;
    }

    private void CountUpdates() {
        var count = (serverCheck?.HasUpdate == true ? 1 : 0) + (botCheck?.HasUpdate == true ? 1 : 0) + (launcherLatest != null ? 1 : 0);
        if (updatesPage != null) updatesPage.Text = count == 0 ? "Updates" : $"Updates ({count})";
    }

    private void ShowServerUpdateBusy() {
        serverUpdate?.Set(Tone.Busy, Glyph.Arc, "Updating", "Building, then saving, updating and restarting; follow it on the Host server tab.");
        if (serverUpdateButton != null) serverUpdateButton.Enabled = false;
    }

    private void SelectHostTab() {
        if (hostPage != null) tabs.SelectedTab = hostPage;
    }

    private async Task CheckBotUpdate() {
        if (host?.Bot is not { } bot || botUpdate == null) return;
        botUpdate.Set(Tone.Idle, Glyph.Arc, "Checking", "");
        botCheck = await Check("bot", () => LocalHosting.RunCaptured(LocalBot.Control(bot, "check-update")));
        ShowCheck(botCheck, botUpdate, botUpdateButton);
    }

    private static async Task<UpdateCheck> Check(string component, Func<(int Exit, string Output)> run) {
        try {
            var (exit, output) = await Task.Run(run);
            return UpdateCheck.Parse(component, exit, output);
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            return new UpdateCheck(false, component, "", "", 0, false, null, e.Message);
        }
    }

    private void ShowCheck(UpdateCheck check, StatusLine state, Button? button, bool deploys = false) {
        // A deploy stops the worlds itself, so "stop the server first" is no reason to hold it back.
        var deployable = deploys && check.OnlyNeedsStop;
        // The pill says which of the three it is; the sentence keeps the commits and the reason.
        var text = deployable ? check.Describe(withReason: false) : check.Describe();
        foreach (var lead in new[] { "Update available: ", "Check failed: " })
            if (text.StartsWith(lead) && text.Length > lead.Length) text = char.ToUpperInvariant(text[lead.Length]) + text[(lead.Length + 1)..];
        if (text.StartsWith("Up to date (")) text = "Build " + text["Up to date (".Length..].TrimEnd('.', ')') + ".";
        if (deploys && check.Ok && regionsBehind is { Count: > 0 } regions) {
            string Name(string id) => hostBoard?.Cards.FirstOrDefault(card => card.Id == id)?.Name ?? id;
            var behind = regions.Where(region => region.Value > 0).Select(region => Name(region.Key)).ToList();
            if (behind.Count > 0 && behind.Count < regions.Count) text += " Out of date: " + string.Join(", ", behind) + ".";
        }
        var (tone, glyph, pill) = !check.Ok ? (Tone.Bad, Glyph.Alert, "Check failed")
            : check.HasUpdate ? (Tone.Busy, Glyph.Down, "Update available") : (Tone.Good, Glyph.Check, "Up to date");
        state.Set(tone, glyph, pill, text + $" Checked {DateTime.Now:t}.");
        // can_update already says why not: the server must be stopped first; the bot needs a clean main checkout.
        if (button != null) button.Enabled = !(deploys && groupScriptRunning) && check.HasUpdate && (check.CanUpdate || deployable);
        CountUpdates();
        if (check.HasUpdate) Console.WriteLine($"{(check.Component == "bot" ? "Civilizationbot" : "Server")}: {check.Describe()}");
    }
}
