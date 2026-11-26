using System.ComponentModel;
using System.Drawing;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Window-local preference: never touch Windows settings or the game/host configuration.
internal static class LauncherSkin {
    internal const string FileName = "appearance.txt";
    internal static readonly Color Canvas = Color.FromArgb(26, 31, 38);
    internal static readonly Color Surface = Color.FromArgb(33, 40, 49);
    internal static readonly Color Raised = Color.FromArgb(47, 57, 70);
    internal static readonly Color Ink = Color.FromArgb(235, 239, 245);
    internal static readonly Color Muted = Color.FromArgb(180, 193, 210);
    internal static readonly Color Border = Color.FromArgb(103, 120, 143);
    internal static readonly Color Selection = Color.FromArgb(55, 77, 106);
    internal static readonly Color Accent = Color.FromArgb(151, 200, 255);
    internal static readonly Color Problem = Color.FromArgb(67, 37, 41);

    [ThreadStatic] private static bool requested;
    internal static bool Dark => requested && !SystemInformation.HighContrast;
    internal static void Choose(bool dark) => requested = dark;

    internal static bool Load(string root) {
        try {
            using var reader = File.OpenText(Path.Combine(root, FileName));
            // The longest valid preference is five characters; ignore unsupported files.
            Span<char> value = stackalloc char[6];
            return reader.ReadBlock(value) == 4 && value[..4].SequenceEqual("dark");
        } catch (Exception e) when (e is IOException or UnauthorizedAccessException) {
            return false;
        }
    }

    internal static void Save(string root, bool dark) {
        Directory.CreateDirectory(root);
        var path = Path.Combine(root, FileName);
        var temp = path + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try {
            File.WriteAllText(temp, dark ? "dark" : "light");
            File.Move(temp, path, true);
        } finally {
            if (File.Exists(temp)) File.Delete(temp);
        }
    }

    private static readonly ConditionalWeakTable<Control, Original> original = new();

    private sealed class Original {
        internal Action Restore = () => { };
        internal bool DarkApplied;
    }

    // Remember explicitly set properties separately from inherited ones so toggling back to the
    // standard skin restores normal WinForms inheritance, rather than freezing old ambient colors.
    private static Action Remember(Control control, params string[] names) {
        var properties = TypeDescriptor.GetProperties(control);
        var undo = new List<Action>();
        foreach (var name in names) {
            var property = properties[name];
            if (property == null) continue;
            if (property.ShouldSerializeValue(control)) {
                var value = property.GetValue(control);
                undo.Add(() => property.SetValue(control, value));
            } else undo.Add(() => property.ResetValue(control));
        }
        return () => { foreach (var action in undo) action(); };
    }

    internal static void Apply(Control control) {
        if (!original.TryGetValue(control, out var state)) {
            state = original.GetValue(control, _ => new Original());
            control.ControlAdded += (_, e) => { if (e.Control is { } child) Apply(child); };
            if (control is Form form) form.HandleCreated += (_, _) => PaintCaption(form);
        }

        if (Dark && !state.DarkApplied) {
            state.Restore = Remember(control, "BackColor", "ForeColor", "FlatStyle",
                "UseVisualStyleBackColor", "LinkColor", "ActiveLinkColor", "VisitedLinkColor",
                "DisabledLinkColor", "DrawMode", "OwnerDraw", "RenderMode");
            state.DarkApplied = true;
            SetDark(control);
        } else if (!Dark && state.DarkApplied) {
            state.DarkApplied = false;
            DetachPainters(control);
            state.Restore();
            state.Restore = () => { };
        }

        if (control.ContextMenuStrip is { } menu) Apply(menu);
        if (control is Form caption) PaintCaption(caption);
        foreach (Control child in control.Controls) Apply(child);
        control.Invalidate();
    }

    private static void SetDark(Control control) {
        control.ForeColor = Ink;
        // Status strips are transparent and their own drawing uses the active palette.
        if (control.BackColor != Color.Transparent || control is TabPage)
            control.BackColor = control switch {
                Button => Raised,
                TextBoxBase or ListView or ListBox or ComboBox or NumericUpDown or RegionBoardView => Surface,
                _ => Canvas
            };

        if (control is LinkLabel link) {
            link.LinkColor = Accent;
            link.ActiveLinkColor = Color.White;
            link.VisitedLinkColor = Accent;
            link.DisabledLinkColor = Muted;
        }
        if (control is ButtonBase button) {
            button.FlatStyle = FlatStyle.Flat;
            button.UseVisualStyleBackColor = false;
        }
        if (control is Button or CheckBox or RadioButton or LinkLabel)
            control.Paint += PaintDisabledText;
        if (control is ComboBox { DropDownStyle: ComboBoxStyle.DropDownList, DrawMode: DrawMode.Normal } combo) {
            combo.DrawMode = DrawMode.OwnerDrawFixed;
            combo.DrawItem += PaintChoice;
        }
        if (control is TabControl tabs) {
            tabs.DrawMode = TabDrawMode.OwnerDrawFixed;
            tabs.DrawItem += PaintTab;
            tabs.SelectedIndexChanged += RedrawTabs;
        }
        if (control is ListView list && !list.OwnerDraw) {
            list.OwnerDraw = true;
            list.DrawColumnHeader += PaintColumn;
            list.DrawItem += DefaultListItem;
            list.DrawSubItem += DefaultListCell;
        }
        if (control is ToolStrip strip) strip.Renderer = new DarkMenuRenderer();
    }

    private static void DetachPainters(Control control) {
        control.Paint -= PaintDisabledText;
        if (control is ComboBox combo) combo.DrawItem -= PaintChoice;
        if (control is TabControl tabs) {
            tabs.DrawItem -= PaintTab;
            tabs.SelectedIndexChanged -= RedrawTabs;
        }
        if (control is ListView list) {
            list.DrawColumnHeader -= PaintColumn;
            list.DrawItem -= DefaultListItem;
            list.DrawSubItem -= DefaultListCell;
        }
    }

    // WinForms' flat text renderer otherwise substitutes a near-black disabled
    // system color even when ForeColor is set. Keep the native button/radio frame.
    private static void PaintDisabledText(object? sender, PaintEventArgs e) {
        var control = (Control)sender!;
        if (control.Enabled || control.Text.Length == 0) return;

        var rect = control.ClientRectangle;
        var flags = TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis;
        if (control is Button) {
            rect.Inflate(-2, -2);
            flags |= TextFormatFlags.HorizontalCenter;
        } else if (control is CheckBox or RadioButton) {
            // The launcher's checkboxes and radio buttons all use the standard left glyph.
            var glyph = control.LogicalToDeviceUnits(17);
            if (control.RightToLeft != RightToLeft.Yes) rect.X += glyph;
            else flags |= TextFormatFlags.Right | TextFormatFlags.RightToLeft;
            rect.Width -= glyph;
        }
        if (rect.Width <= 0 || rect.Height <= 0) return;
        using var fill = new SolidBrush(control.BackColor);
        e.Graphics.FillRectangle(fill, rect);
        TextRenderer.DrawText(e.Graphics, control.Text, control.Font, rect, Muted, flags);
    }

    private static void PaintChoice(object? sender, DrawItemEventArgs e) {
        var combo = (ComboBox)sender!;
        var selected = (e.State & DrawItemState.Selected) != 0;
        using var fill = new SolidBrush(selected ? Selection : Surface);
        e.Graphics.FillRectangle(fill, e.Bounds);
        if (e.Index >= 0 && e.Index < combo.Items.Count) {
            var rect = Rectangle.Inflate(e.Bounds, -2, 0);
            TextRenderer.DrawText(e.Graphics, combo.GetItemText(combo.Items[e.Index]) ?? "", combo.Font, rect,
                combo.Enabled ? Ink : Muted, TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        }
        e.DrawFocusRectangle();
    }

    private static void RedrawTabs(object? sender, EventArgs e) => ((TabControl)sender!).Invalidate();
    private static void PaintTab(object? sender, DrawItemEventArgs e) {
        var tabs = (TabControl)sender!;
        if (e.Index < 0 || e.Index >= tabs.TabCount) return;
        using var fill = new SolidBrush(e.Index == tabs.SelectedIndex ? Selection : Raised);
        e.Graphics.FillRectangle(fill, e.Bounds);
        TextRenderer.DrawText(e.Graphics, tabs.TabPages[e.Index].Text, tabs.Font, e.Bounds, Ink,
            TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        e.DrawFocusRectangle();
    }

    private static void PaintColumn(object? sender, DrawListViewColumnHeaderEventArgs e) {
        using var fill = new SolidBrush(Raised);
        e.Graphics.FillRectangle(fill, e.Bounds);
        var textArea = Rectangle.Inflate(e.Bounds, -4, 0);
        TextRenderer.DrawText(e.Graphics, e.Header?.Text ?? "", e.Font, textArea, Ink,
            TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
        using var edge = new Pen(Border);
        e.Graphics.DrawLine(edge, e.Bounds.Right - 1, e.Bounds.Top, e.Bounds.Right - 1, e.Bounds.Bottom);
    }

    private static void DefaultListItem(object? sender, DrawListViewItemEventArgs e) => e.DrawDefault = true;
    private static void DefaultListCell(object? sender, DrawListViewSubItemEventArgs e) => e.DrawDefault = true;

    internal static DialogResult Show(Form dialog, Form owner) {
        Apply(dialog);
        return dialog.ShowDialog(owner);
    }

    private static void PaintCaption(Form form) {
        if (!form.IsHandleCreated || !OperatingSystem.IsWindowsVersionAtLeast(10, 0, 17763)) return;
        var dark = Dark ? 1 : 0;
        // Supported Windows 11 attribute and the Windows 10 predecessor. Older systems keep their system caption.
        if (DwmSetWindowAttribute(form.Handle, 20, ref dark, sizeof(int)) != 0)
            _ = DwmSetWindowAttribute(form.Handle, 19, ref dark, sizeof(int));
    }

    [DllImport("dwmapi.dll", ExactSpelling = true)]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    private sealed class DarkMenuRenderer() : ToolStripProfessionalRenderer(new MenuPalette()) {
        protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e) {
            e.TextColor = e.Item.Enabled ? Ink : Muted;
            base.OnRenderItemText(e);
        }
        protected override void OnRenderArrow(ToolStripArrowRenderEventArgs e) {
            e.ArrowColor = Ink;
            base.OnRenderArrow(e);
        }
    }

    private sealed class MenuPalette : ProfessionalColorTable {
        public MenuPalette() => UseSystemColors = false;
        public override Color ToolStripDropDownBackground => Surface;
        public override Color ImageMarginGradientBegin => Surface;
        public override Color ImageMarginGradientMiddle => Surface;
        public override Color ImageMarginGradientEnd => Surface;
        public override Color MenuBorder => Border;
        public override Color MenuItemBorder => Accent;
        public override Color MenuItemSelected => Selection;
        public override Color MenuItemSelectedGradientBegin => Selection;
        public override Color MenuItemSelectedGradientEnd => Selection;
        public override Color SeparatorDark => Border;
        public override Color SeparatorLight => Surface;
    }
}
