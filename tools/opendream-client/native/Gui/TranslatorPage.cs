using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Translator tab: the Edge chat translator the host service keeps running for the whole group
// (tools/edge-translator). Stop keeps it stopped (the host service will not restart it) until Start;
// meanwhile chat is shown untranslated. Like Player help it belongs to the host service, so closing
// the launcher leaves it as it is.
internal sealed partial class LauncherWindow {
    private StatusLine? translatorState;
    private TextBox? translatorLog;
    private Button? translatorStart, translatorStop;
    private TranslatorStatus? translatorStatus;
    private bool translatorBusy;

    private TabPage BuildTranslatorPage(HostControl control) {
        var page = new TabPage("Translator") { Padding = new Padding(10) };
        var layout = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 1 };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
        layout.Controls.Add(new Label { AutoSize = true, Margin = new Padding(0, 3, 0, 6),
            Text = "Translates chat into each player's language with Microsoft Edge's built-in translator, on this computer only. " +
                "The host service starts it with the server and restarts it if it exits." });
        translatorState = new StatusLine { Margin = new Padding(0, 4, 0, 6) };
        translatorState.Set(Tone.Idle, Glyph.Arc, "Checking", "");
        layout.Controls.Add(translatorState);
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0) };
        translatorStart = new Button { Text = "Start", AutoSize = true, Enabled = false, Margin = new Padding(0, 6, 0, 6) };
        translatorStart.Click += async (_, _) => await RunTranslator(control, "translator-start");
        translatorStop = new Button { Text = "Stop", AutoSize = true, Enabled = false, Margin = new Padding(8, 6, 0, 6) };
        translatorStop.Click += async (_, _) => {
            if (MessageBox.Show(this, "Stop the chat translator? Chat is shown untranslated until it is started again.", "Civ13 Launcher",
                    MessageBoxButtons.OKCancel, MessageBoxIcon.Question) == DialogResult.OK) await RunTranslator(control, "translator-stop");
        };
        buttons.Controls.Add(translatorStart);
        buttons.Controls.Add(translatorStop);
        var folder = new LinkLabel { Text = "Open log folder", AutoSize = true, Margin = new Padding(12, 11, 0, 6) };
        folder.LinkClicked += (_, _) => {
            if (translatorStatus?.Log is { } log && Path.GetDirectoryName(log) is { } dir && Directory.Exists(dir))
                Open(new ProcessStartInfo(dir) { UseShellExecute = true }, "the chat translator log folder");
        };
        buttons.Controls.Add(folder);
        layout.Controls.Add(buttons);
        translatorLog = new TextBox { Dock = DockStyle.Fill, Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Both, WordWrap = false,
            Font = new Font(FontFamily.GenericMonospace, 9f) };
        layout.Controls.Add(translatorLog);
        for (var row = 0; row < 3; row++) layout.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        page.Controls.Add(layout);
        var poll = new System.Windows.Forms.Timer { Interval = 5000, Enabled = true };
        poll.Tick += async (_, _) => { if (tabs.SelectedTab == page) { await RefreshTranslator(control); RefreshTranslatorLog(false); } };
        page.Enter += async (_, _) => { await RefreshTranslator(control); RefreshTranslatorLog(true); };
        _ = RefreshTranslator(control);
        return page;
    }

    private async Task RefreshTranslator(HostControl control) {
        if (translatorState == null) return;
        TranslatorStatus status;
        try {
            var (exit, output) = await Task.Run(() => LocalHosting.RunCaptured(LocalHosting.GroupStep(control, "translator-status")));
            status = LocalTranslator.ParseStatus(exit, output);
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) {
            status = new TranslatorStatus(false, false, false, false, false, null, null, null, null, null, null, null, e.Message);
        }
        translatorStatus = status;
        if (!translatorBusy) {
            var (tone, glyph, pill) = !status.Ok ? (Tone.Bad, Glyph.Alert, "Unavailable")
                : !status.Configured ? (Tone.Idle, Glyph.Dash, "Not set up")
                : status.Stuck ? (Tone.Bad, Glyph.Alert, "Not answering")
                : !status.Running ? (Tone.Idle, Glyph.Ring, "Stopped")
                : !status.Answering ? (Tone.Busy, Glyph.Arc, "Starting")
                : (Tone.Good, Glyph.Dot, "Running");
            translatorState.Set(tone, glyph, pill, status.Describe());
        }
        UpdateTranslatorButtons();
    }

    private void UpdateTranslatorButtons() {
        var status = translatorStatus;
        var usable = !translatorBusy && status is { Ok: true, Configured: true };
        if (translatorStart != null) translatorStart.Enabled = usable && (status!.Stopped || !status.Running);
        if (translatorStop != null) translatorStop.Enabled = usable && (!status!.Stopped || status.Running);
    }

    private void RefreshTranslatorLog(bool force) {
        if (translatorLog == null || translatorStatus?.Log is not { } path) return;
        string text;
        try { text = File.Exists(path) ? LocalBot.Tail(path) : ""; }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { text = "Could not read the log: " + e.Message; }
        if (!force && text == translatorLog.Text) return;
        var atEnd = force || translatorLog.SelectionStart >= translatorLog.TextLength - 1;
        translatorLog.Text = text;
        if (atEnd) { translatorLog.SelectionStart = translatorLog.TextLength; translatorLog.ScrollToCaret(); }
    }

    private async Task RunTranslator(HostControl control, string action) {
        if (translatorBusy || translatorState == null) return;
        translatorBusy = true;
        UpdateTranslatorButtons();
        translatorState.Set(Tone.Busy, Glyph.Arc, "Working", action == "translator-stop" ? "Stopping the chat translator..." : "Starting the chat translator (the first start installs it)...");
        string line;
        try {
            var (exit, output) = await Task.Run(() => LocalHosting.RunCaptured(LocalHosting.GroupStep(control, action)));
            line = LocalTranslator.DescribeAction(action, exit, output);
        } catch (Exception e) when (e is Win32Exception or IOException or InvalidOperationException) { line = "Chat translator: " + e.Message; }
        Console.WriteLine(line);
        translatorBusy = false;
        await RefreshTranslator(control);
        translatorState.SetDetail(line + Environment.NewLine + translatorState.Detail);
        RefreshTranslatorLog(true);
    }
}
