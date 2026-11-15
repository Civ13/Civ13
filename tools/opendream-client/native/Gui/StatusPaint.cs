using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// One small palette for every status the launcher shows, so the same colour always means the same thing:
// green is fine, blue is resting or ready, grey is off, amber is in progress or needs an update, red needs you.
// Every pill also carries a shape and a word, so nothing depends on colour alone.
internal enum Tone { Good, Info, Idle, Busy, Bad }
internal enum Glyph { None, Dot, Ring, Moon, Arc, Alert, Check, Down, Box, Dash, Person }

internal static class StatusPaint {
    public static readonly Color Ink = Color.FromArgb(28, 33, 40);
    public static readonly Color Muted = Color.FromArgb(96, 105, 118);
    public static readonly Color Line = Color.FromArgb(222, 226, 232);
    public static readonly Color Band = Color.FromArgb(246, 247, 249);
    public static readonly Color Selected = Color.FromArgb(226, 238, 255);
    public static readonly Color SelectedEdge = Color.FromArgb(64, 120, 216);
    public static readonly Color Hover = Color.FromArgb(243, 246, 250);
    public static readonly Color ProblemBack = Color.FromArgb(255, 245, 244);

    public static Color Fore(Tone tone) => tone switch {
        Tone.Good => Color.FromArgb(22, 101, 46),
        Tone.Info => Color.FromArgb(29, 78, 160),
        Tone.Busy => Color.FromArgb(133, 77, 0),
        Tone.Bad => Color.FromArgb(170, 32, 24),
        _ => Color.FromArgb(75, 85, 99),
    };

    public static Color Back(Tone tone) => tone switch {
        Tone.Good => Color.FromArgb(220, 243, 225),
        Tone.Info => Color.FromArgb(222, 233, 251),
        Tone.Busy => Color.FromArgb(255, 238, 190),
        Tone.Bad => Color.FromArgb(252, 221, 218),
        _ => Color.FromArgb(232, 234, 238),
    };

    public static (Tone, Glyph) For(RegionRun run) => run switch {
        RegionRun.Running => (Tone.Good, Glyph.Dot),
        RegionRun.Asleep => (Tone.Info, Glyph.Moon),
        RegionRun.Working => (Tone.Busy, Glyph.Arc),
        RegionRun.Stopped => (Tone.Idle, Glyph.Ring),
        _ => (Tone.Bad, Glyph.Alert),
    };

    public static (Tone, Glyph) For(RegionBuild build) => build switch {
        RegionBuild.Current => (Tone.Good, Glyph.Check),
        RegionBuild.Behind => (Tone.Busy, Glyph.Down),
        RegionBuild.Built => (Tone.Info, Glyph.Box),
        RegionBuild.Building => (Tone.Busy, Glyph.Arc),
        RegionBuild.Failed => (Tone.Bad, Glyph.Alert),
        _ => (Tone.Idle, Glyph.Dash),
    };

    public static (Tone, Glyph) ForCount(string kind) => kind switch {
        "problem" or "unknown" => (Tone.Bad, Glyph.Alert),
        "working" => (Tone.Busy, Glyph.Arc),
        "behind" => (Tone.Busy, Glyph.Down),
        "running" => (Tone.Good, Glyph.Dot),
        "asleep" => (Tone.Info, Glyph.Moon),
        "players" => (Tone.Idle, Glyph.Person),
        _ => (Tone.Idle, Glyph.Ring),
    };

    public static GraphicsPath Rounded(RectangleF bounds, float radius) {
        var path = new GraphicsPath();
        var d = Math.Min(radius * 2, Math.Min(bounds.Width, bounds.Height));
        path.AddArc(bounds.X, bounds.Y, d, d, 180, 90);
        path.AddArc(bounds.Right - d, bounds.Y, d, d, 270, 90);
        path.AddArc(bounds.Right - d, bounds.Bottom - d, d, d, 0, 90);
        path.AddArc(bounds.X, bounds.Bottom - d, d, d, 90, 90);
        path.CloseFigure();
        return path;
    }

    // The width a pill needs for its text, glyph and padding.
    public static int PillWidth(Graphics g, string text, Font font, Glyph glyph, float scale) {
        var width = TextRenderer.MeasureText(g, text, font, Size.Empty, TextFormatFlags.NoPadding | TextFormatFlags.SingleLine).Width;
        return (int)Math.Ceiling(width + (glyph == Glyph.None ? 16 : 31) * scale);
    }

    // A rounded, filled label: glyph, then text, both in the tone's dark colour on its light one.
    public static void Pill(Graphics g, Rectangle bounds, Tone tone, Glyph glyph, string text, Font font, float scale) {
        var old = g.SmoothingMode;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        using (var path = Rounded(bounds, bounds.Height / 2f))
        using (var fill = new SolidBrush(Back(tone)))
            g.FillPath(fill, path);
        var textLeft = bounds.Left + (int)(8 * scale);
        if (glyph != Glyph.None) {
            var size = 9 * scale;
            DrawGlyph(g, glyph, new RectangleF(bounds.Left + 8 * scale, bounds.Top + (bounds.Height - size) / 2f, size, size), Fore(tone), Back(tone), scale);
            textLeft = bounds.Left + (int)(22 * scale);
        }
        g.SmoothingMode = old;
        TextRenderer.DrawText(g, text, font, new Rectangle(textLeft, bounds.Top, bounds.Right - textLeft - (int)(6 * scale), bounds.Height), Fore(tone),
            TextFormatFlags.Left | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding | TextFormatFlags.NoPrefix);
    }

    public static void DrawGlyph(Graphics g, Glyph glyph, RectangleF box, Color color, Color back, float scale) {
        var smoothing = g.SmoothingMode;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        try { Shape(g, glyph, box, color, back, scale); }
        finally { g.SmoothingMode = smoothing; }
    }

    private static void Shape(Graphics g, Glyph glyph, RectangleF box, Color color, Color back, float scale) {
        using var brush = new SolidBrush(color);
        using var pen = new Pen(color, 1.7f * scale) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
        var inset = RectangleF.Inflate(box, -0.9f * scale, -0.9f * scale);
        switch (glyph) {
            case Glyph.Dot:
                g.FillEllipse(brush, box);
                break;
            case Glyph.Ring:
                g.DrawEllipse(pen, inset);
                break;
            case Glyph.Moon: {
                g.FillEllipse(brush, box);
                using var cut = new SolidBrush(back);
                g.FillEllipse(cut, box.X + box.Width * 0.38f, box.Y - box.Height * 0.12f, box.Width * 0.82f, box.Height * 0.82f);
                break;
            }
            case Glyph.Arc:
                g.DrawArc(pen, inset, -60, 270);
                break;
            case Glyph.Alert:
                g.FillPolygon(brush, [new PointF(box.X + box.Width / 2f, box.Y - 0.5f * scale), new PointF(box.Right + 0.5f * scale, box.Bottom),
                    new PointF(box.X - 0.5f * scale, box.Bottom)]);
                using (var mark = new Pen(back, 1.4f * scale)) {
                    g.DrawLine(mark, box.X + box.Width / 2f, box.Y + box.Height * 0.38f, box.X + box.Width / 2f, box.Y + box.Height * 0.66f);
                    g.DrawLine(mark, box.X + box.Width / 2f, box.Y + box.Height * 0.84f, box.X + box.Width / 2f, box.Y + box.Height * 0.86f);
                }
                break;
            case Glyph.Check:
                g.DrawLines(pen, [new PointF(box.X + box.Width * 0.08f, box.Y + box.Height * 0.55f), new PointF(box.X + box.Width * 0.38f, box.Y + box.Height * 0.85f),
                    new PointF(box.X + box.Width * 0.95f, box.Y + box.Height * 0.18f)]);
                break;
            case Glyph.Down:
                g.DrawLine(pen, box.X + box.Width / 2f, box.Y + box.Height * 0.05f, box.X + box.Width / 2f, box.Y + box.Height * 0.9f);
                g.DrawLines(pen, [new PointF(box.X + box.Width * 0.12f, box.Y + box.Height * 0.52f), new PointF(box.X + box.Width / 2f, box.Y + box.Height * 0.92f),
                    new PointF(box.X + box.Width * 0.88f, box.Y + box.Height * 0.52f)]);
                break;
            case Glyph.Box:
                g.FillRectangle(brush, RectangleF.Inflate(box, -1f * scale, -1f * scale));
                break;
            case Glyph.Dash:
                g.DrawLine(pen, box.X + box.Width * 0.15f, box.Y + box.Height / 2f, box.X + box.Width * 0.85f, box.Y + box.Height / 2f);
                break;
            case Glyph.Person:
                g.FillEllipse(brush, box.X + box.Width * 0.28f, box.Y, box.Width * 0.44f, box.Height * 0.44f);
                g.FillPie(brush, box.X + box.Width * 0.05f, box.Y + box.Height * 0.52f, box.Width * 0.9f, box.Height * 0.96f, 180, 180);
                break;
        }
    }
}

// A status line with its pill: "Running" in green beside the plain sentence, for the bot, help and update rows.
internal sealed class StatusLine : Control {
    private Tone tone = Tone.Idle;
    private Glyph glyph = Glyph.Dash;
    private string pill = "";
    private string detail = "";
    private Font? pillFont;

    public StatusLine() {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint | ControlStyles.ResizeRedraw, true);
        SetStyle(ControlStyles.Selectable, false);
        // Sits on a tab page, whose themed background shows through.
        SetStyle(ControlStyles.SupportsTransparentBackColor, true);
        BackColor = Color.Transparent;
        Anchor = AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Top;
        Margin = new Padding(0, 6, 0, 6);
        Height = 26;
    }

    // The sentence beside the pill, as the label this replaces exposed it.
    public string Detail => detail;

    public void Set(Tone tone, Glyph glyph, string pill, string detail) {
        if (this.tone == tone && this.glyph == glyph && this.pill == pill && this.detail == detail) return;
        (this.tone, this.glyph, this.pill, this.detail) = (tone, glyph, pill, detail);
        AccessibleName = pill + ". " + detail;
        FitHeight();
        Invalidate();
    }

    // Keeps the pill and changes only the sentence.
    public void SetDetail(string text) => Set(tone, glyph, pill, text);

    private float Dpi => DeviceDpi / 96f;
    private Font PillFont => pillFont ??= new Font(Font.FontFamily, 8.25f, FontStyle.Bold);

    private int PillWidthNow() {
        if (pill.Length == 0) return 0;
        using var g = CreateGraphics();
        return StatusPaint.PillWidth(g, pill, PillFont, glyph, Dpi);
    }

    private const TextFormatFlags DetailFlags = TextFormatFlags.Left | TextFormatFlags.WordBreak | TextFormatFlags.NoPrefix | TextFormatFlags.NoPadding;

    // Long sentences wrap under themselves; the control grows to hold them.
    private void FitHeight() {
        if (!IsHandleCreated || Width <= 0) return;
        var pillWidth = PillWidthNow();
        var left = pillWidth == 0 ? 0 : pillWidth + (int)(10 * Dpi);
        var text = TextRenderer.MeasureText(detail.Length == 0 ? " " : detail, Font, new Size(Math.Max(40, Width - left), 0), DetailFlags);
        var wanted = Math.Max((int)(24 * Dpi), text.Height + (int)(6 * Dpi));
        if (Height != wanted) Height = wanted;
    }

    protected override void OnHandleCreated(EventArgs e) { base.OnHandleCreated(e); FitHeight(); }
    protected override void OnSizeChanged(EventArgs e) { base.OnSizeChanged(e); FitHeight(); }
    protected override void OnFontChanged(EventArgs e) { base.OnFontChanged(e); pillFont?.Dispose(); pillFont = null; FitHeight(); }
    protected override void Dispose(bool disposing) { if (disposing) pillFont?.Dispose(); base.Dispose(disposing); }

    protected override void OnPaint(PaintEventArgs e) {
        var left = 0;
        if (pill.Length > 0) {
            var width = StatusPaint.PillWidth(e.Graphics, pill, PillFont, glyph, Dpi);
            StatusPaint.Pill(e.Graphics, new Rectangle(0, (int)(2 * Dpi), width, (int)(20 * Dpi)), tone, glyph, pill, PillFont, Dpi);
            left = width + (int)(10 * Dpi);
        }
        TextRenderer.DrawText(e.Graphics, detail, Font, new Rectangle(left, (int)(3 * Dpi), Math.Max(0, Width - left), Height), StatusPaint.Ink, DetailFlags);
    }
}
