using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Civilizationbot tab: start, stop, restart and update the configured bot through its control.php,
// and follow its logs. A bot this window starts stops when the window closes; one started some
// other way is left running.
internal sealed partial class LauncherWindow {
    private static readonly TimeSpan BotStopWait = TimeSpan.FromSeconds(90);
    private readonly OwnedBot ownedBot = new();
    private HostBot? botProfile;
    private Label? botState;
    private TextBox? botLog;
    private ComboBox? botLogChoice;
    private Button? botClearStop;
    private readonly List<Button> botButtons = [];
    private readonly List<Button> botForceButtons = [];
    private System.Windows.Forms.Timer? botPoll;
    private BotStatus? botStatus;
    private bool botBusy;
    private bool botWasOwned;
    private bool closingAfterBot;

    private TabPage BuildBotPage(HostBot bot) {
        botProfile = bot;
        var page = new TabPage("Civilizationbot") { Padding = new Padding(10) };
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2 };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        void Row(string name, string value) {
            layout.Controls.Add(new Label { Text = name, AutoSize = true, Font = new Font(Font, FontStyle.Bold), Margin = new Padding(0, 3, 12, 3) });
            layout.Controls.Add(new Label { Text = value, AutoSize = true, Margin = new Padding(0, 3, 0, 3) });
        }
        Row("Bot folder", bot.Root);
        Row("Profile", bot.Profile);
        Row("When the launcher closes", "A bot started here is stopped first; one started outside the launcher keeps running");
        botState = new Label { AutoSize = true, Margin = new Padding(0, 10, 0, 6), Text = "Checking..." };
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0) };
        foreach (var (text, action) in new (string, Func<Task>)[] { ("Start", StartBot), ("Stop", () => StopBot(true)), ("Restart", RestartBot), ("Update", UpdateBot) }) {
            var button = new Button { Text = text, AutoSize = true, Enabled = false, Margin = new Padding(botButtons.Count == 0 ? 0 : 8, 6, 0, 6) };
            button.Click += async (_, _) => await action();
            botButtons.Add(button);
            buttons.Controls.Add(button);
        }
        foreach (var (text, action) in new (string, Func<Task>)[] { ("Force stop", () => ForceStopBot(false)), ("Force restart", () => ForceStopBot(true)) }) {
            var button = new Button { Text = text, AutoSize = true, Enabled = false, Margin = new Padding(8, 6, 0, 6) };
            button.Click += async (_, _) => await action();
            botForceButtons.Add(button);
            buttons.Controls.Add(button);
        }
        botClearStop = new Button { Text = "Clear old stop request", AutoSize = true, Visible = false, Margin = new Padding(8, 6, 0, 6) };
        botClearStop.Click += async (_, _) => await ClearBotStop();
        buttons.Controls.Add(botClearStop);
        var folder = new LinkLabel { Text = "Open log folder", AutoSize = true, Margin = new Padding(12, 11, 0, 6) };
        folder.LinkClicked += (_, _) => {
            if (botStatus?.StdoutLog is { } stdout && Path.GetDirectoryName(stdout) is { } dir)
                Open(new ProcessStartInfo(dir) { UseShellExecute = true }, "the bot's log folder");
        };
        buttons.Controls.Add(folder);
        botLogChoice = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 160, Margin = new Padding(12, 8, 0, 6) };
        botLogChoice.Items.AddRange(["Output log", "Error log"]);
        botLogChoice.SelectedIndex = 0;
        botLogChoice.SelectedIndexChanged += (_, _) => RefreshBotLog(true);
        buttons.Controls.Add(botLogChoice);
        layout.Controls.Add(botState);
        layout.SetColumnSpan(botState, 2);
        layout.Controls.Add(buttons);
        layout.SetColumnSpan(buttons, 2);
        botLog = new TextBox {
            Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Both, WordWrap = false,
            Font = new Font(FontFamily.GenericMonospace, 9f)
        };
        layout.Controls.Add(botLog);
        layout.SetColumnSpan(botLog, 2);
        for (var row = 0; row < 5; row++) layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        page.Controls.Add(layout);
        // Status every few seconds while anything could change: the tab is open, or a bot here is running.
        botPoll = new System.Windows.Forms.Timer { Interval = 3000, Enabled = true };
        botPoll.Tick += async (_, _) => {
            if (tabs.SelectedTab == page || ownedBot.Running || botWasOwned) await RefreshBot();
            if (tabs.SelectedTab == page) RefreshBotLog(false);
        };
        page.Enter += async (_, _) => { await RefreshBot(); RefreshBotLog(true); };
        _ = RefreshBot();
        return page;
    }

    private async Task<(int Exit, string Output)> RunBot(string action) {
        var bot = botProfile ?? throw new InvalidOperationException("No bot configured.");
        return await Task.Run(() => LocalHosting.RunCaptured(LocalBot.Control(bot, action)));
    }

    private async Task RefreshBot() {
        if (botProfile is not { } bot || botState == null) return;
        BotStatus status;
        try {
            var (exit, output) = await RunBot("status");
            status = LocalBot.ParseStatus(exit, output);
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            status = new BotStatus(false, false, false, null, null, e.Message);
        }
        // A bot checkout older than the status command: fall back to its HTTP listener.
        if (!status.Ok) {
            var listening = await Task.Run(() => LocalHosting.Listening(bot.HttpPort));
            status = status with { Running = listening };
        }
        botStatus = status;
        if (botWasOwned && !ownedBot.Running) {
            botWasOwned = false;
            var errors = ownedBot.Errors;
            BotLine($"Civilizationbot stopped (exit {ownedBot.ExitCode?.ToString() ?? "unknown"})." + (errors.Length > 0 ? " " + errors : ""));
        }
        var owned = ownedBot.Running;
        string text;
        if (status.Running) text = owned ? "Running, started by this launcher. It stops when the launcher closes." : "Running, started outside the launcher. It keeps running when the launcher closes.";
        else text = "Not running.";
        if (status.StopPending) text += status.Running ? " Stop requested; waiting for it to exit." : " An old stop request is blocking start.";
        if (!status.Ok) text += $" (Status unavailable: {status.Error}; checked port {bot.HttpPort} instead.)";
        botState.Text = text;
        if (botClearStop != null) botClearStop.Visible = status.StopPending && !status.Running;
        UpdateBotButtons();
    }

    private void UpdateBotButtons() {
        if (botButtons.Count < 4) return;
        var running = botStatus?.Running ?? false;
        var pending = botStatus?.StopPending ?? false;
        botButtons[0].Enabled = !botBusy && !running && !pending;
        botButtons[1].Enabled = !botBusy && running && !pending;
        botButtons[2].Enabled = !botBusy && running && !pending;
        botButtons[3].Enabled = !botBusy && !pending;
        if (botClearStop != null) botClearStop.Enabled = !botBusy;
        foreach (var button in botForceButtons) button.Enabled = !botBusy;
    }

    private void RefreshBotLog(bool force) {
        if (botLog == null || botLogChoice == null || botStatus == null) return;
        var path = botLogChoice.SelectedIndex == 1 ? botStatus.StderrLog : botStatus.StdoutLog;
        string text;
        try { text = path == null ? "Log location unknown until the bot answers its status command (update the bot to get it)." : LocalBot.Tail(path); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { text = "Could not read the log: " + e.Message; }
        if (!force && text == botLog.Text) return;
        var atEnd = force || botLog.SelectionStart >= botLog.TextLength - 1;
        botLog.Text = text;
        if (atEnd) { botLog.SelectionStart = botLog.TextLength; botLog.ScrollToCaret(); }
    }

    private async Task WithBotBusy(Func<Task> work) {
        if (botBusy) return;
        botBusy = true;
        UpdateBotButtons();
        try { await work(); }
        catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) { BotLine("Civilizationbot: " + e.Message); }
        finally {
            botBusy = false;
            await RefreshBot();
            RefreshBotLog(true);
        }
    }

    private Task StartBot() => WithBotBusy(async () => {
        if (botProfile is not { } bot) return;
        if (ownedBot.Running) { BotLine("Civilizationbot is already running from this launcher."); return; }
        ownedBot.Start(LocalBot.Control(bot, "start"));
        botWasOwned = true;
        BotLine("Starting Civilizationbot...");
        // control.php refuses quickly (bad profile, source guard, old stop request); give it a moment to say so.
        if (await ownedBot.WaitForExit(TimeSpan.FromSeconds(3))) {
            botWasOwned = false;
            BotLine("Civilizationbot did not start: " + LocalBot.FailureText(ownedBot.ExitCode ?? -1, ownedBot.Errors));
        }
    });

    private Task StopBot(bool confirm) => WithBotBusy(async () => {
        if (confirm && MessageBox.Show(this, "Stop Civilizationbot? Discord relays and commands pause until it is started again.", "Civ13 Launcher",
                MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
        await StopBotAndWait();
    });

    // Asks control.php to stop, then waits for the bot to exit. True once it has.
    private async Task<bool> StopBotAndWait() {
        BotLine("Stopping Civilizationbot...");
        var (exit, output) = await RunBot("stop");
        if (exit != 0) {
            BotLine("Stop refused: " + LocalBot.FailureText(exit, output));
            return false;
        }
        bool stopped;
        if (ownedBot.Running) stopped = await ownedBot.WaitForExit(BotStopWait);
        else {
            var deadline = DateTime.UtcNow + BotStopWait;
            do {
                await Task.Delay(1000);
                await RefreshBot();
                stopped = botStatus is { Running: false };
            } while (!stopped && DateTime.UtcNow < deadline);
        }
        BotLine(stopped ? "Civilizationbot stopped." : $"Civilizationbot has not exited after {BotStopWait.TotalSeconds:0} seconds.");
        return stopped;
    }

    private Task RestartBot() => WithBotBusy(async () => {
        if (MessageBox.Show(this, "Restart Civilizationbot?", "Civ13 Launcher", MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
        if (!await StopBotAndWait()) return;
        botBusy = false;
        await StartBot();
    });

    // Stops a running bot, fast-forwards its checkout through control.php update, and starts it again.
    private Task UpdateBot() => WithBotBusy(async () => {
        var wasRunning = botStatus?.Running ?? false;
        if (wasRunning && MessageBox.Show(this, "Updating stops Civilizationbot, pulls main, and starts it again. Continue?", "Civ13 Launcher",
                MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
        if (wasRunning && !await StopBotAndWait()) return;
        BotLine("Updating Civilizationbot...");
        var (exit, output) = await RunBot("update");
        if (exit == 0) BotLine("Civilizationbot updated.");
        else BotLine("Update refused: " + LocalBot.FailureText(exit, output));
        if (wasRunning) {
            botBusy = false;
            await StartBot();
        }
        await CheckBotUpdate();
    });

    // Forced stop: ends the bot's supervisor and bot.php process trees at once, whoever started them, and
    // removes a stop request the bot never acted on. With restart, it is then started from this window.
    private Task ForceStopBot(bool restart) => WithBotBusy(async () => {
        if (botProfile is not { } bot) return;
        var question = (restart ? "Force restart" : "Force stop") + " Civilizationbot? It is ended at once without a clean shutdown" +
            (restart ? ", then started again." : ". Discord relays and commands pause until it is started again.");
        if (MessageBox.Show(this, question, "Civ13 Launcher", MessageBoxButtons.OKCancel, MessageBoxIcon.Warning) != DialogResult.OK) return;
        BotLine("Force-stopping Civilizationbot...");
        var (_, listing) = await Task.Run(() => LocalHosting.RunCaptured(LocalBot.ListPhpProcesses()));
        var pids = LocalBot.ParseBotProcesses(bot, listing);
        foreach (var pid in pids) await Task.Run(() => LocalHosting.RunCaptured(LocalBot.KillTree(pid)));
        if (ownedBot.Running) await ownedBot.WaitForExit(TimeSpan.FromSeconds(10));
        await Task.Delay(1000);
        await RefreshBot();
        if (botStatus is { Running: false, StopPending: true, StdoutLog: { } stdout } && Path.GetDirectoryName(stdout) is { } state)
            File.Delete(Path.Combine(state, "stop.request"));
        if (botStatus is { Running: true }) {
            BotLine("Civilizationbot is still running after the forced stop; end php.exe in Task Manager.");
            return;
        }
        BotLine(pids.Count == 0 ? "No Civilizationbot process was running." : $"Civilizationbot force-stopped ({pids.Count} process{(pids.Count == 1 ? "" : "es")}).");
        if (restart) {
            botBusy = false;
            await StartBot();
        }
    });

    // A stop marker left by a bot that is no longer running blocks every start until someone removes it.
    private Task ClearBotStop() => WithBotBusy(async () => {
        await RefreshBot();
        if (botStatus is not { Ok: true, Running: false, StopPending: true, StdoutLog: { } stdout } || Path.GetDirectoryName(stdout) is not { } state) return;
        if (MessageBox.Show(this, "The bot is not running but an old stop request is still there, which blocks starting it. Check the error log if the last stop looked wrong. Remove the stop request?",
                "Civ13 Launcher", MessageBoxButtons.OKCancel, MessageBoxIcon.Warning) != DialogResult.OK) return;
        File.Delete(Path.Combine(state, "stop.request"));
        BotLine("Removed the old stop request.");
    });

    // Closing waits for a bot this launcher started to stop cleanly. If it does not, the job object ends it.
    private async Task StopBotBeforeClosing(FormClosingEventArgs e) {
        if (closingAfterBot || !ownedBot.Running) return;
        e.Cancel = true;
        closingAfterBot = true;
        Enabled = false;
        SetStatus("Stopping Civilizationbot before closing...");
        try { await StopBotAndWait(); }
        catch (Exception error) when (error is Win32Exception or IOException or InvalidOperationException) { BotLine("Civilizationbot: " + error.Message); }
        Close();
    }

    private void BotLine(string line) {
        Console.WriteLine(line);
        if (botState != null) botState.Text = line;
    }
}
