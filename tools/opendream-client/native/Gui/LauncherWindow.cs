using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Text.Json;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Window front-end for the same launcher steps as the text menu (--console):
// launcher update check, BYOND setup, public server status and joining, BYOND sign in,
// community links, optional local hosting and server management (the Host server tab).
internal sealed partial class LauncherWindow : Form {
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
    // Instances the host reports asleep or waking, per provider. Display data and a
    // wake target only; joining one wakes it and then verifies the game port directly.
    private readonly Dictionary<string, Dictionary<GameTarget, DormantServer>> dormant = new();
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
    // Opens the Host server tab when host.json configures it, else the read-only registered-instances view.
    private readonly LinkLabel manageLink = new() { Text = "Registered instances (read-only)", AutoSize = true, Enabled = false };
    private TabPage? hostPage;
    private Label? hostState;
    private Button? hostStart;
    private TextBox? hostOutput;
    private DiscordPresence? presence;
    private PresenceSettings presenceSettings = new(false, null);
    private readonly CheckBox discordBox = new() { Text = "Show on Discord", AutoSize = true, Visible = false, Margin = new Padding(0, 1, 14, 0) };
    // Optional Discord sign-in for Civ13 accounts; shown only when discord.json names the sign-in service.
    private DiscordSignIn? signIn;
    private HttpClient? signInHttp;
    private readonly LinkLabel signInLink = new() { AutoSize = true, Visible = false, Margin = new Padding(0, 3, 14, 0) };
    private readonly List<Button> hostActions = [];
    private System.Windows.Forms.Timer? hostPoll;
    private bool hostControlBusy;
    private bool groupScriptRunning;

    public static int Run(string root, Version version) {
        var thread = new Thread(() => {
            ConsoleWindow.ReleaseIfOwned();
            Application.SetHighDpiMode(HighDpiMode.PerMonitorV2);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
            // Start-menu entry so Windows search (and computer use) can open the portable launcher.
            if (StartMenuShortcut.Ensure() is { } shortcutProblem) Console.WriteLine(shortcutProblem);
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
        FormClosing += async (_, e) => await StopBotBeforeClosing(e);
        FormClosed += (_, _) => { waitTimer.Dispose(); transport.Dispose(); signInHttp?.Dispose(); presence?.Clear(); presence?.Dispose(); ownedBot.Dispose(); };
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
        signInLink.LinkClicked += async (_, _) => await ToggleSignIn();
        tools.Controls.Add(signInLink);
        var dataFolder = new LinkLabel { Text = "Launcher data folder", AutoSize = true, Margin = new Padding(0, 3, 14, 0) };
        dataFolder.LinkClicked += (_, _) => Open(new ProcessStartInfo(root) { UseShellExecute = true }, "the launcher data folder");
        manageLink.Margin = new Padding(0, 3, 0, 0);
        manageLink.LinkClicked += (_, _) => {
            if (hostPage != null) { tabs.SelectedTab = hostPage; return; }
            using var dialog = new ManagementDialog();
            dialog.ShowDialog(this);
        };
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
        if (profile.Control?.Group is { } group) Row("Region group", group.Config + " (every region, deploy and the host service)");
        else Row("Update before start", profile.Update is { } update ? $"Fast-forward to origin/{update.Branch} and rebuild" : "Off");
        Row("Civilizationbot", profile.Bot != null ? "Started with the server if it is not running; see the Civilizationbot tab" : "Not configured");
        if (profile.MobileUrl is { } mobile) Row("Mobile LAN", mobile + " (paired certificate required; companion must be started separately)");
        hostState = new Label { AutoSize = true, Margin = new Padding(0, 10, 0, 6) };
        hostStart = new Button { Text = "Start server", AutoSize = true, Enabled = false, Margin = new Padding(0, 6, 0, 6) };
        hostStart.Click += async (_, _) => await StartHosting();
        var refresh = new Button { Text = "Check status", AutoSize = true, Margin = new Padding(8, 6, 0, 6) };
        refresh.Click += async (_, _) => await RefreshHostState();
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0) };
        buttons.Controls.Add(hostStart);
        if (profile.Control != null) {
            foreach (var (text, action) in new[] { ("Save and stop", "stop"), ("Restart", "restart"), ("Update", "update"),
                    ("Force stop", "kill"), ("Force restart", "force-restart"), ("Clear lock files", "unlock"), ("Force clear lock files", "force-unlock") }) {
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
        var groupButtons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0) };
        if (profile.Control?.Group != null) {
            groupButtons.Controls.Add(new Label { Text = "All regions:", AutoSize = true, Font = new Font(Font, FontStyle.Bold), Margin = new Padding(0, 11, 0, 6) });
            foreach (var (text, action) in new[] { ("Start", "start"), ("Save and stop", "stop"), ("Restart", "restart"), ("Update", "update"), ("Build update", "stage"),
                    ("Save, update and restart", "deploy"), ("Restart host service", "restart-host"), ("Force stop", "kill"), ("Force restart", "force-restart"),
                    ("Clear lock files", "unlock"), ("Force clear lock files", "force-unlock") }) {
                var button = new Button { Text = text, AutoSize = true, Margin = new Padding(8, 6, 0, 6) };
                button.Click += async (_, _) => await GroupAction(action, text);
                hostActions.Add(button);
                groupButtons.Controls.Add(button);
            }
            var epoch = new Button { Text = "Advance epoch", AutoSize = true, Margin = new Padding(8, 6, 0, 6) };
            epoch.Click += async (_, _) => await AdvanceEpoch();
            hostActions.Add(epoch);
            groupButtons.Controls.Add(epoch);
            var settings = new Button { Text = "Host settings", AutoSize = true, Margin = new Padding(8, 6, 0, 6) };
            settings.Click += (_, _) => ShowHostSettings();
            groupButtons.Controls.Add(settings);
            var hubNames = new Button { Text = "Hub names", AutoSize = true, Margin = new Padding(8, 6, 0, 6) };
            hubNames.Click += (_, _) => ShowHubNames();
            groupButtons.Controls.Add(hubNames);
        }
        layout.Controls.Add(groupButtons);
        layout.SetColumnSpan(groupButtons, 2);
        var regionButtons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0) };
        if (profile.Control?.Group is { } regionGroup) BuildRegionRow(regionGroup, regionButtons);
        layout.Controls.Add(regionButtons);
        layout.SetColumnSpan(regionButtons, 2);
        hostOutput = new TextBox { Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical };
        layout.Controls.Add(hostOutput);
        layout.SetColumnSpan(hostOutput, 2);
        for (var row = 0; row < 9; row++) layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        page.Controls.Add(layout);
        page.Enter += async (_, _) => await RefreshHostState();
        return page;
    }

    // One region of the group: the same shard_group.py actions with --region, plus sleep and wake, staging,
    // the handover deploy for just this region (deploy.bat REGION),
    // applying host settings and setting a region up (a new one added to the group config, or a refresh).
    private void BuildRegionRow(HostGroup group, FlowLayoutPanel row) {
        IReadOnlyList<LocalHosting.GroupRegion> regions;
        try { regions = LocalHosting.GroupRegions(group); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException or InvalidDataException) {
            row.Controls.Add(new Label { Text = "Regions unavailable: " + e.Message, AutoSize = true, Margin = new Padding(0, 11, 0, 6) });
            return;
        }
        row.Controls.Add(new Label { Text = "One region:", AutoSize = true, Font = new Font(Font, FontStyle.Bold), Margin = new Padding(0, 11, 0, 6) });
        var picker = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 260, Margin = new Padding(8, 7, 0, 6) };
        void Fill(string? keep) {
            picker.Items.Clear();
            foreach (var region in regions) {
                var ports = region.Port > 0 ? " - port " + region.Port + (region.TransferPort > 0 ? ", travel " + region.TransferPort : "") : "";
                picker.Items.Add(region.Name + (region.Mainland ? " (mainland)" : "") + ports);
            }
            var index = keep == null ? 0 : regions.ToList().FindIndex(region => region.Id == keep);
            picker.SelectedIndex = Math.Max(0, index);
        }
        Fill(null);
        // Re-read the group config each time the list opens, so a region just added to it can be set up.
        picker.DropDown += (_, _) => {
            try { var keep = Chosen(); regions = LocalHosting.GroupRegions(group); Fill(keep); }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException or InvalidDataException) { HostLine("Could not re-read the regions: " + e.Message); }
        };
        row.Controls.Add(picker);
        string Chosen() => regions[Math.Max(0, picker.SelectedIndex)].Id;
        foreach (var (text, action) in new[] { ("Start", "start"), ("Save and stop", "stop"), ("Restart", "restart"), ("Update", "update"),
                ("Build update", "stage"), ("Save, update and restart", "deploy"), ("Sleep now", "freeze"), ("Wake", "thaw"), ("Apply host settings", "config-apply"), ("Set up", "setup"),
                ("Force stop", "kill"), ("Force restart", "force-restart"), ("Clear lock files", "unlock"), ("Force clear lock files", "force-unlock"), ("Fresh world…", "fresh-world") }) {
            var button = new Button { Text = text, AutoSize = true, Margin = new Padding(8, 6, 0, 6) };
            button.Click += async (_, _) => await GroupAction(action, text, Chosen());
            hostActions.Add(button);
            row.Controls.Add(button);
        }
        var regionLog = new LinkLabel { Text = "Open its world log", AutoSize = true, Margin = new Padding(12, 11, 0, 6) };
        regionLog.LinkClicked += (_, _) => {
            string? path;
            try { path = LocalHosting.RegionLog(group, Chosen()); }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException) { HostLine("Could not read " + group.Config + ": " + e.Message); return; }
            if (path == null) { HostLine("The group config names no root folder."); return; }
            Open(new ProcessStartInfo(path) { UseShellExecute = true }, "the world log");
        };
        row.Controls.Add(regionLog);
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
        if (host != null) {
            tabs.TabPages.Add(hostPage = BuildHostPage(host));
            if (host.Bot is { } bot) tabs.TabPages.Add(BuildBotPage(bot));
            if (host.Control is { Group: not null } helpControl) tabs.TabPages.Add(BuildHelpPage(helpControl));
            if (host.Control != null || host.Bot != null) {
                tabs.TabPages.Add(BuildUpdatesPage(host));
                _ = CheckAllUpdates();
            }
        }
        presenceSettings = PresenceSettings.Load(root);
        if (presenceSettings.ApplicationId != null) {
            discordBox.Checked = presenceSettings.ShowActivity;
            discordBox.Visible = true;
            SetDiscordPresence(presenceSettings.ShowActivity, false);
        }
        if (DiscordSignInSettings.Load(root) is { } signInSettings) {
            signInHttp = new HttpClient(new HttpClientHandler { AllowAutoRedirect = false });
            signIn = new DiscordSignIn(signInSettings, root, signInHttp, url => {
                try { using var browser = Process.Start(new ProcessStartInfo(url.AbsoluteUri) { UseShellExecute = true }); return true; }
                catch (Exception e) when (e is System.ComponentModel.Win32Exception or InvalidOperationException) { return false; }
            });
            signInLink.Visible = true;
            UpdateSignInLink();
        }
        startupDone = true;
        if (hostPage != null) manageLink.Text = "Server management";
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
        notesLabel.Text = $"Checking {provider} servers... A sleeping server can take up to 15 seconds to wake.";
        var servers = KnownFor(provider);
        Populate();
        try {
            var snapshot = await discovery.Fetch(provider);
            var sleeping = DormantFor(provider);
            sleeping.Clear();
            foreach (var server in snapshot.Dormant ?? []) sleeping[server.Target] = server;
            var answered = new HashSet<GameTarget>();
            foreach (var server in snapshot.Servers) {
                var cached = ServerBrowser.CachedFor(snapshot, server);
                var status = cached == null ? $"Checked {server.CheckedAt:HH:mm:ss} UTC"
                    : $"Cached, {cached.AgeSeconds}s old" + (cached.Recent != null ? "" : "; recheck needed");
                servers[server.Target] = new KnownServer(server, status);
                answered.Add(server.Target);
            }
            foreach (var (target, entry) in servers) {
                if (answered.Contains(target) || sleeping.ContainsKey(target)) continue;
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

    private Dictionary<GameTarget, DormantServer> DormantFor(string provider) {
        if (!dormant.TryGetValue(provider, out var servers)) dormant[provider] = servers = new();
        return servers;
    }

    internal static string DormantStatus(DormantServer server) {
        var state = server.State == "waking" ? "Waking" : "Asleep";
        var age = server.CachedAgeSeconds is { } seconds ? ", last seen " + ServerBrowser.Age(seconds) + " ago" : "";
        return $"{state}; wakes on join (~{ServerBrowser.Age(server.WakeEstimateSeconds)}){age}";
    }

    private static string LastSeen(KnownServer entry) => $"last seen {entry.Server.CheckedAt:HH:mm} UTC";

    private void Populate() {
        var keep = Selected()?.Target ?? SelectedDormant()?.Target;
        serverList.BeginUpdate();
        serverList.Items.Clear();
        if (Provider is { } provider) {
            var sleeping = DormantFor(provider);
            var rows = new List<(int Port, ListViewItem Item, GameTarget Target)>();
            foreach (var entry in KnownFor(provider).Values) {
                var server = entry.Server;
                if (sleeping.ContainsKey(server.Target)) continue;
                rows.Add((server.Port, new ListViewItem([server.Name, server.Players.ToString(), ServerBrowser.Display(server.Map),
                    ServerBrowser.Display(server.Mode), server.Epoch.Length == 0 ? "-" : server.Epoch, ServerBrowser.Display(server.RoundId),
                    ServerBrowser.Elapsed(server), entry.Status]) { Tag = server }, server.Target));
            }
            foreach (var server in sleeping.Values)
                rows.Add((server.Target.Port, new ListViewItem([server.Name, server.Players.ToString(), ServerBrowser.Display(server.Map),
                    ServerBrowser.Display(server.Mode), "-", "-", "-", DormantStatus(server)]) { Tag = server }, server.Target));
            foreach (var row in rows.OrderBy(row => row.Port)) {
                serverList.Items.Add(row.Item);
                if (row.Target == keep) row.Item.Selected = true;
            }
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
    private DormantServer? SelectedDormant() => serverList.SelectedItems.Count == 1 ? serverList.SelectedItems[0].Tag as DormantServer : null;

    // Wake and join: thaw through the host, then the same direct verification as Join.
    private async Task WakeAndJoin(DormantServer selected) {
        if (byond == null) return;
        SetBusy(true);
        try {
            var verified = await discovery.WakeAndVerify(selected, message => joinStatus.Text = message);
            DormantFor(selected.Provider).Remove(selected.Target);
            KnownFor(selected.Provider)[selected.Target] = new KnownServer(verified.Status, $"Checked {verified.Status.CheckedAt:HH:mm:ss} UTC");
            Populate();
            var ticket = await JoinTicket(verified.Status.Port);
            var game = Program.StartNativeGame(verified, byond, desktop, Console.Out, ticket);
            WatchGame(game, DiscordPresence.ServerLine(verified.Status));
            joinStatus.Text = $"Started BYOND for {selected.Name}.";
        } catch (TopicWaitException wait) {
            joinStatus.Text = "";
            notesLabel.Text = $"{selected.Name} is waking. Wait {wait.Seconds} seconds, then Refresh and join. No automatic check will run.";
        } catch (TopicPacingException) {
            joinStatus.Text = "";
            notesLabel.Text = "Public checks paused: shared request timing could not be verified. Local timing state needs review.";
        } catch (IOException error) {
            joinStatus.Text = "";
            notesLabel.Text = error.Message;
        } finally {
            SetBusy(false);
        }
    }

    private async Task Join() {
        if (pending == null && SelectedDormant() is { } sleeping) {
            if (byond != null && joinButton.Enabled) await WakeAndJoin(sleeping);
            return;
        }
        var selected = pending ?? Selected();
        if (selected == null || byond == null || !joinButton.Enabled) return;
        SetBusy(true);
        joinStatus.Text = $"Verifying {selected.Name}...";
        try {
            // The ticket comes first: the recheck's answer is only fresh for a short while.
            var ticket = await JoinTicket(selected.Target.Port);
            var verified = await discovery.Recheck(selected);
            var game = Program.StartNativeGame(verified, byond, desktop, Console.Out, ticket);
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
            joinButton.Text = SelectedDormant() != null ? "Wake and join" : "Join";
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
        joinButton.Enabled = byond != null && !busy && !waiting && (pending != null || Selected() != null || SelectedDormant() != null);
        if (pending == null) joinButton.Text = SelectedDormant() != null ? "Wake and join" : "Join";
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
            var busy = answer.Busy;
            var text = answer.Message;
            if (control.Group != null) {
                ControlAnswer group;
                try { group = await Task.Run(() => LocalHosting.RunGroup(control, "status")); }
                catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) { group = new ControlAnswer(false, "Group status unavailable: " + e.Message, false); }
                text += Environment.NewLine + group.Message;
                busy |= group.Busy;
            }
            hostState.Text = text;
            SetHostBusy(busy || groupScriptRunning);
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
            // The bot supervisor is started by this window, not detached, so it stops when the launcher closes.
            var botWanted = false;
            var lines = await Task.Run(() => LocalHosting.Run(profile, bin, LocalHosting.Listening, start => {
                if (profile.Bot is { } bot && start.FileName == bot.Php) botWanted = true;
                else { using var process = Process.Start(start); }
            }));
            foreach (var line in lines) HostLine(line);
            if (botWanted) await StartBot();
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            HostLine("Local hosting failed: " + e.Message);
        } finally {
            hostStart.Enabled = byond != null;
            await RefreshHostState();
        }
    }

    private const string UnlockQuestion = "Check the save for BYOND lock files (left when a world is killed) and remove them? "
        + "Only worlds that are stopped with no action running are touched.";
    private const string ForceUnlockQuestion = "Remove BYOND lock files even from a world that looks running? Use this only when its "
        + "dd.exe is gone. Removing a lock a running world holds can corrupt its save.";

    // Accepted actions finish in the script's worker; the timer follows them until they settle.
    private async Task HostAction(string action, string label) {
        if (host?.Control is not { } control) return;
        var forced = action is "kill" or "force-restart" or "force-unlock";
        var question = action switch {
            "unlock" => UnlockQuestion,
            "force-unlock" => ForceUnlockQuestion,
            _ => forced ? label + " the server? It is ended at once WITHOUT saving: anything since the last completed save is lost. Use this only for a server that hangs."
                : label + " the server? Players are saved and can rejoin when it is back.",
        };
        if (action != "update" && MessageBox.Show(this, question, "Civ13 Launcher",
                MessageBoxButtons.OKCancel, forced ? MessageBoxIcon.Warning : MessageBoxIcon.Question) != DialogResult.OK) return;
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

    // Group actions run shard_group.py for every region; deploy and restart-host run their .bat in a
    // hidden cmd.exe and stream its lines here. Nothing opens a console window or takes focus.
    // region: one region id (the One region row), or null for every region.
    private async Task GroupAction(string action, string label, string? region = null) {
        if (host?.Control is not { } control || control.Group == null || hostOutput == null) return;
        var target = region == null ? "every region" : "region " + region;
        var question = action switch {
            "update" => $"Check out and compile the group's revision in {(region == null ? "every stopped region" : target + " (it must be stopped)")}?",
            "stage" => $"Build the latest update beside {target} while the worlds keep running? Nobody is kicked. " +
                "Save, update and restart then only has to hand each running region over; a region that is asleep or empty gets it on its own.",
            "restart-host" => "Restart the host service? The worlds keep running.",
            "unlock" => UnlockQuestion,
            "force-unlock" => ForceUnlockQuestion,
            "freeze" => $"Put {target} to sleep now? Only an empty, saved world sleeps; a join or travel wakes it.",
            "thaw" => $"Wake {target} from sleep?",
            "config-apply" => $"Write the overlays' host settings into {target}? A running world uses them from its next restart.",
            "setup" => $"Create or refresh {target}'s folder and config? It must be stopped. A region newly added to the group config is set up "
                + "and enrolled for travel with the running regions, which keep running.",
            "kill" or "force-restart" => $"{label} {target}? It is ended at once WITHOUT saving: anything since its last completed save is lost. Use this only for a server that hangs.",
            "restart" => $"{label} {target}? It saves, stops and starts on the build it has, so players are kicked until it is back. " +
                "To move players over without kicking them, use Save, update and restart: it builds the latest master beside the running world, " +
                "and players keep playing on the old world (held only while their own level saves) until the new one has loaded the save.",
            _ => $"{label} {target}? Players are saved and can rejoin when it is back.",
        };
        if (action == "fresh-world") { if (region != null) await FreshWorld(region); return; }
        if (action == "deploy") { await ChooseAndDeploy(label, region); return; }
        if (MessageBox.Show(this, question, "Civ13 Launcher", MessageBoxButtons.OKCancel,
                action == "force-unlock" ? MessageBoxIcon.Warning : MessageBoxIcon.Question) != DialogResult.OK) return;
        SetHostBusy(true);
        if (action == "restart-host") {
            groupScriptRunning = true;
            HostLine(label + "...");
            try {
                var (exit, _) = await RunGroupScript(control, action, false);
                HostLine(exit == 0 ? label + " finished." : $"{label} stopped with exit code {exit}; see the lines above.");
            } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
                HostLine(label + " failed: " + e.Message);
            } finally {
                groupScriptRunning = false;
                await RefreshHostState();
            }
            return;
        }
        try {
            if (action == "setup") HostLine($"Setting up {target}; fetching and making its worktree can take a minute...");
            var answer = await Task.Run(() => LocalHosting.RunGroup(control, action, null, region));
            HostLine(answer.Message);
            // These finish at once rather than in a worker the status poll follows.
            if (!answer.Ok || !answer.Busy) SetHostBusy(false);
            if (!answer.Busy) await RefreshHostState();
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            HostLine(label + " failed: " + e.Message);
            SetHostBusy(false);
        }
    }

    private async Task FreshWorld(string region) {
        if (host?.Control is not { Group: not null } control) return;
        using var dialog = new Form { Text = "Start a fresh world: " + region, FormBorderStyle = FormBorderStyle.FixedDialog,
            MinimizeBox = false, MaximizeBox = false, StartPosition = FormStartPosition.CenterParent,
            AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Padding = new Padding(12) };
        var layout = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, AutoSize = true, WrapContents = false };
        layout.Controls.Add(new Label { Text = "Use Save and stop first. This archives this region's map save, backups and rollback, " +
            "then starts its existing build on a fresh map. Buildings, factions, local player-built transits, saved bodies and their inventory " +
            "are removed from the active world. Account preferences/notes, bans, settings, reputation and raid cooldowns remain. " +
            "Linked transfer groups and separate extraction/vehicle storage are refused: their shared transits need a coordinated reset. " +
            "Nothing is permanently deleted; recovery is manual from the archive reported in the host log. " +
            "Type the exact region id to confirm: " + region,
            MaximumSize = new Size(480, 0), AutoSize = true });
        var confirmation = new TextBox { Width = 300 };
        var go = new Button { Text = "Archive world and start fresh", DialogResult = DialogResult.OK, AutoSize = true, Enabled = false };
        confirmation.TextChanged += (_, _) => go.Enabled = confirmation.Text == region;
        layout.Controls.Add(confirmation);
        layout.Controls.Add(go);
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true };
        layout.Controls.Add(cancel);
        dialog.Controls.Add(layout);
        dialog.CancelButton = cancel;
        if (dialog.ShowDialog(this) != DialogResult.OK || confirmation.Text != region) return;
        SetHostBusy(true);
        try {
            var answer = await Task.Run(() => LocalHosting.RunGroup(control, "fresh-world", null, region, null, region));
            HostLine(answer.Message);
            if (!answer.Ok || !answer.Busy) SetHostBusy(false);
            if (!answer.Busy) await RefreshHostState();
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            HostLine("Fresh world refused: " + e.Message);
            SetHostBusy(false);
        }
    }

    // Advance epoch: the mainland takes the chosen epoch live (no restart), then every awake region; the
    // others follow the mainland when they next run (shard_group.py epoch). Epochs only move forward.
    private async Task AdvanceEpoch() {
        if (host?.Control is not { Group: not null } control) return;
        using var dialog = new Form { Text = "Advance epoch", FormBorderStyle = FormBorderStyle.FixedDialog, MinimizeBox = false, MaximizeBox = false,
            StartPosition = FormStartPosition.CenterParent, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Padding = new Padding(12) };
        var layout = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, AutoSize = true, WrapContents = false };
        layout.Controls.Add(new Label { Text = "Move every region to this epoch now, with no restart. The mainland changes first and every running " +
            "region with it; a region that is asleep or stopped catches up when it next runs. Epochs only move forward: a region already " +
            "there or later keeps its own. Players see the change announced. This cannot be undone from the launcher.",
            MaximumSize = new Size(460, 0), AutoSize = true, Margin = new Padding(0, 0, 0, 8) });
        var picker = new ComboBox { DropDownStyle = ComboBoxStyle.DropDownList, Width = 200 };
        picker.Items.AddRange(LocalHosting.EpochNames);
        layout.Controls.Add(picker);
        var buttons = new FlowLayoutPanel { FlowDirection = FlowDirection.RightToLeft, AutoSize = true, Width = 460, Margin = new Padding(0, 8, 0, 0) };
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true };
        var go = new Button { Text = "Advance", DialogResult = DialogResult.OK, AutoSize = true, Enabled = false };
        picker.SelectedIndexChanged += (_, _) => go.Enabled = picker.SelectedIndex >= 0;
        buttons.Controls.Add(cancel);
        buttons.Controls.Add(go);
        layout.Controls.Add(buttons);
        dialog.Controls.Add(layout);
        dialog.AcceptButton = go;
        dialog.CancelButton = cancel;
        if (dialog.ShowDialog(this) != DialogResult.OK || picker.SelectedIndex < 0) return;
        var ordinal = picker.SelectedIndex;
        SetHostBusy(true);
        try {
            HostLine("Advancing every region to the epoch " + LocalHosting.EpochNames[ordinal] + "...");
            HostLine((await Task.Run(() => LocalHosting.RunGroup(control, "epoch", null, null, ordinal))).Message);
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            HostLine("Advance epoch failed: " + e.Message);
        } finally {
            SetHostBusy(false);
            await RefreshHostState();
        }
    }

    // The host's own config files in the group's overlays (HostSettingsDialog); not tied to a running action.
    private void ShowHostSettings() {
        if (host?.Control is not { } control || OverlayLocations() is not { } locations) return;
        using var dialog = new HostSettingsDialog(control, locations);
        dialog.ShowDialog(this);
    }

    // The name each region shows on the BYOND hub (SERVER_NAME in its overlay), as its own window.
    private void ShowHubNames() {
        if (host?.Control is not { } control || OverlayLocations() is not { } locations) return;
        using var dialog = new HubNamesDialog(control, locations);
        dialog.ShowDialog(this);
    }

    private IReadOnlyList<HostSettings.Location>? OverlayLocations() {
        if (host?.Control is not { Group: { } group }) return null;
        IReadOnlyList<HostSettings.Location> locations;
        try { locations = HostSettings.Locations(group); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.Text.Json.JsonException) {
            HostLine("Could not read the overlays from " + group.Config + ": " + e.Message);
            return null;
        }
        if (locations.Count == 0) {
            HostLine("The group config names no overlay folder. Add \"overlay\" (for every region) or a region's \"overlay\" to " + group.Config + " first.");
            return null;
        }
        return locations;
    }

    private const string DeployQuestion = "Update the regions ticked below without stopping them. The checkout is pulled and the update " +
        "is built beside each running world first; nobody is kicked until every build is ready, and a failed build stops here. Then each " +
        "running region is handed over, one at a time: the new build starts beside it, the old world saves (players are held only while " +
        "their own level is saved, a minute or two, then play on), the new one loads that save, and players reconnect to it within seconds. " +
        "Anything done after a level was saved is end-of-round play and is not carried over. If the save or the " +
        "load fails, the old world carries on and nothing is lost. A region still on a build from before handovers is saved, stopped and " +
        "started instead, once. Regions that are asleep get the new build when they wake; regions left unticked keep running.";

    // Asks which regions to update (all ticked, or only `only` from the One region row; the mainland is
    // marked), then deploys them.
    private async Task ChooseAndDeploy(string label, string? only = null) {
        if (host?.Control?.Group is not { } group) return;
        IReadOnlyList<LocalHosting.GroupRegion> regions;
        try { regions = LocalHosting.GroupRegions(group); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.Text.Json.JsonException or InvalidDataException) {
            HostLine("Could not read the regions from " + group.Config + ": " + e.Message);
            return;
        }
        using var dialog = new Form { Text = label, FormBorderStyle = FormBorderStyle.FixedDialog, MinimizeBox = false, MaximizeBox = false,
            StartPosition = FormStartPosition.CenterParent, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Padding = new Padding(12) };
        var layout = new FlowLayoutPanel { FlowDirection = FlowDirection.TopDown, AutoSize = true, WrapContents = false };
        layout.Controls.Add(new Label { Text = DeployQuestion, MaximumSize = new Size(460, 0), AutoSize = true, Margin = new Padding(0, 0, 0, 8) });
        var list = new CheckedListBox { CheckOnClick = true, Width = 460, Height = Math.Min(16, regions.Count) * 20 + 8, IntegralHeight = false };
        foreach (var region in regions) list.Items.Add(region.Mainland ? region.Name + " (mainland)" : region.Name, only == null || region.Id == only);
        layout.Controls.Add(list);
        var buttons = new FlowLayoutPanel { FlowDirection = FlowDirection.RightToLeft, AutoSize = true, Width = 460, Margin = new Padding(0, 8, 0, 0) };
        var cancel = new Button { Text = "Cancel", DialogResult = DialogResult.Cancel, AutoSize = true };
        var go = new Button { Text = label, DialogResult = DialogResult.OK, AutoSize = true };
        buttons.Controls.Add(cancel);
        buttons.Controls.Add(go);
        layout.Controls.Add(buttons);
        dialog.Controls.Add(layout);
        dialog.AcceptButton = go;
        dialog.CancelButton = cancel;
        // ItemCheck fires before the box changes, so count the pending state.
        list.ItemCheck += (_, e) => go.Enabled = list.CheckedIndices.Count + (e.NewValue == CheckState.Checked ? 1 : 0) - (e.CurrentValue == CheckState.Checked ? 1 : 0) > 0;
        if (dialog.ShowDialog(this) != DialogResult.OK || list.CheckedIndices.Count == 0) return;
        var chosen = list.CheckedIndices.Cast<int>().Select(index => regions[index].Id).ToList();
        // Every region ticked runs the whole group, so a region added to the config later is never skipped.
        // From the One region row the ids stay explicit, so a region added meanwhile is never pulled in.
        await DeployGroup(label, only == null && chosen.Count == regions.Count ? [] : chosen);
    }

    // The whole update (deploy.bat): pull, stage the build beside the running worlds, then once every build is
    // ready hand each running region over to it (scripts/shard-group handover) and restart the host service.
    // The exit-3 loop below belonged to the stop-and-start deploy; a handover never leaves a world stopped,
    // so deploy.bat no longer returns it. It stays for an older deploy.bat on the host.
    // The Host tab's group status line shows each region's staged build and a standby loading beside it.
    // A region whose world does not save (refused because it is busy, or the save failed) is still running
    // when deploy.bat stops at the save step; nothing has been updated yet. The operator then chooses:
    // force-stop those regions without a save and carry on, or start the regions that did stop again.
    private async Task DeployGroup(string label, IReadOnlyList<string> regions) {
        if (host?.Control is not { } control || control.Group == null || groupScriptRunning) return;
        SelectHostTab();
        SetHostBusy(true);
        groupScriptRunning = true;
        ShowServerUpdateBusy();
        var which = regions.Count == 0 ? "every region" : string.Join(", ", regions);
        HostLine($"{label}: {which}...");
        try {
            var (exit, output) = await RunGroupScript(control, "deploy", false, regions);
            while (exit == LocalHosting.DeployUnsaved) {
                var (_, status) = await Task.Run(() => LocalHosting.RunCaptured(LocalHosting.GroupStep(control, "status")));
                // Regions left out of the deploy keep running on purpose.
                var unsaved = LocalHosting.UnsavedRegions(status, output).Where(region => regions.Count == 0 || regions.Contains(region.Id)).ToList();
                if (unsaved.Count == 0) break;
                var names = string.Join(Environment.NewLine, unsaved.Select(region => "  " + region.Name + ": " + region.Reason));
                HostLine("Did not save, still running:" + Environment.NewLine + names);
                var choice = MessageBox.Show(this,
                    "These regions did not save, so they are still running and nothing has been updated yet:" + Environment.NewLine + Environment.NewLine +
                    names + Environment.NewLine + Environment.NewLine +
                    "Yes: force-stop them WITHOUT saving and carry on with the update. They go back to their last completed save, " +
                    "so anything played there since then is lost." + Environment.NewLine +
                    "No: cancel the update and start the regions that already stopped again.",
                    "Civ13 Launcher", MessageBoxButtons.YesNo, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button2);
                if (choice != DialogResult.Yes) {
                    HostLine("Update cancelled. Starting the regions that stopped again...");
                    if (regions.Count == 0) HostLine((await Task.Run(() => LocalHosting.RunGroup(control, "start"))).Message);
                    else foreach (var region in regions) HostLine((await Task.Run(() => LocalHosting.RunGroup(control, "start", null, region))).Message);
                    return;
                }
                foreach (var region in unsaved)
                    HostLine((await Task.Run(() => LocalHosting.RunGroup(control, "kill", null, region.Id))).Message);
                HostLine("Carrying on with the update...");
                (exit, output) = await RunGroupScript(control, "deploy", true, regions);
            }
            HostLine(exit == 0 ? label + " finished." : $"{label} stopped with exit code {exit}; see the lines above.");
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            HostLine(label + " failed: " + e.Message);
        } finally {
            groupScriptRunning = false;
            await RefreshHostState();
            await CheckAllUpdates();
        }
    }

    // Runs deploy.bat or restart-host.bat, streaming each line to the Host tab; returns its exit code and output.
    private async Task<(int Exit, string Output)> RunGroupScript(HostControl control, string script, bool resume, IReadOnlyList<string>? regions = null) {
        var output = new System.Text.StringBuilder();
        var exit = await Task.Run(() => {
            using var process = Process.Start(LocalHosting.GroupScriptStep(control, script, resume, regions)) ?? throw new IOException("Could not start cmd.exe.");
            process.StandardInput.Close();
            void Line(object _, DataReceivedEventArgs e) {
                if (e.Data is not { Length: > 0 } text) return;
                lock (output) output.AppendLine(text);
                BeginInvoke(() => HostLine(text));
            }
            process.OutputDataReceived += Line;
            process.ErrorDataReceived += Line;
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            process.WaitForExit();
            return process.ExitCode;
        });
        lock (output) return (exit, output.ToString());
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

    private void UpdateSignInLink() {
        signInLink.Text = signIn?.SignedIn == true ? "Signed in with Discord (sign out)" : "Sign in with Discord";
    }

    private async Task ToggleSignIn() {
        if (signIn == null) return;
        if (signIn.SignedIn) {
            signIn.SignOut();
            Console.WriteLine("Signed out of Discord. Joins use your BYOND key only.");
        } else {
            signInLink.Enabled = false;
            Console.WriteLine("Opening Discord sign-in in your browser...");
            try {
                await signIn.SignInInteractive();
                Console.WriteLine("Signed in with Discord. Joins now carry a one-time sign-in ticket.");
            } catch (DiscordSignInException e) {
                Console.WriteLine("Discord sign-in failed: " + e.Message);
            } finally { signInLink.Enabled = true; }
        }
        UpdateSignInLink();
    }

    // Discord is optional: any sign-in failure joins with the BYOND key alone.
    private async Task<string?> JoinTicket(int port) {
        if (signIn?.SignedIn != true) return null;
        try { return await signIn.JoinTicket(port); }
        catch (DiscordSignInException e) {
            Console.WriteLine("Joining without Discord sign-in: " + e.Message);
            UpdateSignInLink();
            return null;
        }
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
