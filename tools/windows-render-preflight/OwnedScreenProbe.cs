// Native diagnostic only. No BYOND, browser, network, injected input or offscreen capture.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

public static class OwnedScreenProbe
{
    const int FrameWidth = 320, FrameHeight = 160;
    [StructLayout(LayoutKind.Sequential)] struct Rect { public int Left, Top, Right, Bottom; }
    [StructLayout(LayoutKind.Sequential)] struct Point { public int X, Y; public Point(int x, int y) { X = x; Y = y; } }
    [StructLayout(LayoutKind.Sequential)] struct ObjectFlags { public int Inherit, Reserved; public uint Flags; }
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr OpenInputDesktop(uint flags, bool inherit, uint access);
    [DllImport("user32.dll", SetLastError = true)] static extern bool CloseDesktop(IntPtr desktop);
    [DllImport("user32.dll")] static extern IntPtr GetProcessWindowStation();
    [DllImport("user32.dll")] static extern IntPtr GetThreadDesktop(uint thread);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool GetUserObjectInformationW(IntPtr handle, int index, IntPtr data, uint size, out uint needed);
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SetThreadDpiAwarenessContext(IntPtr context);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr window);
    [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr window);
    [DllImport("user32.dll")] static extern bool IsIconic(IntPtr window);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr window, out uint pid);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowTextW(IntPtr window, StringBuilder text, int capacity);
    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr window, out Rect rect);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr window, ref Point point);
    [DllImport("user32.dll")] static extern IntPtr WindowFromPoint(Point point);

    sealed class PatternWindow : Form
    {
        public bool Inverted;
        public int PaintCount;
        public PatternWindow(string title, Rectangle screen)
        {
            Text = title;
            FormBorderStyle = FormBorderStyle.None;
            AutoScaleMode = AutoScaleMode.None;
            StartPosition = FormStartPosition.Manual;
            ShowInTaskbar = false;
            TopMost = true;
            ClientSize = new Size(FrameWidth, FrameHeight);
            Location = new System.Drawing.Point(screen.Left + 32, screen.Top + 32);
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            using (Brush left = new SolidBrush(Inverted ? Color.Cyan : Color.Red))
            using (Brush right = new SolidBrush(Inverted ? Color.Yellow : Color.Blue))
            {
                e.Graphics.FillRectangle(left, 0, 0, FrameWidth / 2, FrameHeight);
                e.Graphics.FillRectangle(right, FrameWidth / 2, 0, FrameWidth / 2, FrameHeight);
            }
            PaintCount++;
        }
    }

    sealed class Refusal : Exception { public Refusal(string code) : base(code) {} }
    static void Require(bool condition, string code)
    {
        if (!condition) throw new Refusal(code);
    }
    static int ObjectInteger(IntPtr handle, int index)
    {
        IntPtr memory = Marshal.AllocHGlobal(4);
        try
        {
            uint needed;
            Require(handle != IntPtr.Zero && GetUserObjectInformationW(handle, index, memory, 4, out needed), "object_integer_unavailable");
            return Marshal.ReadInt32(memory);
        }
        finally { Marshal.FreeHGlobal(memory); }
    }
    static string ObjectName(IntPtr handle)
    {
        IntPtr memory = Marshal.AllocHGlobal(512);
        try
        {
            uint needed;
            Require(handle != IntPtr.Zero && GetUserObjectInformationW(handle, 2, memory, 512, out needed), "object_name_unavailable");
            string name = Marshal.PtrToStringUni(memory);
            Require(name != null && name.Length <= 128, "object_name_out_of_bounds");
            return name;
        }
        finally { Marshal.FreeHGlobal(memory); }
    }
    static bool VisibleStation(IntPtr handle)
    {
        int size = Marshal.SizeOf(typeof(ObjectFlags));
        IntPtr memory = Marshal.AllocHGlobal(size);
        try
        {
            uint needed;
            Require(handle != IntPtr.Zero && GetUserObjectInformationW(handle, 1, memory, (uint)size, out needed), "station_flags_unavailable");
            return (((ObjectFlags)Marshal.PtrToStructure(memory, typeof(ObjectFlags))).Flags & 1) != 0;
        }
        finally { Marshal.FreeHGlobal(memory); }
    }
    static void Budget(Stopwatch clock) { Require(clock.ElapsedMilliseconds < 30000, "thirty_second_budget_exhausted"); }
    static void Pump(Stopwatch clock)
    {
        long until = clock.ElapsedMilliseconds + 300;
        while (clock.ElapsedMilliseconds < until)
        {
            Budget(clock);
            Application.DoEvents();
            Thread.Sleep(10);
        }
    }
    static Rectangle VerifyWindow(IntPtr window, uint pid, string title, IntPtr input, IntPtr desktop, Rectangle screen)
    {
        uint owner;
        Require(IsWindow(window) && GetWindowThreadProcessId(window, out owner) != 0 && owner == pid, "owned_window_identity_changed");
        StringBuilder actualTitle = new StringBuilder(128);
        GetWindowTextW(window, actualTitle, actualTitle.Capacity);
        Require(actualTitle.ToString() == title, "owned_window_title_changed");
        Require(ObjectInteger(input, 6) == 1 && ObjectInteger(desktop, 6) == 1, "input_desktop_changed");
        Require(IsWindowVisible(window) && !IsIconic(window) && GetForegroundWindow() == window, "owned_window_not_foreground_visible");
        Rect client;
        Require(GetClientRect(window, out client) && client.Left == 0 && client.Top == 0 && client.Right == FrameWidth && client.Bottom == FrameHeight, "client_size_changed");
        Point start = new Point(0, 0), end = new Point(FrameWidth, FrameHeight);
        Require(ClientToScreen(window, ref start) && ClientToScreen(window, ref end), "client_geometry_unavailable");
        Rectangle bounds = new Rectangle(start.X, start.Y, end.X - start.X, end.Y - start.Y);
        Require(bounds.Width == FrameWidth && bounds.Height == FrameHeight && screen.Contains(bounds), "client_geometry_out_of_bounds");
        foreach (int x in new int[] { 0, FrameWidth / 2, FrameWidth - 1 })
            foreach (int y in new int[] { 0, FrameHeight / 2, FrameHeight - 1 })
                Require(WindowFromPoint(new Point(start.X + x, start.Y + y)) == window, "owned_window_occluded");
        return bounds;
    }
    public static bool ValidateFrame(Bitmap frame, bool inverted)
    {
        if (frame.Width != FrameWidth || frame.Height != FrameHeight) return false;
        int left = (inverted ? Color.Cyan : Color.Red).ToArgb();
        int right = (inverted ? Color.Yellow : Color.Blue).ToArgb();
        for (int y = 0; y < FrameHeight; y++)
            for (int x = 0; x < FrameWidth; x++)
                if (frame.GetPixel(x, y).ToArgb() != (x < FrameWidth / 2 ? left : right)) return false;
        return true;
    }
    static Bitmap Capture(IntPtr window, uint pid, string title, IntPtr input, IntPtr desktop, Rectangle screen, bool inverted, Stopwatch clock)
    {
        Budget(clock);
        Rectangle before = VerifyWindow(window, pid, title, input, desktop, screen);
        Bitmap frame = new Bitmap(FrameWidth, FrameHeight, PixelFormat.Format24bppRgb);
        try
        {
            using (Graphics pixels = Graphics.FromImage(frame))
                pixels.CopyFromScreen(before.Left, before.Top, 0, 0, before.Size, CopyPixelOperation.SourceCopy);
            Require(before == VerifyWindow(window, pid, title, input, desktop, screen), "capture_geometry_changed");
            Budget(clock);
            // Validate EVERY pixel before any image may reach disk or an artifact.
            Require(ValidateFrame(frame, inverted), "unexpected_blank_stale_or_occluded_pixels");
            return frame;
        }
        catch { frame.Dispose(); throw; }
    }
    public static int SelfTest()
    {
        // Synthetic validator controls only; no desktop calls and no saved images.
        int checks = 0;
        using (Bitmap frame = new Bitmap(FrameWidth, FrameHeight, PixelFormat.Format24bppRgb))
        using (Graphics graphics = Graphics.FromImage(frame))
        using (Bitmap wrongSize = new Bitmap(1, 1))
        {
            graphics.Clear(Color.Black);
            Require(!ValidateFrame(frame, false), "selftest_blank"); checks++;
            graphics.Clear(Color.Red);
            Require(!ValidateFrame(frame, false), "selftest_single_color"); checks++;
            graphics.FillRectangle(Brushes.Blue, FrameWidth / 2, 0, FrameWidth / 2, FrameHeight);
            Require(ValidateFrame(frame, false), "selftest_red_blue"); checks++;
            Require(!ValidateFrame(frame, true), "selftest_stale"); checks++;
            frame.SetPixel(0, 0, Color.Black);
            Require(!ValidateFrame(frame, false), "selftest_one_pixel"); checks++;
            graphics.Clear(Color.Cyan);
            graphics.FillRectangle(Brushes.Yellow, FrameWidth / 2, 0, FrameWidth / 2, FrameHeight);
            Require(ValidateFrame(frame, true), "selftest_inverse"); checks++;
            Require(!ValidateFrame(wrongSize, false), "selftest_size"); checks++;
        }
        return checks;
    }
    public static Dictionary<string, object> Run(string output)
    {
        Dictionary<string, object> result = new Dictionary<string, object>();
        Stopwatch clock = Stopwatch.StartNew();
        PatternWindow form = null;
        Bitmap first = null, second = null;
        IntPtr input = IntPtr.Zero, oldDpi = IntPtr.Zero, window = IntPtr.Zero;
        bool closed = true, inputClosed = true, dpiRestored = true;
        result["status"] = "capability_unavailable";
        result["reason"] = "not_started";
        result["capture_count"] = 0;
        try
        {
            Require(Thread.CurrentThread.GetApartmentState() == ApartmentState.STA, "sta_thread_required");
            using (Process current = Process.GetCurrentProcess())
            {
                result["pid"] = current.Id;
                result["session_id"] = current.SessionId;
            }
            result["user_interactive"] = Environment.UserInteractive;
            IntPtr station = GetProcessWindowStation(), desktop = GetThreadDesktop(GetCurrentThreadId());
            result["window_station"] = ObjectName(station);
            result["thread_desktop"] = ObjectName(desktop);
            result["station_visible"] = VisibleStation(station);
            // DESKTOP_READOBJECTS only. A denial ends this probe, without retry or switching desktops.
            input = OpenInputDesktop(0, false, 0x0001);
            if (input == IntPtr.Zero)
            {
                int error = Marshal.GetLastWin32Error();
                result["input_desktop_error"] = error;
                throw new Refusal(error == 5 ? "input_desktop_access_denied" : "input_desktop_unavailable");
            }
            result["input_desktop"] = ObjectName(input);
            Require(Environment.UserInteractive && (bool)result["station_visible"], "noninteractive_station");
            Require(ObjectInteger(input, 6) == 1 && ObjectInteger(desktop, 6) == 1, "thread_not_on_input_desktop");
            // Thread-local coordinate handling only; restore it after our owned window is disposed.
            oldDpi = SetThreadDpiAwarenessContext(new IntPtr(-4));
            Require(oldDpi != IntPtr.Zero, "dpi_context_unavailable");
            Require(Screen.PrimaryScreen != null, "primary_screen_unavailable");
            Rectangle screen = Screen.PrimaryScreen.Bounds;
            Rectangle virtualScreen = SystemInformation.VirtualScreen;
            result["primary_geometry"] = new int[] { screen.X, screen.Y, screen.Width, screen.Height };
            result["virtual_geometry"] = new int[] { virtualScreen.X, virtualScreen.Y, virtualScreen.Width, virtualScreen.Height };
            Require(screen.Width >= FrameWidth + 64 && screen.Height >= FrameHeight + 64, "screen_too_small");
            string title = "Civ13-owned-preflight-" + Guid.NewGuid().ToString("N");
            form = new PatternWindow(title, screen);
            window = form.Handle;
            closed = false;
            uint pid = (uint)(int)result["pid"], owner;
            Require(GetWindowThreadProcessId(window, out owner) != 0 && owner == pid, "initial_window_ownership_failed");
            result["owned_hwnd"] = window.ToInt64();
            result["owned_title"] = title;
            form.Show();
            form.Activate(); // Only this owned window; no input injection or activation workaround.
            form.Refresh();
            Pump(clock);
            Require(form.PaintCount > 0, "initial_paint_missing");
            first = Capture(window, pid, title, input, desktop, screen, false, clock);
            int previousPaint = form.PaintCount;
            form.Inverted = true;
            form.Invalidate();
            form.Update();
            Pump(clock);
            Require(form.PaintCount > previousPaint, "inverse_repaint_missing");
            second = Capture(window, pid, title, input, desktop, screen, true, clock);
            result["capture_count"] = 2;
            result["client_size"] = new int[] { FrameWidth, FrameHeight };
            result["status"] = "passed_owned_screen_capture";
            result["reason"] = "two_exact_inverse_screen_frames";
        }
        catch (Exception error)
        {
            // Fixed in-source reason codes only; unexpected exceptions disclose type, not paths or data.
            result["reason"] = error is Refusal ? error.Message : error.GetType().Name;
        }
        finally
        {
            if (form != null)
            {
                try { form.Close(); form.Dispose(); closed = form.IsDisposed && (window == IntPtr.Zero || !IsWindow(window)); }
                catch { closed = false; }
            }
            if (input != IntPtr.Zero) inputClosed = CloseDesktop(input);
            if (oldDpi != IntPtr.Zero) dpiRestored = SetThreadDpiAwarenessContext(oldDpi) != IntPtr.Zero;
            result["owned_window_closed"] = closed;
            result["input_handle_closed"] = inputClosed;
            result["thread_dpi_restored"] = dpiRestored;
            if (!closed || !inputClosed || !dpiRestored)
            {
                result["status"] = "capability_unavailable";
                result["reason"] = "owned_cleanup_unconfirmed";
            }
            try
            {
                if ((string)result["status"] == "passed_owned_screen_capture")
                {
                    Budget(clock);
                    // Both frames were validated in memory. Never serialize unexpected pixels.
                    first.Save(Path.Combine(output, "red-blue.png"), ImageFormat.Png);
                    second.Save(Path.Combine(output, "cyan-yellow.png"), ImageFormat.Png);
                }
            }
            catch { result["status"] = "probe_error"; result["reason"] = "evidence_write_failed_or_budget_expired"; }
            finally { if (first != null) first.Dispose(); if (second != null) second.Dispose(); }
            result["elapsed_ms"] = clock.ElapsedMilliseconds;
        }
        return result;
    }
}
