using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Text.Json;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Window front-end for the same launcher steps as the text menu (--console):
// launcher update check, BYOND setup, public server status and joining, BYOND sign in,
// community links, optional local hosting and read-only server management.
internal sealed class LauncherWindow : Form {
    private static readonly Color HeaderBack = Color.FromArgb(32, 38, 46);
    private static readonly Color HeaderText = Color.FromArgb(236, 239, 243);
    private static readonly Color HeaderMuted = Color.FromArgb(160, 170, 184);

    private readonly string root;
    private readonly Version version;
    private readonly ReleaseTransport transport;
    private readonly WindowsByondDesktop desktop = new();
    private readonly ServerDiscovery discovery = new();
    private string? byond;
    private HostProfile? host;
    // Servers found this session, per provider. Refresh updates their status but never removes
    // them; a server that stops answering stays listed with when it was last seen.
    private readonly Dictionary<string, Dictionary<GameTarget, KnownServer>> known = new();
    private sealed class KnownServer(GameServer server, string status) {
        public GameServer Server { get; set; } = server;
        public string Status { get; set; } = status;
    }
    private GameServer? pending;
    private DateTime pendingReadyUtc;
    private bool startupDone;
    private bool busy;

    private readonly Label statusLabel = new() { AutoSize = true, ForeColor = HeaderMuted, Text = "Starting..." };
    private readonly Button signInButton = new() { Text = "BYOND sign in", AutoSize = true, Enabled = false, FlatStyle = FlatStyle.System };
    private readonly Button setupButton = new() { Text = "Set up BYOND", AutoSize = true, Visible = false, FlatStyle = FlatStyle.System };
    private readonly TabControl tabs = new() { Dock = DockStyle.Fill };
    private readonly RadioButton officialRadio = new() { Text = "Civ13.com", AutoSize = true, Enabled = false };
    private readonly RadioButton valRadio = new() { Text = "ValZarGaming.com", AutoSize = true, Enabled = false };
    private readonly Button refreshButton = new() { Text = "Refresh", AutoSize = true, Enabled = false };
    private readonly ListView serverList = new() {
        Dock = DockStyle.Fill, View = View.Details, FullRowSelect = true, MultiSelect = false, HideSelection = false
    };
    private readonly Label notesLabel = new() { AutoSize = true, Dock = DockStyle.Fill, Padding = new Padding(0, 6, 0, 0) };
    private readonly Label joinStatus = new() { AutoSize = true, Anchor = AnchorStyles.Left };
    private readonly Button joinButton = new() { Text = "Join", AutoSize = true, Enabled = false, MinimumSize = new Size(110, 0) };
    private readonly Button cancelButton = new() { Text = "Cancel", AutoSize = true, Visible = false };
    private readonly System.Windows.Forms.Timer waitTimer = new() { Interval = 1000 };
    private readonly TextBox log = new() {
        Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical,
        Font = new Font(FontFamily.GenericMonospace, 9f), BorderStyle = BorderStyle.None
    };
    private readonly LinkLabel manageLink = new() { Text = "Server management (read-only)", AutoSize = true, Enabled = false };
    private TabPage? hostPage;
    private Label? hostState;
    private Button? hostStart;
    private TextBox? hostOutput;
    private DiscordPresence? presence;
    private PresenceSettings presenceSettings = new(false, null);
    private readonly CheckBox discordBox = new() { Text = "Show on Discord", AutoSize = true, Visible = false, Margin = new Padding(0, 1, 14, 0) };
    private readonly List<Button> hostActions = [];
    private System.Windows.Forms.Timer? hostPoll;
    private bool hostControlBusy;

    public static int Run(string root, Version version) {
        var thread = new Thread(() => {
            ConsoleWindow.ReleaseIfOwned();
            Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
            using var window = new LauncherWindow(root, version);
            Application.ThreadException += (_, e) => window.ReportError("Unexpected error", e.Exception);
            Application.Run(window);
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join();
        return 0;
    }

    private LauncherWindow(string root, Version version) {
        this.root = root;
        this.version = version;
        transport = new ReleaseTransport(new HttpClientHandler { AllowAutoRedirect = false }, Console.WriteLine);
        Text = "Civ13 Launcher " + version.ToString(3);
        AutoScaleMode = AutoScaleMode.Dpi;
        Font = new Font("Segoe UI", 9.75f);
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(720, 520);
        Size = new Size(940, 640);
        try { Icon = Icon.ExtractAssociatedIcon(Environment.ProcessPath ?? ""); } catch (Exception e) when (e is ArgumentException or IOException) { }

        var body = new SplitContainer {
            Dock = DockStyle.Fill, Orientation = Orientation.Horizontal, FixedPanel = FixedPanel.Panel2, Padding = new Padding(10, 8, 10, 0)
        };
        body.Panel1.Controls.Add(tabs);
        var logGroup = new GroupBox { Text = "Launcher log", Dock = DockStyle.Fill, Padding = new Padding(8, 4, 8, 8) };
        logGroup.Controls.Add(log);
        body.Panel2.Controls.Add(logGroup);
        tabs.TabPages.Add(BuildPlayPage());

        Controls.Add(body);
        Controls.Add(BuildFooter());
        Controls.Add(BuildHeader());
        Load += (_, _) => {
            body.SplitterDistance = Math.Max(body.Panel1MinSize, body.Height - LogicalToDeviceUnits(150));
        };
        Shown += async (_, _) => await Startup();
        FormClosed += (_, _) => { waitTimer.Dispose(); transport.Dispose(); presence?.Clear(); presence?.Dispose(); };
        waitTimer.Tick += (_, _) => UpdatePendingWait();
    }

    private Control BuildHeader() {
        var header = new TableLayoutPanel {
            Dock = DockStyle.Top, AutoSize = true, BackColor = HeaderBack, ColumnCount = 2, RowCount = 2, Padding = new Padding(14, 10, 14, 10)
        };
        header.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        header.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        var title = new Label {
            Text = "Civ13", AutoSize = true, ForeColor = HeaderText, Font = new Font("Segoe UI Semibold", 18f), Margin = new Padding(0)
        };
        var buttons = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Anchor = AnchorStyles.Right, Margin = new Padding(0) };
        signInButton.Click += (_, _) => { if (byond != null) Open(() => Program.StartByondPager(byond), "the BYOND Pager"); };
        setupButton.Click += async (_, _) => await SetUpByond();
        buttons.Controls.Add(setupButton);
        buttons.Controls.Add(signInButton);
        header.Controls.Add(title, 0, 0);
        header.Controls.Add(buttons, 1, 0);
        header.SetRowSpan(buttons, 2);
        header.Controls.Add(statusLabel, 0, 1);
        return header;
    }

    private TabPage BuildPlayPage() {
        var page = new TabPage("Play") { Padding = new Padding(10) };
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1, RowCount = 4 };
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        var providers = new FlowLayoutPanel { AutoSize = true, Dock = DockStyle.Fill, WrapContents = false, Margin = new Padding(0, 0, 0, 6) };
        providers.Controls.Add(new Label { Text = "Servers:", AutoSize = true, Margin = new Padding(0, 6, 8, 0) });
        providers.Controls.Add(officialRadio);
        providers.Controls.Add(valRadio);
        providers.Controls.Add(refreshButton);
        officialRadio.Margin = valRadio.Margin = new Padding(0, 4, 12, 0);
        officialRadio.CheckedChanged += async (_, _) => { if (officialRadio.Checked) await Fetch(); };
        valRadio.CheckedChanged += async (_, _) => { if (valRadio.Checked) await Fetch(); };
        refreshButton.Click += async (_, _) => await Fetch();

        foreach (var (name, width) in new[] { ("Server", 170), ("Players", 64), ("Map", 130), ("Mode", 110), ("Epoch", 90),
            ("Round", 80), ("Elapsed", 72), ("Status", 160) })
            serverList.Columns.Add(name, LogicalToDeviceUnits(width));
        serverList.SelectedIndexChanged += (_, _) => {
            if (pending != null && Selected() is { } chosen && chosen != pending) CancelPending();
            UpdateJoinButton();
        };
        serverList.ItemActivate += async (_, _) => await Join();
        // Let the last column take the remaining width so the list never scrolls sideways.
        serverList.ClientSizeChanged += (_, _) => FillLastColumn();

        var actions = new TableLayoutPanel { Dock = DockStyle.Fill, AutoSize = true, ColumnCount = 3, Margin = new Padding(0, 6, 0, 0) };
        actions.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        actions.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        actions.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        actions.Controls.Add(joinStatus, 0, 0);
        actions.Controls.Add(cancelButton, 1, 0);
        actions.Controls.Add(joinButton, 2, 0);
        joinButton.Click += async (_, _) => await Join();
        cancelButton.Click += (_, _) => CancelPending();

        notesLabel.Text = "Choose a server list. The game address is verified again before joining.";
        layout.Controls.Add(providers, 0, 0);
        layout.Controls.Add(serverList, 0, 1);
        layout.Controls.Add(notesLabel, 0, 2);
        layout.Controls.Add(actions, 0, 3);
        page.Controls.Add(layout);
        notesLabel.SizeChanged += (_, _) => notesLabel.MaximumSize = new Size(layout.ClientSize.Width, 0);
        return page;
    }

    private Control BuildFooter() {
        var footer = new TableLayoutPanel { Dock = DockStyle.Bottom, AutoSize = true, ColumnCount = 2, Padding = new Padding(10, 6, 10, 8) };
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        footer.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        var community = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0) };
        community.Controls.Add(new Label { Text = "Community:", AutoSize = true, Margin = new Padding(0, 3, 6, 0) });
        foreach (var (key, link) in CommunityLinks.Items) {
            var label = new LinkLabel { Text = link.Label, AutoSize = true, Margin = new Padding(0, 3, 14, 0) };
            label.LinkClicked += (_, _) => CommunityLinks.TryOpen(key, start => { using var browser = Process.Start(start); }, Console.Out);
            community.Controls.Add(label);
        }
        // Operator tools stay out of the main view.
        var tools = new FlowLayoutPanel { AutoSize = true, WrapContents = false, Margin = new Padding(0), Anchor = AnchorStyles.Right };
        discordBox.CheckedChanged += (_, _) => SetDiscordPresence(discordBox.Checked, true);
        tools.Controls.Add(discordBox);
        var dataFolder = new LinkLabel { Text = "Launcher data folder", AutoSize = true, Margin = new Padding(0, 3, 14, 0) };
        dataFolder.LinkClicked += (_, _) => Open(new ProcessStartInfo(root) { UseShellExecute = true }, "the launcher data folder");
        manageLink.Margin = new Padding(0, 3, 0, 0);
        manageLink.LinkClicked += (_, _) => { using var dialog = new ManagementDialog(); dialog.ShowDialog(this); };
        tools.Controls.Add(dataFolder);
        tools.Controls.Add(manageLink);
        footer.Controls.Add(community, 0, 0);
        footer.Controls.Add(tools, 1, 0);
        return footer;
    }

    private TabPage BuildHostPage(HostProfile profile) {
        var page = new TabPage("Host server") { Padding = new Padding(10) };
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2 };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.AutoSize));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        void Row(string name, string value) {
            layout.Controls.Add(new Label { Text = name, AutoSize = true, Font = new Font(Font, FontStyle.Bold), Margin = new Padding(0, 3, 12, 3) });
            layout.Controls.Add(new Label { Text = value, AutoSize = true, Margin = new Padding(0, 3, 0, 3) });
        }
        Row("Game folder", profile.GameDirectory);
        Row("World", profile.World + " on port " + profile.Port + " (listed publicly on the BYOND hub)");
        if (profile.Control is { } control) Row("Control", "Save-safe start, stop, restart and update through " + Path.GetFileName(control.Script));
        else Row("Update before start", profile.Update is { } update ? $"Fast-forward to origin/{update.Branch} and rebuild" : "Off");
        Row("Civilizationbot", profile.Bot is { } bot ? $"Start the supervisor if port {bot.HttpPort} is not listening" : "Not configured");
        hostState = new Label { AutoSize = true, Margin = new Padding(0, 10, 0, 6) };
        hostStart = new Button { Text = "Start server", AutoSize = true, Enabled = false, Margin = new Padding(0, 6, 0, 6) };
        hostStart.Click += async (_, _) => await StartHosting();
        var refresh = new Button { Text = "Check status", AutoSize = true, Margin = new Padding(8, 6, 0, 6) };
        refresh.Click += async (_, _) => await RefreshHostState();
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0) };
        buttons.Controls.Add(hostStart);
        if (profile.Control != null) {
            foreach (var (text, action) in new[] { ("Save and stop", "stop"), ("Restart", "restart"), ("Update", "update") }) {
                var button = new Button { Text = text, AutoSize = true, Margin = new Padding(8, 6, 0, 6) };
                button.Click += async (_, _) => await HostAction(action, text);
                hostActions.Add(button);
                buttons.Controls.Add(button);
            }
            var worldLog = new LinkLabel { Text = "Open world log", AutoSize = true, Margin = new Padding(12, 11, 0, 6) };
            worldLog.LinkClicked += (_, _) => Open(new ProcessStartInfo(Path.Combine(profile.GameDirectory, "logs", "world.log")) { UseShellExecute = true }, "the world log");
            buttons.Controls.Add(worldLog);
            hostPoll = new System.Windows.Forms.Timer { Interval = 5000 };
            hostPoll.Tick += async (_, _) => await RefreshHostState();
        }
        buttons.Controls.Add(refresh);
        layout.Controls.Add(hostState);
        layout.SetColumnSpan(hostState, 2);
        layout.Controls.Add(buttons);
        layout.SetColumnSpan(buttons, 2);
        hostOutput = new TextBox { Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical };
        layout.Controls.Add(hostOutput);
        layout.SetColumnSpan(hostOutput, 2);
        for (var row = 0; row < 6; row++) layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        page.Controls.Add(layout);
        page.Enter += async (_, _) => await RefreshHostState();
        return page;
    }

    private async Task Startup() {
        Console.SetOut(new LogWriter(log));
        Console.SetError(Console.Out);
        FileStream? owner = null;
        try {
            owner = Updater.Lock(root);
            Console.WriteLine("Civ13 Launcher " + version.ToString(3));
            SetStatus("Checking for launcher updates...");
            if (await Program.CheckLauncherUpdate(transport, version, root)) {
                // The update helper waits for this process to exit; never block it with a dialog.
                SetStatus("Launcher update downloaded. Restarting...");
                owner.Dispose();
                owner = null;
                Close();
                return;
            }
            await EnsureByond();
        } catch (IOException e) {
            Console.WriteLine(e.Message);
            SetStatus(e.Message);
            MessageBox.Show(this, e.Message, "Civ13 Launcher", MessageBoxButtons.OK, MessageBoxIcon.Warning);
        } finally { owner?.Dispose(); }
        try { host = LocalHosting.Load(root); }
        catch (Exception e) when (e is InvalidDataException or JsonException or IOException) { Console.WriteLine("Local hosting disabled: " + e.Message); }
        if (host != null) tabs.TabPages.Add(hostPage = BuildHostPage(host));
        presenceSettings = PresenceSettings.Load(root);
        if (presenceSettings.ApplicationId != null) {
            discordBox.Checked = presenceSettings.ShowActivity;
            discordBox.Visible = true;
            SetDiscordPresence(presenceSettings.ShowActivity, false);
        }
        startupDone = true;
        manageLink.Enabled = true;
        UpdateReadiness();
    }

    private async Task EnsureByond() {
        var requirement = Program.RequiredByond();
        SetStatus($"Checking for BYOND {requirement.Version}...");
        using var byondTransport = new ByondTransport();
        try {
            byond = await Byond.Ensure(requirement, root, byondTransport, new GuiByondDesktop(this, desktop, requirement));
            Console.WriteLine("BYOND " + requirement.Version + " available at " + byond);
            Console.WriteLine("Sign in to your BYOND account in the BYOND Pager before joining.");
        } catch (Exception e) when (e is IOException or HttpRequestException or InvalidDataException or OperationCanceledException or Win32Exception or UnauthorizedAccessException) {
            byond = null;
            Console.WriteLine("BYOND setup unavailable: " + e.Message);
        }
    }

    private async Task SetUpByond() {
        setupButton.Enabled = false;
        try {
            using var owner = Updater.Lock(root);
            await EnsureByond();
        } catch (IOException e) {
            Console.WriteLine(e.Message);
        } finally {
            setupButton.Enabled = true;
            UpdateReadiness();
        }
    }

    private void UpdateReadiness() {
        var requirement = Program.RequiredByond();
        var ready = byond != null;
        if (ready) SetStatus($"Launcher {version.ToString(3)}  |  BYOND {requirement.Version} ready. Sign in to your BYOND account before joining.");
        else SetStatus($"Launcher {version.ToString(3)}  |  BYOND {requirement.Version} is required to join. Use Set up BYOND to retry.");
        signInButton.Enabled = ready;
        setupButton.Visible = startupDone && !ready;
        officialRadio.Enabled = valRadio.Enabled = startupDone && !busy;
        refreshButton.Enabled = startupDone && !busy && Provider != null;
        if (hostStart != null) hostStart.Enabled = ready;
        UpdateJoinButton();
    }

    private string? Provider => officialRadio.Checked ? "Civ13.com" : valRadio.Checked ? "ValZarGaming" : null;

    private async Task Fetch() {
        if (Provider is not { } provider) return;
        CancelPending();
        SetBusy(true);
        notesLabel.Text = $"Checking {provider} servers...";
        var servers = KnownFor(provider);
        Populate();
        try {
            var snapshot = await discovery.Fetch(provider);
            var answered = new HashSet<GameTarget>();
            foreach (var server in snapshot.Servers) {
                var cached = ServerBrowser.CachedFor(snapshot, server);
                var status = cached == null ? $"Checked {server.CheckedAt:HH:mm:ss} UTC"
                    : $"Cached, {cached.AgeSeconds}s old" + (cached.Recent != null ? "" : "; recheck needed");
                servers[server.Target] = new KnownServer(server, status);
                answered.Add(server.Target);
            }
            foreach (var (target, entry) in servers) {
                if (answered.Contains(target)) continue;
                var deferred = snapshot.Deferred?.FirstOrDefault(item => item.Target == target);
                entry.Status = deferred != null ? $"Next check in {deferred.Seconds}s; {LastSeen(entry)}"
                    : snapshot.PacingPaused ? "Checks paused; " + LastSeen(entry)
                    : "Not responding; " + LastSeen(entry);
            }
            using var notes = new StringWriter();
            notes.WriteLine($"{provider} - recent BYOND status. The game address is verified again before joining.");
            ServerBrowser.WriteNotes(notes, snapshot);
            notesLabel.Text = notes.ToString().TrimEnd();
        } catch (IOException) {
            foreach (var entry in servers.Values) entry.Status = "Check failed; " + LastSeen(entry);
            notesLabel.Text = $"{provider} status checks failed. No servers can be verified. Try Refresh shortly.";
        } finally {
            Populate();
            SetBusy(false);
        }
    }

    private Dictionary<GameTarget, KnownServer> KnownFor(string provider) {
        if (!known.TryGetValue(provider, out var servers)) known[provider] = servers = new();
        return servers;
    }

    private static string LastSeen(KnownServer entry) => $"last seen {entry.Server.CheckedAt:HH:mm} UTC";

    private void Populate() {
        var keep = Selected()?.Target;
        serverList.BeginUpdate();
        serverList.Items.Clear();
        if (Provider is { } provider)
            foreach (var entry in KnownFor(provider).Values.OrderBy(entry => entry.Server.Port)) {
                var server = entry.Server;
                var item = new ListViewItem([server.Name, server.Players.ToString(), ServerBrowser.Display(server.Map),
                    ServerBrowser.Display(server.Mode), server.Epoch.Length == 0 ? "-" : server.Epoch, ServerBrowser.Display(server.RoundId),
                    ServerBrowser.Elapsed(server), entry.Status]) { Tag = server };
                serverList.Items.Add(item);
                if (server.Target == keep) item.Selected = true;
            }
        if (serverList.SelectedItems.Count == 0 && serverList.Items.Count == 1) serverList.Items[0].Selected = true;
        serverList.EndUpdate();
        UpdateJoinButton();
    }

    private void MarkUnverified(GameServer server, string status) {
        if (KnownFor(server.Provider).TryGetValue(server.Target, out var entry)) entry.Status = status + "; " + LastSeen(entry);
        Populate();
    }

    private void FillLastColumn() {
        if (serverList.Columns.Count == 0) return;
        var used = 0;
        for (var index = 0; index < serverList.Columns.Count - 1; index++) used += serverList.Columns[index].Width;
        serverList.Columns[^1].Width = Math.Max(LogicalToDeviceUnits(120), serverList.ClientSize.Width - used - 1);
    }

    private GameServer? Selected() => serverList.SelectedItems.Count == 1 ? serverList.SelectedItems[0].Tag as GameServer : null;

    private async Task Join() {
        var selected = pending ?? Selected();
        if (selected == null || byond == null || !joinButton.Enabled) return;
        SetBusy(true);
        joinStatus.Text = $"Verifying {selected.Name}...";
        try {
            var verified = await discovery.Recheck(selected);
            var game = Program.StartNativeGame(verified, byond, desktop, Console.Out);
            WatchGame(game, DiscordPresence.ServerLine(verified.Status));
            pending = null;
            if (KnownFor(selected.Provider).TryGetValue(selected.Target, out var entry)) {
                entry.Server = verified.Status;
                entry.Status = $"Checked {verified.Status.CheckedAt:HH:mm:ss} UTC";
                Populate();
            }
            joinStatus.Text = $"Started BYOND for {selected.Name}.";
        } catch (TopicWaitException wait) {
            pending = selected;
            pendingReadyUtc = DateTime.UtcNow.AddSeconds(wait.Seconds);
            Console.WriteLine($"Wait {wait.Seconds} seconds before rechecking {selected.Name}.");
            Console.WriteLine("No automatic check will run. Wall-clock spacing cannot prove server game time advanced or clear a ban.");
            waitTimer.Start();
        } catch (TopicPacingException) {
            pending = null;
            joinStatus.Text = "";
            MarkUnverified(selected, "Checks paused");
            notesLabel.Text = "Public checks paused: shared request timing could not be verified. Local timing state needs review.";
        } catch (IOException) {
            // Do not turn a failed recheck into another immediate status sweep; only Refresh probes again.
            pending = null;
            joinStatus.Text = "";
            MarkUnverified(selected, "Could not verify");
            notesLabel.Text = "The selected server could not be verified or started. Refresh and choose again. No automatic retry.";
        } finally {
            SetBusy(false);
            UpdatePendingWait();
        }
    }

    private void UpdatePendingWait() {
        if (pending == null) {
            waitTimer.Stop();
            cancelButton.Visible = false;
            joinButton.Text = "Join";
            UpdateJoinButton();
            return;
        }
        var remaining = (int)Math.Ceiling((pendingReadyUtc - DateTime.UtcNow).TotalSeconds);
        cancelButton.Visible = true;
        joinButton.Text = "Recheck and join";
        if (remaining > 0) joinStatus.Text = $"Wait {remaining} seconds before rechecking {pending.Name}. No automatic check will run.";
        else {
            waitTimer.Stop();
            joinStatus.Text = $"Ready to recheck {pending.Name}. Press Recheck and join, or Cancel.";
        }
        UpdateJoinButton();
    }

    private void CancelPending() {
        if (pending == null) return;
        pending = null;
        joinStatus.Text = "";
        UpdatePendingWait();
    }

    private void UpdateJoinButton() {
        var waiting = pending != null && DateTime.UtcNow < pendingReadyUtc;
        joinButton.Enabled = byond != null && !busy && !waiting && (pending != null || Selected() != null);
    }

    private void SetBusy(bool value) {
        // No second status request starts until the in-flight one finishes.
        busy = value;
        officialRadio.Enabled = valRadio.Enabled = !busy && startupDone;
        refreshButton.Enabled = !busy && startupDone && Provider != null;
        UseWaitCursor = busy;
        UpdateJoinButton();
    }

    private async Task RefreshHostState() {
        if (host == null || hostState == null) return;
        if (host.Control is { } control) {
            ControlAnswer answer;
            try { answer = await Task.Run(() => LocalHosting.RunControl(control, "status")); }
            catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) { answer = new ControlAnswer(false, "Status unavailable: " + e.Message, false); }
            hostState.Text = answer.Message;
            SetHostBusy(answer.Busy);
            return;
        }
        var port = host.Port;
        var running = await Task.Run(() => LocalHosting.Listening(port));
        hostState.Text = running ? $"DreamDaemon is running on port {port}." : $"DreamDaemon is not running on port {port}.";
    }

    private async Task StartHosting() {
        if (host == null || byond == null || hostStart == null || hostOutput == null) return;
        var profile = host;
        var bin = byond;
        hostStart.Enabled = false;
        try {
            if (profile.Update != null && !await Task.Run(() => LocalHosting.Listening(profile.Port)))
                HostLine($"Updating to origin/{profile.Update.Branch} and rebuilding {profile.World}; this can take a few minutes...");
            var lines = await Task.Run(() => LocalHosting.Run(profile, bin, LocalHosting.Listening, start => { using var process = Process.Start(start); }));
            foreach (var line in lines) HostLine(line);
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            HostLine("Local hosting failed: " + e.Message);
        } finally {
            hostStart.Enabled = byond != null;
            await RefreshHostState();
        }
    }

    // Accepted actions finish in the script's worker; the timer follows them until they settle.
    private async Task HostAction(string action, string label) {
        if (host?.Control is not { } control) return;
        if (action != "update" && MessageBox.Show(this, label + " the server? Players are saved and can rejoin when it is back.", "Civ13 Launcher",
                MessageBoxButtons.OKCancel, MessageBoxIcon.Question) != DialogResult.OK) return;
        SetHostBusy(true);
        try {
            var answer = await Task.Run(() => LocalHosting.RunControl(control, action));
            HostLine(answer.Message);
            if (!answer.Ok) SetHostBusy(false);
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            HostLine(label + " failed: " + e.Message);
            SetHostBusy(false);
        }
    }

    private void SetHostBusy(bool value) {
        if (hostControlBusy && !value && hostState != null) HostLine(hostState.Text);
        hostControlBusy = value;
        foreach (var button in hostActions) button.Enabled = !value;
        if (hostStart != null) hostStart.Enabled = !value && byond != null;
        if (hostPoll != null) hostPoll.Enabled = value;
    }

    // Turning it off clears the activity at once; the choice is kept in discord.json.
    private void SetDiscordPresence(bool show, bool save) {
        if (save) {
            try { PresenceSettings.SaveShowActivity(root, show); }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { Console.WriteLine("Could not save the Discord setting: " + e.Message); }
        }
        if (!show || presenceSettings.ApplicationId == null) {
            presence?.Clear();
            presence?.Dispose();
            presence = null;
            return;
        }
        presence ??= new DiscordPresence(presenceSettings.ApplicationId);
        presence.Browsing();
    }

    // "Playing" lasts while that DreamSeeker runs, then the launcher goes back to browsing.
    private async void WatchGame(Process game, string server) {
        using (game) {
            presence?.Playing(server, DateTimeOffset.UtcNow);
            try { await game.WaitForExitAsync(); }
            catch (InvalidOperationException) { return; }
        }
        if (!IsDisposed) presence?.Browsing();
    }

    private void HostLine(string line) {
        Console.WriteLine(line);
        if (hostOutput == null) return;
        if (hostOutput.TextLength > 0) hostOutput.AppendText(Environment.NewLine);
        hostOutput.AppendText(line);
    }

    private void Open(ProcessStartInfo start, string what) => Open(() => { using var process = Process.Start(start); }, what);
    private void Open(Action start, string what) {
        try { start(); }
        catch (Exception e) when (e is Win32Exception or InvalidOperationException or IOException) {
            Console.WriteLine($"Could not open {what}: {e.Message}");
        }
    }

    private void SetStatus(string text) => statusLabel.Text = text;

    private void ReportError(string title, Exception error) {
        Console.WriteLine(title + ": " + error.Message);
        MessageBox.Show(this, error.Message, title, MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}
