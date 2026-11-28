using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// The Host server tab's region board: a summary of counts, then one row per region with its state pill,
// name, players, build pill, local time on the world calendar and notes. A region with a problem gets a red edge and,
// under its row, each problem in full: what is wrong, the next step and a button for every fix, plus Dismiss.
// A problem the host retries by itself is drawn in amber without the red. Three or more regions with the same
// problem get one banner above the rows that fixes or dismisses them together.
// Clicking a row (or Up/Down) chooses that region for the "Selected region" buttons; Enter, Space or the menu key
// opens the row's fixes as a menu.
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
    private readonly ContextMenuStrip menu = new();
    private Font? bold, small, pillFont, underline;

    private DismissedProblems? dismissed;
    private bool showDismissed;
    private IReadOnlySet<string> busyRegions = new HashSet<string>();
    private bool locked, anyBusy;

    // Where everything sits for the current width and cards, in content coordinates (before scrolling).
    private BoardLayout? layout;
    private bool laying;
    // The button under the mouse and the one held down, by id (region, problem index, button), so they
    // survive a relayout from a status poll.
    private string? hoverButton, pressed;

    // False for a single server: there is nothing to choose between.
    public bool Choosable { get; set; } = true;
    public event Action<string>? Chosen;

    // Null: dismissing is not offered.
    public DismissedProblems? Dismissed {
        get => dismissed;
        set { dismissed = value; Relayout(); }
    }

    // A fix button was used: the row's card for a row fix, every affected card for a group banner,
    // and no cards for the board's own fixes (status check, travel coordinator).
    public event Func<IReadOnlyList<RegionCard>, RegionFix, Task>? FixRequested;

    public RegionBoardView() {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw | ControlStyles.Selectable, true);
        BackColor = Color.White;
        menu.Opening += (_, _) => LauncherSkin.Apply(menu);
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
        AccessibleDescription = error ? text + " " + BoardAdvice.MessageStep(text) : text;
        Relayout();
    }

    // Which fixes can run now: busy regions refuse their own actions, a locked board refuses every action,
    // and a fix for all regions waits until none is busy. Opening the log and checking status always work.
    public void SetGates(IReadOnlySet<string> busyRegions, bool locked, bool anyBusy) {
        this.busyRegions = busyRegions;
        this.locked = locked;
        this.anyBusy = anyBusy;
        Invalidate();
    }

    private float Dpi => DeviceDpi / 96f;
    private int Px(float logical) => (int)Math.Round(logical * Dpi);
    private Font Bold => bold ??= new Font(Font, FontStyle.Bold);
    private Font Small => small ??= new Font(Font.FontFamily, 7.5f, FontStyle.Bold);
    private Font PillFont => pillFont ??= new Font(Font.FontFamily, 8.25f, FontStyle.Bold);
    private Font Underline => underline ??= new Font(Font, FontStyle.Underline);

    private void DropFonts() {
        bold?.Dispose(); small?.Dispose(); pillFont?.Dispose(); underline?.Dispose();
        bold = small = pillFont = underline = null;
    }

    protected override void OnFontChanged(EventArgs e) {
        base.OnFontChanged(e);
        DropFonts();
        Relayout();
    }

    protected override void OnDpiChangedAfterParent(EventArgs e) {
        base.OnDpiChangedAfterParent(e);
        DropFonts();
        Relayout();
    }

    protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); Relayout(); }

    protected override void OnResize(EventArgs e) {
        base.OnResize(e);
        if (layout?.Width != ClientSize.Width) Rebuild();
    }

    // Scrolling moves the window's pixels, which would drag the border along with them.
    protected override void OnScroll(ScrollEventArgs se) { base.OnScroll(se); Invalidate(); }
    protected override void OnMouseWheel(MouseEventArgs e) { base.OnMouseWheel(e); Invalidate(); }

    protected override void Dispose(bool disposing) {
        if (disposing) { DropFonts(); tip.Dispose(); ClearMenu(); menu.Dispose(); }
        base.Dispose(disposing);
    }

    // ---- Layout ----

    private enum Act { Fix, Dismiss, Restore, ToggleDismissed }

    // A button to lay out: Name tells it from its neighbours in the id, Tip is its tooltip under the label.
    private sealed record Spec(string Name, string Label, Act Act, string Tip, RegionFix? Fix = null,
        IReadOnlyList<RegionCard>? Targets = null, IReadOnlyList<string>? Keys = null);

    private sealed class Button {
        public string Id = "", Label = "", Tip = "";
        public Rectangle Bounds;
        public Act Act;
        public RegionFix? Fix;
        public IReadOnlyList<RegionCard> Targets = [];
        public IReadOnlyList<string> Keys = [];
        // Link: drawn as blue text in the summary band. Primary: the first fix. Quiet: Dismiss and Restore.
        public bool Link, Primary, Quiet;
        public int Row = -1;
    }

    // One problem (or message) as drawn: its sign, its wrapped text and the "Next:" step under it.
    private sealed class Block {
        public Glyph Glyph;
        public Tone Tone;
        public bool Muted, OneLine;
        public string Text = "";
        public string? Next;
        public Rectangle GlyphBox, TextBox, NextLabel, NextBox;
        public int Bottom;
    }

    private sealed class Banner {
        public int Top, Height;
        public bool Problem;
        public Block Block = new();
    }

    private sealed class Row {
        public int Top, Height, Hidden;
        public bool Error;
        public List<Block> Blocks = [];
    }

    private sealed record PillSpot(Rectangle Bounds, Tone Tone, Glyph Glyph, string Text);

    private sealed class BoardLayout {
        public int Width, Summary, HeaderTop, Total;
        public Rectangle Checked;
        public List<PillSpot> Pills = [];
        public List<Banner> Banners = [];
        public List<Row> Rows = [];
        public List<Button> Buttons = [];
        public int StateX, StateWidth, NameX, NameWidth, PlayersX, PlayersWidth, BuildX, BuildWidth;
        public int ClockX, ClockWidth, TimeX, TimeWidth, SeasonX, SeasonWidth, ZoneX, ZoneWidth, NotesX;
        public bool ShowSeason, ShowZone;
    }

    private const TextFormatFlags OneLine = TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis
        | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix;
    private const TextFormatFlags OneLineTop = TextFormatFlags.Left | TextFormatFlags.Top | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis
        | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix;
    // TextBoxControl breaks a word longer than the line (a path, an error code) instead of clipping it.
    private const TextFormatFlags Wrapped = TextFormatFlags.Left | TextFormatFlags.Top | TextFormatFlags.WordBreak | TextFormatFlags.TextBoxControl
        | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix;
    private const TextFormatFlags Centered = TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis
        | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix;

    private const string DismissTip = "Hides this problem in this launcher only; nothing on the host changes. It shows again if it happens again.";

    private bool IsOff(RegionCard card, RegionProblem problem) => dismissed?.IsDismissed(card, problem) == true;

    // Every problem on the board that is not dismissed, with its card.
    private List<(RegionCard Card, RegionProblem Problem)> ShownProblems() =>
        cards.SelectMany(card => card.Problems.Where(problem => !IsOff(card, problem)).Select(problem => (card, problem))).ToList();

    private void Relayout() {
        layout = null;
        Rebuild();
    }

    // Lays the board out for the client width. A vertical scrollbar that appears (or goes) changes that width,
    // so a second pass lays it out again for what is left.
    private void Rebuild() {
        if (laying || !IsHandleCreated) return;
        laying = true;
        try {
            // A poll every few seconds must not jump the board back to the top.
            var scrolled = -AutoScrollPosition.Y;
            using (var g = CreateGraphics()) {
                for (var pass = 0; pass < 2; pass++) {
                    layout = Build(g, ClientSize.Width);
                    AutoScrollMinSize = new Size(0, layout.Total);
                    if (layout.Width == ClientSize.Width) break;
                }
            }
            if (-AutoScrollPosition.Y != scrolled) AutoScrollPosition = new Point(0, scrolled);
        } finally { laying = false; }
        if (pressed != null && layout?.Buttons.All(button => button.Id != pressed) == true) pressed = null;
        Invalidate();
    }

    private static int LineHeight(Graphics g, Font font) => TextRenderer.MeasureText(g, "Ag", font, Size.Empty, TextFormatFlags.NoPadding).Height;
    private static int TextWidth(Graphics g, string text, Font font) =>
        TextRenderer.MeasureText(g, text, font, Size.Empty, TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix).Width;
    private static int WrappedHeight(Graphics g, string text, Font font, int span) =>
        Math.Max(LineHeight(g, font), TextRenderer.MeasureText(g, text, font, new Size(span, int.MaxValue), Wrapped).Height);

    private BoardLayout Build(Graphics g, int width) {
        var to = new BoardLayout { Width = width };
        var hidden = dismissed?.Hidden(cards) ?? 0;
        if (hidden == 0) showDismissed = false;
        var shown = ShownProblems();

        // Summary band: what needs attention first, then the plain counts, then the links for dismissed problems.
        var line = Px(34);
        var x = Px(10);
        var pillHeight = Px(20);
        void AddPill(Tone tone, Glyph glyph, string text) {
            var pillWidth = StatusPaint.PillWidth(g, text, PillFont, glyph, Dpi);
            to.Pills.Add(new PillSpot(new Rectangle(x, (line - pillHeight) / 2, pillWidth, pillHeight), tone, glyph, text));
            x += pillWidth + Px(6);
        }
        foreach (var count in HostBoard.Summary(cards, dismissed == null ? null : dismissed.Shown)) {
            var (tone, glyph) = StatusPaint.ForCount(count.Kind);
            AddPill(tone, glyph, count.Text);
        }
        if (cards.Count > 0 && cards.All(card => card.Build == RegionBuild.Current)) AddPill(Tone.Good, Glyph.Check, "All up to date");
        if (coordinator == false) AddPill(Tone.Bad, Glyph.Alert, "Travel coordinator down");

        var links = new List<Spec>();
        if (dismissed != null) {
            if (showDismissed) links.Add(new Spec("show", "Hide dismissed", Act.ToggleDismissed, "Hide the dismissed problems again."));
            else if (hidden > 0) links.Add(new Spec("show", $"Show dismissed ({hidden})", Act.ToggleDismissed, "Show the dismissed problems, each with a Restore button."));
            if (shown.Count > 0)
                links.Add(new Spec("all", "Dismiss all", Act.Dismiss, "Hides every problem shown now in this launcher only; nothing on the host changes. A problem that happens again shows again.",
                    Keys: shown.Select(entry => entry.Problem.Key(entry.Card.Id)).ToList()));
        }
        var right = width - Px(10);
        var checkedWidth = checkedText.Length == 0 ? 0 : TextWidth(g, checkedText, Font);
        if (checkedWidth > 0 && right - checkedWidth > x) to.Checked = new Rectangle(right - checkedWidth, 0, checkedWidth, line);
        to.Summary = line;
        if (links.Count > 0) {
            var widths = links.Select(link => TextWidth(g, link.Label, Font) + Px(4)).ToList();
            var all = widths.Sum() + Px(12) * (links.Count - 1);
            var linkRight = to.Checked.IsEmpty ? right : to.Checked.Left - Px(16);
            // Beside the counts when there is room, else on a second line of the band.
            var linkX = linkRight - all;
            var linkY = (line - Px(22)) / 2;
            if (linkX < x + Px(6)) {
                linkX = Px(10);
                linkY = line - Px(5);
                to.Summary = line + Px(21);
            }
            for (var index = 0; index < links.Count; index++) {
                var link = links[index];
                to.Buttons.Add(new Button { Id = "band\n" + link.Name, Label = link.Label, Tip = link.Tip, Act = link.Act, Keys = link.Keys ?? [], Link = true,
                    Bounds = new Rectangle(linkX, linkY, Math.Min(widths[index], Math.Max(0, width - linkX)), Px(22)) });
                linkX += widths[index] + Px(12);
            }
        }
        var y = to.Summary;

        // Banners: the board's own message, the travel coordinator, then each problem that three or more regions share.
        void AddBanner(string owner, Tone tone, Glyph glyph, bool muted, bool red, string text, string? next, IReadOnlyList<Spec> specs) {
            var block = MakeBlock(g, to, owner, -1, glyph == Glyph.None ? Px(12) : Px(30), y + Px(6), width - Px(12), tone, glyph, muted, false, text, next, specs);
            var height = Math.Max(Px(28), block.Bottom - y + Px(7));
            to.Banners.Add(new Banner { Top = y, Height = height, Problem = red, Block = block });
            y += height;
        }
        if (message != null) {
            if (messageIsError)
                AddBanner("message", Tone.Bad, Glyph.Alert, false, true, message, BoardAdvice.MessageStep(message),
                    [new Spec(BoardAdvice.MessageFix.Action, BoardAdvice.MessageFix.Label, Act.Fix, BoardAdvice.MessageStep(message), BoardAdvice.MessageFix)]);
            else AddBanner("message", Tone.Idle, Glyph.None, true, false, message, null, []);
        }
        if (coordinator == false)
            AddBanner("coordinator", Tone.Bad, Glyph.Alert, false, true, "The travel coordinator is not running", BoardAdvice.CoordinatorStep,
                [new Spec(BoardAdvice.CoordinatorFix.Action, BoardAdvice.CoordinatorFix.Label, Act.Fix, BoardAdvice.CoordinatorStep, BoardAdvice.CoordinatorFix)]);

        var grouped = new HashSet<(string Region, string Kind, string Text)>();
        foreach (var group in shown.GroupBy(entry => (entry.Problem.Kind, entry.Problem.Text))) {
            var members = group.DistinctBy(entry => entry.Card.Id).ToList();
            if (members.Count < 3) continue;
            foreach (var entry in group) grouped.Add((entry.Card.Id, entry.Problem.Kind, entry.Problem.Text));
            var first = members[0].Problem;
            var affected = members.Select(entry => entry.Card).ToList();
            var owner = "group\n" + first.Kind + "\n" + first.Text;
            // Only the fixes every one of these regions offers; a host-wide fix keeps its label, which already says "all regions".
            var specs = first.Fixes.Where(fix => members.All(entry => entry.Problem.Fixes.Any(other => other.Action == fix.Action)))
                .Select(fix => new Spec(fix.Action, fix.Group ? fix.Label : $"{fix.Label} (all {members.Count})", Act.Fix, first.NextStep, fix, affected)).ToList();
            if (dismissed != null)
                specs.Add(new Spec("dismiss", $"Dismiss all {members.Count}", Act.Dismiss, DismissTip, Keys: group.Select(entry => entry.Problem.Key(entry.Card.Id)).ToList()));
            var needsYou = first.Severity == ProblemSeverity.NeedsYou;
            AddBanner(owner, needsYou ? Tone.Bad : Tone.Busy, needsYou ? Glyph.Alert : Glyph.Arc, false, needsYou,
                $"{members.Count} regions: {first.Text}", first.NextStep, specs);
        }
        to.HeaderTop = y;
        if (cards.Count == 0) {
            to.Total = y + 1;
            return to;
        }

        // Columns: state, region, players, build, local time, details. The name column fits the longest name.
        to.StateX = Px(14);
        to.StateWidth = Px(96);
        to.NameX = to.StateX + to.StateWidth + Px(12);
        to.NameWidth = Px(110);
        foreach (var card in cards) {
            var needed = TextWidth(g, card.Name, Bold) + (card.Mainland ? TextWidth(g, "  mainland", Font) : 0);
            to.NameWidth = Math.Max(to.NameWidth, needed + Px(8));
        }
        to.NameWidth = Math.Min(to.NameWidth, Math.Max(Px(110), width / 4));
        to.PlayersX = to.NameX + to.NameWidth + Px(8);
        to.PlayersWidth = Px(76);
        to.BuildX = to.PlayersX + to.PlayersWidth + Px(8);
        to.BuildWidth = Px(118);

        // Local time: sun or moon, the clock, then the season and the time zone, each in its own slot so
        // a board of regions reads down like a timetable. It sits after BUILD so the columns an operator
        // acts on stay where they were, and it is absent when no region is on the calendar. DETAILS gives
        // way first; once it would fall under its floor the zone goes, then the season, and the clock
        // itself always stays. The tooltip carries all of it either way.
        to.ClockX = to.BuildX + to.BuildWidth + Px(12);
        to.TimeX = to.ClockX + Px(11) + Px(6);
        foreach (var card in cards) {
            if (card.Clock is not { } clock) continue;
            to.TimeWidth = Math.Max(to.TimeWidth, TextWidth(g, clock.Time, Bold));
            to.SeasonWidth = Math.Max(to.SeasonWidth, TextWidth(g, clock.SeasonText, Font));
            to.ZoneWidth = Math.Max(to.ZoneWidth, TextWidth(g, clock.ZoneText, Font));
        }
        to.ClockWidth = to.TimeWidth == 0 ? 0 : to.TimeX - to.ClockX + to.TimeWidth;
        to.SeasonX = to.ClockX + to.ClockWidth + Px(8);
        var detailsFloor = Px(110);
        to.ShowSeason = to.ClockWidth > 0 && width - (to.SeasonX + to.SeasonWidth + Px(12)) >= detailsFloor;
        if (to.ShowSeason) to.ClockWidth = to.SeasonX + to.SeasonWidth - to.ClockX;
        to.ZoneX = to.ClockX + to.ClockWidth + Px(8);
        to.ShowZone = to.ShowSeason && width - (to.ZoneX + to.ZoneWidth + Px(12)) >= detailsFloor;
        if (to.ShowZone) to.ClockWidth = to.ZoneX + to.ZoneWidth - to.ClockX;
        to.NotesX = to.ClockWidth == 0 ? to.ClockX : to.ClockX + to.ClockWidth + Px(12);
        y += Px(20);

        // Rows: the one line of columns, then each problem under it from the name column across.
        var textX = to.NameX + Px(16);
        for (var index = 0; index < cards.Count; index++) {
            var card = cards[index];
            var row = new Row { Top = y };
            var bottom = y + Px(28);
            for (var number = 0; number < card.Problems.Count; number++) {
                var problem = card.Problems[number];
                var off = IsOff(card, problem);
                if (off && !showDismissed) {
                    row.Hidden++;
                    continue;
                }
                var top = row.Blocks.Count == 0 ? y + Px(24) : bottom + Px(6);
                var owner = card.Id + "\n" + number;
                var needsYou = problem.Severity == ProblemSeverity.NeedsYou;
                var tone = needsYou ? Tone.Bad : Tone.Busy;
                var glyph = needsYou ? Glyph.Alert : Glyph.Arc;
                IReadOnlyList<string> key = [problem.Key(card.Id)];
                Block block;
                if (off)
                    block = MakeBlock(g, to, owner, index, textX, top, width - Px(12), Tone.Idle, Glyph.Dash, true, false, "Dismissed: " + problem.Text, null,
                        [new Spec("restore", "Restore", Act.Restore, "Show this problem again.", Keys: key)]);
                else if (grouped.Contains((card.Id, problem.Kind, problem.Text)))
                    // The banner above carries the next step and the buttons for all of them.
                    block = MakeBlock(g, to, owner, index, textX, top, width - Px(12), tone, glyph, false, true, problem.Text, null, []);
                else {
                    var specs = problem.Fixes.Select(fix => new Spec(fix.Action, fix.Label, Act.Fix, problem.NextStep, fix, [card])).ToList();
                    if (dismissed != null) specs.Add(new Spec("dismiss", "Dismiss", Act.Dismiss, DismissTip, Keys: key));
                    block = MakeBlock(g, to, owner, index, textX, top, width - Px(12), tone, glyph, false, false, problem.Text, problem.NextStep, specs);
                }
                if (!off && needsYou) row.Error = true;
                row.Blocks.Add(block);
                bottom = block.Bottom;
            }
            row.Height = row.Blocks.Count == 0 ? Px(28) : bottom - y + Px(7);
            to.Rows.Add(row);
            y += row.Height;
        }
        to.Total = y + 1;
        return to;
    }

    // Lays out one problem from top down: the text (wrapped, or one ellipsised line), "Next:" with the step hanging
    // beside it, then the buttons on their own line, wrapping to further lines when they do not fit.
    private Block MakeBlock(Graphics g, BoardLayout to, string owner, int row, int textX, int top, int right, Tone tone, Glyph glyph, bool muted, bool oneLine,
            string text, string? next, IReadOnlyList<Spec> specs) {
        var line = LineHeight(g, Bold);
        var span = Math.Max(Px(60), right - textX);
        var block = new Block { Glyph = glyph, Tone = tone, Muted = muted, OneLine = oneLine, Text = text, Next = next };
        block.GlyphBox = new Rectangle(textX - Px(16), top + (line - Px(10)) / 2, Px(10), Px(10));
        var height = oneLine ? line : WrappedHeight(g, text, Bold, span);
        block.TextBox = new Rectangle(textX, top, span, height);
        var y = top + height;
        if (next != null) {
            y += Px(2);
            var label = TextWidth(g, "Next:", Bold);
            var nextSpan = Math.Max(Px(40), span - label - Px(5));
            var nextHeight = WrappedHeight(g, next, Font, nextSpan);
            block.NextLabel = new Rectangle(textX, y, label, line);
            block.NextBox = new Rectangle(textX + label + Px(5), y, nextSpan, nextHeight);
            y += nextHeight;
        }
        if (specs.Count > 0) {
            y += Px(5);
            var x = textX;
            var buttonHeight = Px(22);
            var primary = specs.FirstOrDefault(spec => spec.Act == Act.Fix);
            foreach (var spec in specs) {
                var buttonWidth = Math.Min(span, TextWidth(g, spec.Label, Font) + Px(18));
                if (x > textX && x + buttonWidth > textX + span) {
                    x = textX;
                    y += buttonHeight + Px(4);
                }
                to.Buttons.Add(new Button { Id = owner + "\n" + spec.Name, Label = spec.Label, Tip = spec.Tip, Act = spec.Act, Fix = spec.Fix,
                    Targets = spec.Targets ?? [], Keys = spec.Keys ?? [], Primary = spec == primary, Quiet = spec.Act != Act.Fix, Row = row,
                    Bounds = new Rectangle(x, y, buttonWidth, buttonHeight) });
                x += buttonWidth + Px(6);
            }
            y += buttonHeight;
        }
        block.Bottom = y;
        return block;
    }

    // ---- Gates and actions ----

    private bool FixEnabled(RegionFix fix, IReadOnlyList<RegionCard> targets) {
        if (fix.Action is RegionFix.OpenLog or RegionFix.CheckStatus) return true;
        if (fix.Group || fix.Action == RegionFix.RestartHost) return !anyBusy && !locked;
        return !locked && targets.All(card => !busyRegions.Contains(card.Id));
    }

    private bool Usable(Button button) => button.Act != Act.Fix || (button.Fix != null && FixEnabled(button.Fix, button.Targets));

    private void Run(Act act, RegionFix? fix, IReadOnlyList<RegionCard> targets, IReadOnlyList<string> keys, int row) {
        switch (act) {
            case Act.Fix:
                if (fix == null || !FixEnabled(fix, targets)) return;
                // As clicking the row does, so the "Selected region" buttons follow what was just acted on.
                if (row >= 0 && row < cards.Count) Choose(row);
                _ = FixRequested?.Invoke(targets, fix);
                break;
            case Act.Dismiss:
                dismissed?.Dismiss(keys);
                Relayout();
                break;
            case Act.Restore:
                dismissed?.Restore(keys);
                Relayout();
                break;
            case Act.ToggleDismissed:
                showDismissed = !showDismissed;
                Relayout();
                break;
        }
    }

    private void Choose(int row) {
        if (!Choosable || cards[row].Id == selected) return;
        selected = cards[row].Id;
        Invalidate();
        Chosen?.Invoke(selected);
    }

    // ---- Mouse ----

    private Point Content(Point point) => new(point.X, point.Y - AutoScrollPosition.Y);

    private int RowAt(Point point) {
        if (layout is not { } at) return -1;
        var y = point.Y - AutoScrollPosition.Y;
        for (var index = 0; index < at.Rows.Count && index < cards.Count; index++)
            if (y >= at.Rows[index].Top && y < at.Rows[index].Top + at.Rows[index].Height) return index;
        return -1;
    }

    private Button? ButtonAt(Point point) {
        var spot = Content(point);
        return layout?.Buttons.FirstOrDefault(button => button.Bounds.Contains(spot));
    }

    private string TipFor(Button button) {
        if (button.Act != Act.Fix) return WrapTip(button.Tip);
        var waiting = Usable(button) ? "" : " - not available while another action is running";
        return WrapTip(button.Label + waiting + (button.Tip.Length > 0 ? "\n" + button.Tip : ""));
    }

    // A tooltip does not wrap by itself, and a next step is a few sentences long.
    private static string WrapTip(string text) {
        var lines = new List<string>();
        foreach (var paragraph in text.Split('\n')) {
            var current = "";
            foreach (var word in paragraph.Split(' ', StringSplitOptions.RemoveEmptyEntries)) {
                if (current.Length > 0 && current.Length + 1 + word.Length > 76) {
                    lines.Add(current);
                    current = word;
                } else current = current.Length == 0 ? word : current + " " + word;
            }
            lines.Add(current);
        }
        return string.Join("\n", lines);
    }

    protected override void OnMouseMove(MouseEventArgs e) {
        base.OnMouseMove(e);
        var row = RowAt(e.Location);
        var button = ButtonAt(e.Location);
        var usable = button != null && Usable(button);
        var cursor = usable ? Cursors.Hand : Cursors.Default;
        if (Cursor != cursor) Cursor = cursor;
        var text = button != null ? TipFor(button) : row >= 0 ? WrapTip(cards[row].Describe()) : "";
        if (text != tipText) tip.SetToolTip(this, tipText = text);
        if (row == hover && button?.Id == hoverButton) return;
        hover = row;
        hoverButton = button?.Id;
        Invalidate();
    }

    protected override void OnMouseLeave(EventArgs e) {
        base.OnMouseLeave(e);
        if (hover == -1 && hoverButton == null) return;
        hover = -1;
        hoverButton = null;
        Invalidate();
    }

    protected override void OnMouseDown(MouseEventArgs e) {
        base.OnMouseDown(e);
        Focus();
        if (ButtonAt(e.Location) is { } button) {
            // A button fires on release inside it, so a press can still be dragged off; a disabled one does nothing.
            if (e.Button == MouseButtons.Left && Usable(button)) {
                pressed = hoverButton = button.Id;
                Invalidate();
            }
            if (e.Button == MouseButtons.Left) return;
        }
        if (RowAt(e.Location) is >= 0 and var row) Choose(row);
    }

    protected override void OnMouseUp(MouseEventArgs e) {
        base.OnMouseUp(e);
        if (e.Button != MouseButtons.Left || pressed == null) return;
        var id = pressed;
        pressed = null;
        Invalidate();
        if (ButtonAt(e.Location) is { } button && button.Id == id && Usable(button)) Run(button.Act, button.Fix, button.Targets, button.Keys, button.Row);
    }

    // ---- Keyboard and the row menu ----

    // Enter would otherwise go to the form's default button; Escape is only taken while a button is held.
    protected override bool IsInputKey(Keys keyData) =>
        keyData is Keys.Up or Keys.Down or Keys.Enter || (keyData == Keys.Escape && pressed != null) || base.IsInputKey(keyData);

    protected override void OnKeyDown(KeyEventArgs e) {
        base.OnKeyDown(e);
        if (e.KeyCode == Keys.Escape && pressed != null) {
            pressed = null;
            Invalidate();
            e.Handled = true;
            return;
        }
        if (e.KeyCode is Keys.Enter or Keys.Space && !e.Alt && !e.Control) {
            OpenMenu(null);
            e.Handled = e.SuppressKeyPress = true;
            return;
        }
        if (!Choosable || cards.Count == 0 || e.KeyCode is not (Keys.Up or Keys.Down)) return;
        var index = cards.ToList().FindIndex(card => card.Id == selected);
        var next = Math.Clamp(index + (e.KeyCode == Keys.Down ? 1 : -1), 0, cards.Count - 1);
        Choose(next);
        ScrollIntoView(next);
        e.Handled = true;
    }

    protected override void OnGotFocus(EventArgs e) { base.OnGotFocus(e); Invalidate(); }
    protected override void OnLostFocus(EventArgs e) { base.OnLostFocus(e); pressed = null; Invalidate(); }

    // Rows are as tall as their problems now, so the chosen one can be off screen.
    private void ScrollIntoView(int index) {
        if (layout is not { } at || index < 0 || index >= at.Rows.Count) return;
        var row = at.Rows[index];
        var view = -AutoScrollPosition.Y;
        if (row.Top < view) AutoScrollPosition = new Point(0, row.Top);
        else if (row.Top + row.Height > view + ClientSize.Height) AutoScrollPosition = new Point(0, Math.Min(row.Top, row.Top + row.Height - ClientSize.Height));
        else return;
        Invalidate();
    }

    // The menu key, Shift+F10 and a right click all arrive as this one message; -1 means it came from the keyboard.
    protected override void WndProc(ref Message m) {
        const int ContextMenuMessage = 0x007B;
        if (m.Msg == ContextMenuMessage) {
            var where = m.LParam.ToInt64();
            if ((where & 0xFFFFFFFF) == 0xFFFFFFFF) OpenMenu(null);
            else OpenMenu(PointToClient(new Point((short)(where & 0xFFFF), (short)((where >> 16) & 0xFFFF))));
            return;
        }
        base.WndProc(ref m);
    }

    private void ClearMenu() {
        var old = menu.Items.Cast<ToolStripItem>().ToList();
        menu.Items.Clear();
        foreach (var item in old) item.Dispose();
    }

    private static string MenuText(string text) => text.Replace("&", "&&");
    private static string Clip(string text) => text.Length > 60 ? text[..60].TrimEnd() + "..." : text;

    // Everything the buttons do, for the keyboard: the chosen row's fixes and dismissals, then the board's own.
    // at: where the mouse asked for it, or null from the keyboard (it opens at the chosen row).
    private void OpenMenu(Point? at) {
        if (layout is not { } current) return;
        int row;
        Point where;
        if (at is { } point) {
            row = RowAt(point);
            where = point;
        } else {
            row = Choosable ? cards.ToList().FindIndex(card => card.Id == selected) : cards.Count == 1 ? 0 : -1;
            if (row >= current.Rows.Count) row = -1;
            ScrollIntoView(row);
            where = row >= 0 ? new Point(current.NameX, Math.Clamp(current.Rows[row].Top + AutoScrollPosition.Y + Px(24), 0, Math.Max(0, ClientSize.Height - 1)))
                : new Point(Px(10), Px(10));
        }
        ClearMenu();
        void Add(string text, bool enabled, Action run) {
            var item = new ToolStripMenuItem(MenuText(text)) { Enabled = enabled };
            item.Click += (_, _) => run();
            menu.Items.Add(item);
        }
        var offered = new HashSet<string>();
        var card = row >= 0 && row < cards.Count ? cards[row] : null;
        if (card != null) {
            IReadOnlyList<RegionCard> target = [card];
            foreach (var problem in card.Problems.Where(problem => !IsOff(card, problem)))
                foreach (var fix in problem.Fixes)
                    if (offered.Add(fix.Action)) Add("Fix: " + fix.Label, FixEnabled(fix, target), () => Run(Act.Fix, fix, target, [], row));
        }
        if (message != null && messageIsError && offered.Add(BoardAdvice.MessageFix.Action))
            Add("Fix: " + BoardAdvice.MessageFix.Label, true, () => Run(Act.Fix, BoardAdvice.MessageFix, [], [], -1));
        if (coordinator == false && offered.Add(BoardAdvice.CoordinatorFix.Action))
            Add("Fix: " + BoardAdvice.CoordinatorFix.Label, FixEnabled(BoardAdvice.CoordinatorFix, []), () => Run(Act.Fix, BoardAdvice.CoordinatorFix, [], [], -1));
        if (dismissed != null) {
            if (menu.Items.Count > 0) menu.Items.Add(new ToolStripSeparator());
            if (card != null)
                foreach (var problem in card.Problems) {
                    IReadOnlyList<string> key = [problem.Key(card.Id)];
                    if (!IsOff(card, problem)) Add("Dismiss: " + Clip(problem.Text), true, () => Run(Act.Dismiss, null, [], key, -1));
                    else if (showDismissed) Add("Restore: " + Clip(problem.Text), true, () => Run(Act.Restore, null, [], key, -1));
                }
            var all = ShownProblems().Select(entry => entry.Problem.Key(entry.Card.Id)).ToList();
            if (all.Count > 0) Add("Dismiss all", true, () => Run(Act.Dismiss, null, [], all, -1));
            var hidden = dismissed.Hidden(cards);
            if (showDismissed) Add("Hide dismissed", true, () => Run(Act.ToggleDismissed, null, [], [], -1));
            else if (hidden > 0) Add($"Show dismissed ({hidden})", true, () => Run(Act.ToggleDismissed, null, [], [], -1));
            if (menu.Items.Count > 0 && menu.Items[^1] is ToolStripSeparator last) {
                menu.Items.Remove(last);
                last.Dispose();
            }
        }
        if (menu.Items.Count > 0) menu.Show(this, where);
    }

    // ---- Painting ----

    protected override void OnPaint(PaintEventArgs e) {
        PaintBoard(e.Graphics);
        using var border = new Pen(StatusPaint.Line);
        e.Graphics.DrawRectangle(border, 0, 0, ClientSize.Width - 1, ClientSize.Height - 1);
    }

    private static Rectangle Moved(Rectangle box, int dy) => new(box.X, box.Y + dy, box.Width, box.Height);

    private void PaintBoard(Graphics g) {
        g.Clear(BackColor);
        if (layout == null) Rebuild();
        if (layout is not { } at) return;
        var width = ClientSize.Width;
        var dy = AutoScrollPosition.Y;
        var pillHeight = Px(20);
        using var line = new Pen(StatusPaint.Line);

        // Summary band: what needs attention first, then the plain counts.
        using (var band = new SolidBrush(StatusPaint.Band)) g.FillRectangle(band, 0, dy, width, at.Summary);
        foreach (var pill in at.Pills) StatusPaint.Pill(g, Moved(pill.Bounds, dy), pill.Tone, pill.Glyph, pill.Text, PillFont, Dpi);
        if (!at.Checked.IsEmpty) TextRenderer.DrawText(g, checkedText, Font, Moved(at.Checked, dy), StatusPaint.Muted, OneLine);
        g.DrawLine(line, 0, dy + at.Summary - 1, width, dy + at.Summary - 1);

        foreach (var banner in at.Banners) {
            var color = banner.Problem ? StatusPaint.ProblemBack : BackColor;
            using (var back = new SolidBrush(color)) g.FillRectangle(back, 0, dy + banner.Top, width, banner.Height - 1);
            PaintBlock(g, banner.Block, dy, color);
            g.DrawLine(line, 0, dy + banner.Top + banner.Height - 1, width, dy + banner.Top + banner.Height - 1);
        }

        if (cards.Count > 0 && at.Rows.Count == cards.Count) {
            var y = dy + at.HeaderTop;
            var headerHeight = Px(20);
            void Head(string text, int left, int span) =>
                TextRenderer.DrawText(g, text, Small, new Rectangle(left, y, span, headerHeight), StatusPaint.Muted, OneLine);
            Head("STATE", at.StateX, at.StateWidth);
            Head("REGION", at.NameX, at.NameWidth);
            Head("PLAYERS", at.PlayersX, at.PlayersWidth);
            Head("BUILD", at.BuildX, at.BuildWidth);
            if (at.ClockWidth > 0) Head(at.ShowSeason ? "LOCAL TIME" : "LOCAL", at.ClockX, at.ClockWidth);
            Head("DETAILS", at.NotesX, Math.Max(0, width - at.NotesX));
            g.DrawLine(line, 0, y + headerHeight - 1, width, y + headerHeight - 1);

            var sunSize = Px(11);
            var now = DateTimeOffset.UtcNow;
            for (var index = 0; index < cards.Count; index++) {
                var card = cards[index];
                var row = at.Rows[index];
                y = dy + row.Top;
                var height = row.Height;
                if (y + height < 0 || y > ClientSize.Height) continue;
                var first = Px(28);
                var chosen = Choosable && card.Id == selected;
                // Only a problem that needs the operator turns the row red; one the host retries by itself stays quiet.
                var backColor = chosen ? StatusPaint.Selected : row.Error ? StatusPaint.ProblemBack : index == hover && Choosable ? StatusPaint.Hover : BackColor;
                using (var back = new SolidBrush(backColor)) g.FillRectangle(back, 0, y, width, height - 1);
                // The edge colour is the row's worst news: red for a problem, else its state.
                var (runTone, runGlyph) = StatusPaint.For(card.Run);
                using (var edge = new SolidBrush(StatusPaint.Fore(row.Error ? Tone.Bad : runTone))) g.FillRectangle(edge, 0, y, Px(4), height - 1);

                var runWidth = Math.Min(at.StateWidth, StatusPaint.PillWidth(g, card.RunText, PillFont, runGlyph, Dpi));
                StatusPaint.Pill(g, new Rectangle(at.StateX, y + (first - pillHeight) / 2, runWidth, pillHeight), runTone, runGlyph, card.RunText, PillFont, Dpi);

                var nameSize = TextRenderer.MeasureText(g, card.Name, Bold, Size.Empty, TextFormatFlags.NoPadding);
                TextRenderer.DrawText(g, card.Name, Bold, new Rectangle(at.NameX, y, at.NameWidth, first), StatusPaint.Ink, OneLine);
                if (card.Mainland && nameSize.Width + Px(6) < at.NameWidth)
                    TextRenderer.DrawText(g, "mainland", Font, new Rectangle(at.NameX + nameSize.Width + Px(6), y, at.NameWidth - nameSize.Width - Px(6), first), StatusPaint.Muted, OneLine);

                var players = card.Players switch { null => "", 0 => "empty", 1 => "1 player", { } count => count + " players" };
                TextRenderer.DrawText(g, players, card.Players > 0 ? Bold : Font, new Rectangle(at.PlayersX, y, at.PlayersWidth, first),
                    card.Players > 0 ? StatusPaint.Ink : StatusPaint.Muted, OneLine);

                var (buildTone, buildGlyph) = StatusPaint.For(card.Build);
                var buildPill = Math.Min(at.BuildWidth, StatusPaint.PillWidth(g, card.BuildText, PillFont, buildGlyph, Dpi));
                StatusPaint.Pill(g, new Rectangle(at.BuildX, y + (first - pillHeight) / 2, buildPill, pillHeight), buildTone, buildGlyph, card.BuildText, PillFont, Dpi);

                // A region off the calendar leaves its slot empty: a dash would put a mark on every such row for no news.
                if (at.ClockWidth > 0 && card.Clock is { } clock) {
                    StatusPaint.DrawGlyph(g, clock.Daylight ? Glyph.Sun : Glyph.Moon, new RectangleF(at.ClockX, y + (first - sunSize) / 2f, sunSize, sunSize),
                        clock.Daylight ? StatusPaint.Day : StatusPaint.Night, backColor, Dpi);
                    TextRenderer.DrawText(g, clock.Time, Bold, new Rectangle(at.TimeX, y, at.TimeWidth, first), StatusPaint.Ink, OneLine);
                    if (at.ShowSeason) TextRenderer.DrawText(g, clock.SeasonText, Font, new Rectangle(at.SeasonX, y, at.SeasonWidth, first), StatusPaint.Muted, OneLine);
                    if (at.ShowZone) TextRenderer.DrawText(g, clock.ZoneText, Font, new Rectangle(at.ZoneX, y, at.ZoneWidth, first), StatusPaint.Muted, OneLine);
                }

                var notesLeft = at.NotesX;
                if (card.Activity is { } activity && width > notesLeft) {
                    var size = TextRenderer.MeasureText(g, activity, Bold, Size.Empty, TextFormatFlags.NoPadding);
                    var span = Math.Min(size.Width, width - notesLeft - Px(8));
                    TextRenderer.DrawText(g, activity, Bold, new Rectangle(notesLeft, y, span, first), StatusPaint.Fore(Tone.Busy), OneLine);
                    notesLeft += span + Px(10);
                }
                // Dismissed problems leave a quiet count first, where the ellipsis cannot take it.
                var details = card.Revision is { } revision
                    ? revision.Describe(now) + (card.Notes.Length > 0 ? ", " + card.Notes : "")
                    : card.Notes;
                var notes = row.Hidden == 0 ? details : row.Hidden + " dismissed" + (details.Length > 0 ? ", " + details : "");
                if (width - notesLeft - Px(8) > Px(20))
                    TextRenderer.DrawText(g, notes, Font, new Rectangle(notesLeft, y, width - notesLeft - Px(8), first), StatusPaint.Muted, OneLine);

                foreach (var block in row.Blocks) PaintBlock(g, block, dy, backColor);
                if (chosen) {
                    using var edge = new Pen(StatusPaint.SelectedEdge);
                    g.DrawRectangle(edge, Px(4), y, width - Px(4) - 1, height - 2);
                    if (Focused) ControlPaint.DrawFocusRectangle(g, new Rectangle(Px(6), y + 2, width - Px(8) - 1, height - 5));
                }
                g.DrawLine(line, 0, y + height - 1, width, y + height - 1);
            }
        }

        foreach (var button in at.Buttons) {
            var bounds = Moved(button.Bounds, dy);
            if (bounds.Bottom >= 0 && bounds.Top <= ClientSize.Height) PaintButton(g, button, bounds);
        }
    }

    private void PaintBlock(Graphics g, Block block, int dy, Color back) {
        var color = block.Muted ? StatusPaint.Muted : StatusPaint.Fore(block.Tone);
        if (block.Glyph != Glyph.None) StatusPaint.DrawGlyph(g, block.Glyph, Moved(block.GlyphBox, dy), color, back, Dpi);
        TextRenderer.DrawText(g, block.Text, block.Glyph == Glyph.None ? Font : Bold, Moved(block.TextBox, dy), color, block.OneLine ? OneLineTop : Wrapped);
        if (block.Next == null) return;
        TextRenderer.DrawText(g, "Next:", Bold, Moved(block.NextLabel, dy), StatusPaint.Ink, OneLineTop);
        TextRenderer.DrawText(g, block.Next, Font, Moved(block.NextBox, dy), StatusPaint.Ink, Wrapped);
    }

    private void PaintButton(Graphics g, Button button, Rectangle bounds) {
        var enabled = Usable(button);
        var hot = enabled && hoverButton == button.Id;
        var down = hot && pressed == button.Id;
        if (button.Link) {
            TextRenderer.DrawText(g, button.Label, hot ? Underline : Font, bounds, down ? StatusPaint.Ink : StatusPaint.Fore(Tone.Info), Centered);
            return;
        }
        var fill = !enabled ? StatusPaint.Band : down ? StatusPaint.Selected : hot ? StatusPaint.Hover : BackColor;
        var edge = !enabled ? StatusPaint.Line : down || button.Primary ? StatusPaint.SelectedEdge : StatusPaint.ButtonEdge;
        var ink = !enabled ? StatusPaint.Disabled : button.Quiet ? StatusPaint.Muted : button.Primary ? StatusPaint.Fore(Tone.Info) : StatusPaint.Ink;
        var smoothing = g.SmoothingMode;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        using (var path = StatusPaint.Rounded(new RectangleF(bounds.X + 0.5f, bounds.Y + 0.5f, bounds.Width - 1, bounds.Height - 1), 4 * Dpi))
        using (var brush = new SolidBrush(fill))
        using (var pen = new Pen(edge)) {
            g.FillPath(brush, path);
            g.DrawPath(pen, path);
        }
        g.SmoothingMode = smoothing;
        TextRenderer.DrawText(g, button.Label, Font, Rectangle.Inflate(bounds, -Px(4), 0), ink, Centered);
    }

    // ---- Screen readers ----

    protected override AccessibleObject CreateAccessibilityInstance() => new BoardAccessible(this);

    // The board as a list with one item per region.
    private sealed class BoardAccessible(RegionBoardView owner) : ControlAccessibleObject(owner) {
        public override int GetChildCount() => owner.cards.Count;
        public override AccessibleObject? GetChild(int index) => index >= 0 && index < owner.cards.Count ? new RowAccessible(owner, this, index) : null;
        public override AccessibleObject? HitTest(int x, int y) =>
            owner.RowAt(owner.PointToClient(new Point(x, y))) is >= 0 and var row ? GetChild(row) : base.HitTest(x, y);
        public override AccessibleObject? GetSelected() => owner.Choosable ? GetChild(owner.cards.ToList().FindIndex(card => card.Id == owner.selected)) : null;
        public override AccessibleObject? GetFocused() => owner.Focused ? GetSelected() : null;
    }

    // A region row: its one-line description, then each problem's next step. Its default action is its first fix.
    private sealed class RowAccessible(RegionBoardView owner, AccessibleObject parent, int index) : AccessibleObject {
        private RegionCard? Card => index < owner.cards.Count ? owner.cards[index] : null;

        private (RegionProblem Problem, RegionFix Fix)? FirstFix() {
            if (Card is not { } card) return null;
            foreach (var problem in card.Problems.Where(problem => !owner.IsOff(card, problem)))
                if (problem.Fixes.Count > 0) return (problem, problem.Fixes[0]);
            return null;
        }

        public override string? Name {
            get {
                if (Card is not { } card) return null;
                var steps = card.Problems.Where(problem => !owner.IsOff(card, problem)).Select(problem => "Next: " + problem.NextStep);
                return string.Join(" ", new[] { card.Describe() }.Concat(steps));
            }
        }

        public override AccessibleRole Role => AccessibleRole.ListItem;
        public override AccessibleObject Parent => parent;
        public override string? DefaultAction => FirstFix()?.Fix.Label;

        public override Rectangle Bounds {
            get {
                if (owner.layout is not { } at || index >= at.Rows.Count) return Rectangle.Empty;
                var row = at.Rows[index];
                return owner.RectangleToScreen(new Rectangle(0, row.Top + owner.AutoScrollPosition.Y, owner.ClientSize.Width, row.Height));
            }
        }

        public override AccessibleStates State {
            get {
                var state = AccessibleStates.Focusable;
                if (!owner.Choosable) return state;
                state |= AccessibleStates.Selectable;
                if (Card?.Id == owner.selected) state |= AccessibleStates.Selected | (owner.Focused ? AccessibleStates.Focused : AccessibleStates.None);
                return state;
            }
        }

        public override void Select(AccessibleSelection flags) {
            if (Card != null) owner.Choose(index);
        }

        public override void DoDefaultAction() {
            if (Card is not { } card) return;
            if (FirstFix() is { } first) owner.Run(Act.Fix, first.Fix, [card], [], index);
            else owner.Choose(index);
        }
    }
}
