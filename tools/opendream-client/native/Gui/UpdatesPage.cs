using System.ComponentModel;
using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Updates tab: one row per hosted component (the server through gaia_host.py, the bot through
// control.php). Each check-update only fetches; Update uses the component's own update path.
// Checks run at startup, when the tab opens, and every 30 minutes while the launcher is open.
internal sealed partial class LauncherWindow {
    private static readonly TimeSpan UpdateCheckEvery = TimeSpan.FromMinutes(30);
    private TabPage? updatesPage;
    private Label? serverUpdate, botUpdate;
    private Button? serverUpdateButton, botUpdateButton;
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
        (Label, Button) Row(string name, Func<Task> update) {
            layout.Controls.Add(new Label { Text = name, AutoSize = true, Font = new Font(Font, FontStyle.Bold), Margin = new Padding(0, 9, 12, 3) });
            var state = new Label { Text = "Not checked yet.", AutoSize = true, Margin = new Padding(0, 9, 12, 3) };
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
        if (profile.Control != null) (serverUpdate, serverUpdateButton) = Row("Server", () => HostAction("update", "Update"));
        if (profile.Bot != null) (botUpdate, botUpdateButton) = Row("Civilizationbot", UpdateBot);
        var note = new Label {
            AutoSize = true, Margin = new Padding(0, 14, 0, 0),
            Text = "Checking only fetches; nothing changes until you press Update. The server must be stopped before it updates. " +
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
            await Task.WhenAll(CheckServerUpdate(), CheckBotUpdate());
        } finally {
            checkingUpdates = false;
            foreach (var button in checkButtons) button.Enabled = true;
        }
    }

    private async Task CheckServerUpdate() {
        if (host?.Control is not { } control || serverUpdate == null) return;
        serverUpdate.Text = "Checking...";
        serverCheck = await Check("server", () => LocalHosting.RunCaptured(LocalHosting.ControlStep(control, "check-update")));
        ShowCheck(serverCheck, serverUpdate, serverUpdateButton);
    }

    private async Task CheckBotUpdate() {
        if (host?.Bot is not { } bot || botUpdate == null) return;
        botUpdate.Text = "Checking...";
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

    private void ShowCheck(UpdateCheck check, Label state, Button? button) {
        state.Text = check.Describe() + $" Checked {DateTime.Now:t}.";
        // can_update already says why not: the server must be stopped first; the bot needs a clean main checkout.
        if (button != null) button.Enabled = check.HasUpdate && check.CanUpdate;
        var count = (serverCheck?.HasUpdate == true ? 1 : 0) + (botCheck?.HasUpdate == true ? 1 : 0);
        if (updatesPage != null) updatesPage.Text = count == 0 ? "Updates" : $"Updates ({count})";
        if (check.HasUpdate) Console.WriteLine($"{(check.Component == "bot" ? "Civilizationbot" : "Server")}: {check.Describe()}");
    }
}
