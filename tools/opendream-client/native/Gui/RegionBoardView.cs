using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// The Host server tab's region board: a summary of counts, then one row per region with its state pill,
// name, players, build pill and notes. A region with a problem gets a red edge and a second line saying
// what is wrong. Clicking a row (or Up/Down) chooses that region for the "Selected region" buttons.
internal sealed class RegionBoardView : ScrollableControl {
    private IReadOnlyList<RegionCard> cards = [];
    private bool? coordinator;
    private string checkedText = "";
    private string? message = "Checking...";
    private bool messageIsError;
    private string? selected;
    private int hover = -1;
    private string tipText = "";
    private readonly ToolTip tip = new() { AutoPopDelay = 30000, InitialDelay = 400, ReshowDelay = 100 };
    private Font? bold, small, pillFont;

    // False for a single server: there is nothing to choose between.
    public bool Choosable { get; set; } = true;
    public event Action<string>? Chosen;

    public RegionBoardView() {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        BackColor = Color.White;
        AutoScroll = true;
        TabStop = true;
        Dock = DockStyle.Fill;
        AccessibleName = "Region status";
        AccessibleRole = AccessibleRole.List;
    }

    public string? Selected {
        get => selected;
        set { if (selected != value) { selected = value; Invalidate(); } }
    }

    public IReadOnlyList<RegionCard> Cards => cards;

    public void ShowCards(IReadOnlyList<RegionCard> shown, bool? coordinatorRunning, string checkedAt) {
        cards = shown;
        coordinator = coordinatorRunning;
        checkedText = checkedAt;
        message = shown.Count == 0 ? "No regions reported." : null;
        messageIsError = false;
        if (Choosable && shown.Count > 0 && shown.All(card => card.Id != selected)) selected = shown[0].Id;
        AccessibleDescription = string.Join(" ", shown.Select(card => card.Describe()));
        Relayout();
    }

    // Keeps the last rows on screen under the message when a status check fails, so a blip does not blank the board.
    public void ShowMessage(string text, bool error) {
        message = text;
        messageIsError = error;
        AccessibleDescription = text;
        Relayout();
    }

    private float Dpi => DeviceDpi / 96f;
    private int Px(float logical) => (int)Math.Round(logical * Dpi);
    private Font Bold => bold ??= new Font(Font, FontStyle.Bold);
    private Font Small => small ??= new Font(Font.FontFamily, 7.5f, FontStyle.Bold);
    private Font PillFont => pillFont ??= new Font(Font.FontFamily, 8.25f, FontStyle.Bold);

    protected override void OnFontChanged(EventArgs e) {
        base.OnFontChanged(e);
        bold?.Dispose(); small?.Dispose(); pillFont?.Dispose();
        bold = small = pillFont = null;
        Relayout();
    }

    protected override void Dispose(bool disposing) {
        if (disposing) { bold?.Dispose(); small?.Dispose(); pillFont?.Dispose(); tip.Dispose(); }
        base.Dispose(disposing);
    }

    private int SummaryHeight => Px(34);
    private int HeaderHeight => Px(20);
    private int MessageHeight => message == null ? 0 : Px(28);
    private int RowHeight(RegionCard card) => Px(card.Problem == null ? 28 : 46);

    private void Relayout() {
        AutoScrollMinSize = new Size(0, SummaryHeight + MessageHeight + (cards.Count == 0 ? 0 : HeaderHeight) + cards.Sum(RowHeight) + 1);
        Invalidate();
    }

    private int RowAt(Point point) {
        var y = point.Y - AutoScrollPosition.Y - SummaryHeight - MessageHeight - HeaderHeight;
        if (y < 0) return -1;
        for (var index = 0; index < cards.Count; index++) {
            y -= RowHeight(cards[index]);
            if (y < 0) return index;
        }
        return -1;
    }

    protected override void OnMouseMove(MouseEventArgs e) {
        base.OnMouseMove(e);
        var row = RowAt(e.Location);
        if (row == hover) return;
        hover = row;
        var text = row >= 0 ? cards[row].Describe() : "";
        if (text != tipText) tip.SetToolTip(this, tipText = text);
        Invalidate();
    }

    protected override void OnMouseLeave(EventArgs e) {
        base.OnMouseLeave(e);
        if (hover == -1) return;
        hover = -1;
        Invalidate();
    }

    protected override void OnMouseDown(MouseEventArgs e) {
        base.OnMouseDown(e);
        Focus();
        if (RowAt(e.Location) is >= 0 and var row) Choose(row);
    }

    protected override bool IsInputKey(Keys keyData) => keyData is Keys.Up or Keys.Down || base.IsInputKey(keyData);

    protected override void OnKeyDown(KeyEventArgs e) {
        base.OnKeyDown(e);
        if (!Choosable || cards.Count == 0 || e.KeyCode is not (Keys.Up or Keys.Down)) return;
        var index = cards.ToList().FindIndex(card => card.Id == selected);
        Choose(Math.Clamp(index + (e.KeyCode == Keys.Down ? 1 : -1), 0, cards.Count - 1));
        e.Handled = true;
    }

    protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
    protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); Invalidate(); }

    private void Choose(int row) {
        if (!Choosable || cards[row].Id == selected) return;
        selected = cards[row].Id;
        Invalidate();
        Chosen?.Invoke(selected);
    }

    private const TextFormatFlags OneLine = TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis
        | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix;

    protected override void OnPaint(PaintEventArgs e) {
        PaintBoard(e.Graphics);
        using var border = new Pen(StatusPaint.Line);
        e.Graphics.DrawRectangle(border, 0, 0, ClientSize.Width - 1, ClientSize.Height - 1);
    }

    private void PaintBoard(Graphics g) {
        g.Clear(BackColor);
        var width = ClientSize.Width;
        var y = AutoScrollPosition.Y;

        // Summary band: what needs attention first, then the plain counts.
        using (var band = new SolidBrush(StatusPaint.Band)) g.FillRectangle(band, 0, y, width, SummaryHeight);
        var x = Px(10);
        var pillHeight = Px(20);
        var counts = HostBoard.Summary(cards).ToList();
        foreach (var count in counts) {
            var (tone, glyph) = StatusPaint.ForCount(count.Kind);
            var pillWidth = StatusPaint.PillWidth(g, count.Text, PillFont, glyph, Dpi);
            StatusPaint.Pill(g, new Rectangle(x, y + (SummaryHeight - pillHeight) / 2, pillWidth, pillHeight), tone, glyph, count.Text, PillFont, Dpi);
            x += pillWidth + Px(6);
        }
        if (cards.Count > 0 && cards.All(card => card.Build == RegionBuild.Current)) {
            var pillWidth = StatusPaint.PillWidth(g, "All up to date", PillFont, Glyph.Check, Dpi);
            StatusPaint.Pill(g, new Rectangle(x, y + (SummaryHeight - pillHeight) / 2, pillWidth, pillHeight), Tone.Good, Glyph.Check, "All up to date", PillFont, Dpi);
            x += pillWidth + Px(6);
        }
        if (coordinator == false) {
            const string text = "Travel coordinator down";
            var pillWidth = StatusPaint.PillWidth(g, text, PillFont, Glyph.Alert, Dpi);
            StatusPaint.Pill(g, new Rectangle(x, y + (SummaryHeight - pillHeight) / 2, pillWidth, pillHeight), Tone.Bad, Glyph.Alert, text, PillFont, Dpi);
            x += pillWidth + Px(6);
        }
        if (checkedText.Length > 0) {
            var size = TextRenderer.MeasureText(g, checkedText, Font, Size.Empty, TextFormatFlags.NoPadding);
            if (width - size.Width - Px(10) > x)
                TextRenderer.DrawText(g, checkedText, Font, new Rectangle(width - size.Width - Px(10), y, size.Width, SummaryHeight), StatusPaint.Muted, OneLine);
        }
        y += SummaryHeight;
        using var line = new Pen(StatusPaint.Line);
        g.DrawLine(line, 0, y - 1, width, y - 1);

        if (message != null) {
            var tone = messageIsError ? Tone.Bad : Tone.Idle;
            using (var back = new SolidBrush(messageIsError ? StatusPaint.ProblemBack : BackColor)) g.FillRectangle(back, 0, y, width, MessageHeight);
            if (messageIsError) StatusPaint.DrawGlyph(g, Glyph.Alert, new RectangleF(Px(12), y + (MessageHeight - Px(10)) / 2f, Px(10), Px(10)), StatusPaint.Fore(tone), StatusPaint.ProblemBack, Dpi);
            TextRenderer.DrawText(g, message, Font, new Rectangle(Px(messageIsError ? 30 : 12), y, width - Px(40), MessageHeight),
                messageIsError ? StatusPaint.Fore(Tone.Bad) : StatusPaint.Muted, OneLine);
            y += MessageHeight;
            g.DrawLine(line, 0, y - 1, width, y - 1);
        }
        if (cards.Count == 0) return;

        // Columns: state, region, players, build, details. The name column fits the longest name.
        var stateX = Px(14);
        var stateWidth = Px(96);
        var nameX = stateX + stateWidth + Px(12);
        var nameWidth = Px(110);
        foreach (var card in cards) {
            var needed = TextRenderer.MeasureText(g, card.Name, Bold, Size.Empty, TextFormatFlags.NoPadding).Width
                + (card.Mainland ? TextRenderer.MeasureText(g, "  mainland", Font, Size.Empty, TextFormatFlags.NoPadding).Width : 0);
            nameWidth = Math.Max(nameWidth, needed + Px(8));
        }
        nameWidth = Math.Min(nameWidth, Math.Max(Px(110), width / 4));
        var playersX = nameX + nameWidth + Px(8);
        var playersWidth = Px(76);
        var buildX = playersX + playersWidth + Px(8);
        var buildWidth = Px(118);
        var notesX = buildX + buildWidth + Px(12);

        void Head(string text, int left, int span) =>
            TextRenderer.DrawText(g, text, Small, new Rectangle(left, y, span, HeaderHeight), StatusPaint.Muted, OneLine);
        Head("STATE", stateX, stateWidth);
        Head("REGION", nameX, nameWidth);
        Head("PLAYERS", playersX, playersWidth);
        Head("BUILD", buildX, buildWidth);
        Head("DETAILS", notesX, Math.Max(0, width - notesX));
        y += HeaderHeight;
        g.DrawLine(line, 0, y - 1, width, y - 1);

        for (var index = 0; index < cards.Count; index++) {
            var card = cards[index];
            var height = RowHeight(card);
            var first = Px(28);
            var chosen = Choosable && card.Id == selected;
            if (y + height >= 0 && y <= ClientSize.Height) {
                var backColor = chosen ? StatusPaint.Selected : card.Problem != null ? StatusPaint.ProblemBack : index == hover && Choosable ? StatusPaint.Hover : BackColor;
                using (var back = new SolidBrush(backColor)) g.FillRectangle(back, 0, y, width, height - 1);
                // The edge colour is the row's worst news: red for a problem, else its state.
                var (runTone, runGlyph) = StatusPaint.For(card.Run);
                using (var edge = new SolidBrush(StatusPaint.Fore(card.Problem != null ? Tone.Bad : runTone))) g.FillRectangle(edge, 0, y, Px(4), height - 1);

                var runWidth = Math.Min(stateWidth, StatusPaint.PillWidth(g, card.RunText, PillFont, runGlyph, Dpi));
                StatusPaint.Pill(g, new Rectangle(stateX, y + (first - pillHeight) / 2, runWidth, pillHeight), runTone, runGlyph, card.RunText, PillFont, Dpi);

                var nameSize = TextRenderer.MeasureText(g, card.Name, Bold, Size.Empty, TextFormatFlags.NoPadding);
                TextRenderer.DrawText(g, card.Name, Bold, new Rectangle(nameX, y, nameWidth, first), StatusPaint.Ink, OneLine);
                if (card.Mainland && nameSize.Width + Px(6) < nameWidth)
                    TextRenderer.DrawText(g, "mainland", Font, new Rectangle(nameX + nameSize.Width + Px(6), y, nameWidth - nameSize.Width - Px(6), first), StatusPaint.Muted, OneLine);

                var players = card.Players switch { null => "", 0 => "empty", 1 => "1 player", { } count => count + " players" };
                TextRenderer.DrawText(g, players, card.Players > 0 ? Bold : Font, new Rectangle(playersX, y, playersWidth, first),
                    card.Players > 0 ? StatusPaint.Ink : StatusPaint.Muted, OneLine);

                var (buildTone, buildGlyph) = StatusPaint.For(card.Build);
                var buildPill = Math.Min(buildWidth, StatusPaint.PillWidth(g, card.BuildText, PillFont, buildGlyph, Dpi));
                StatusPaint.Pill(g, new Rectangle(buildX, y + (first - pillHeight) / 2, buildPill, pillHeight), buildTone, buildGlyph, card.BuildText, PillFont, Dpi);

                var notesLeft = notesX;
                if (card.Activity is { } activity && width > notesLeft) {
                    var size = TextRenderer.MeasureText(g, activity, Bold, Size.Empty, TextFormatFlags.NoPadding);
                    var span = Math.Min(size.Width, width - notesLeft - Px(8));
                    TextRenderer.DrawText(g, activity, Bold, new Rectangle(notesLeft, y, span, first), StatusPaint.Fore(Tone.Busy), OneLine);
                    notesLeft += span + Px(10);
                }
                if (width - notesLeft - Px(8) > Px(20))
                    TextRenderer.DrawText(g, card.Notes, Font, new Rectangle(notesLeft, y, width - notesLeft - Px(8), first), StatusPaint.Muted, OneLine);

                if (card.Problem is { } problem) {
                    var top = y + first - Px(5);
                    StatusPaint.DrawGlyph(g, Glyph.Alert, new RectangleF(nameX, top + Px(5), Px(10), Px(10)), StatusPaint.Fore(Tone.Bad), backColor, Dpi);
                    TextRenderer.DrawText(g, problem, Bold, new Rectangle(nameX + Px(16), top, Math.Max(0, width - nameX - Px(24)), Px(20)), StatusPaint.Fore(Tone.Bad), OneLine);
                }
                if (chosen) {
                    using var edge = new Pen(StatusPaint.SelectedEdge);
                    g.DrawRectangle(edge, Px(4), y, width - Px(4) - 1, height - 2);
                    if (Focused) ControlPaint.DrawFocusRectangle(g, new Rectangle(Px(6), y + 2, width - Px(8) - 1, height - 5));
                }
                g.DrawLine(line, 0, y + height - 1, width, y + height - 1);
            }
            y += height;
        }
    }
}
