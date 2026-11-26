using System.Drawing;
using System.Drawing.Imaging;
using System.Text.Json;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// Civ13.exe --render-tabs <launcher data folder> <output folder>: draws the hosting tabs to PNG files so a
// change to how the launcher looks can be reviewed without a host. It builds the same window from that
// folder's host.json, asks its scripts for status and update checks only (tests/render/host_fixture.py
// makes a pretend setup that answers in every state), and skips the launcher update, BYOND and the server list.
internal sealed partial class LauncherWindow {
    public static int RenderTabs(string root, string output, Version version) {
        var exit = 1;
        var thread = new Thread(() => {
            // 96 DPI whatever the screen, so two renders of the same change are comparable.
            Application.SetHighDpiMode(HighDpiMode.DpiUnaware);
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            using var window = new LauncherWindow(root, version, output) {
                StartPosition = FormStartPosition.Manual, Location = new Point(-20000, -20000), ShowInTaskbar = false,
            };
            Application.ThreadException += (_, e) => { Console.Error.WriteLine("Render failed: " + e.Exception.Message); window.Close(); };
            Application.Run(window);
            exit = window.renderExit;
        });
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        thread.Join();
        return exit;
    }

    private static void VerifyDarkSurfaces(Bitmap image, string page) {
        int canvas = 0, surface = 0;
        for (var y = 0; y < image.Height; y += 16)
            for (var x = 0; x < image.Width; x += 16) {
                var pixel = image.GetPixel(x, y).ToArgb();
                if (pixel == LauncherSkin.Canvas.ToArgb()) canvas++;
                if (pixel == LauncherSkin.Surface.ToArgb()) surface++;
            }
        if (canvas < 10 || surface < 10)
            throw new InvalidOperationException($"Dark surfaces missing from the {page} render.");
    }

    private void VerifyDisabledButtonInk(Bitmap image) {
        var button = signInButton;
        if (button.Enabled) return;
        var start = PointToClient(button.PointToScreen(Point.Empty));
        var bounds = Rectangle.Intersect(new Rectangle(start, button.ClientSize), new Rectangle(0, 0, image.Width, image.Height));
        var ink = LauncherSkin.Muted;
        var samples = 0;
        for (var y = bounds.Top; y < bounds.Bottom; y++)
            for (var x = bounds.Left; x < bounds.Right; x++) {
                var pixel = image.GetPixel(x, y);
                // Allow modest antialiasing variation; neither the native rim nor the raised surface is this color.
                if (Math.Abs(pixel.R - ink.R) < 12 && Math.Abs(pixel.G - ink.G) < 12
                    && Math.Abs(pixel.B - ink.B) < 12 && ++samples >= 4) return;
            }
        throw new InvalidOperationException("Disabled buttons are not using readable dark-mode ink.");
    }

    private int renderExit = 1;

    private async Task RenderTabsTo(string output) {
        var console = Console.Out;
        try {
            Console.SetOut(new LogWriter(log));
            host = LocalHosting.Load(root) ?? throw new InvalidDataException("No host.json in " + root + ".");
            AddHostTabs(host);
            startupDone = true;
            SetStatus($"Launcher {version.ToString(3)}  |  Drawn from {Path.Combine(root, LocalHosting.FileName)}");
            await RefreshHostState();
            await CheckAllUpdates();
            await RefreshHostState();
            if (botProfile != null) await RefreshBot();
            if (host.Control is { Group: not null } helpControl) await RefreshHelp(helpControl);
            if (darkMode.Checked && !SystemInformation.HighContrast) {
                // The dark fixture starts from its persisted setting, then exercises the same
                // toggle used by players after the host tabs and their child controls exist.
                if (BackColor != LauncherSkin.Canvas || hostBoard?.BackColor != LauncherSkin.Surface)
                    throw new InvalidOperationException("The stored dark skin did not reach the host board.");
                darkMode.Checked = false;
                if (BackColor == LauncherSkin.Canvas || hostBoard?.BackColor != Color.White
                    || tabs.DrawMode != TabDrawMode.Normal || serverList.OwnerDraw)
                    throw new InvalidOperationException("The standard skin was not restored.");
                darkMode.Checked = true;
                if (!LauncherSkin.Load(root) || BackColor != LauncherSkin.Canvas || hostBoard?.BackColor != LauncherSkin.Surface
                    || tabs.DrawMode != TabDrawMode.OwnerDrawFixed || !serverList.OwnerDraw)
                    throw new InvalidOperationException("The dark skin could not be reapplied.");

                var scratch = Directory.CreateTempSubdirectory("ci-launcher-appearance-");
                try {
                    if (LauncherSkin.Load(scratch.FullName))
                        throw new InvalidOperationException("The standard skin should be the default.");
                    File.WriteAllText(Path.Combine(scratch.FullName, LauncherSkin.FileName), "unsupported");
                    if (LauncherSkin.Load(scratch.FullName))
                        throw new InvalidOperationException("An unknown appearance must not enable the dark skin.");
                    LauncherSkin.Save(scratch.FullName, true);
                    if (!LauncherSkin.Load(scratch.FullName))
                        throw new InvalidOperationException("The dark skin preference did not round-trip.");
                    LauncherSkin.Save(scratch.FullName, false);
                    if (LauncherSkin.Load(scratch.FullName))
                        throw new InvalidOperationException("The standard skin preference did not round-trip.");
                } finally {
                    scratch.Delete(true);
                }
            }
            Directory.CreateDirectory(output);
            var written = new List<string>();
            foreach (TabPage page in tabs.TabPages) {
                tabs.SelectedTab = page;
                // Let the tab lay out and paint before it is copied.
                for (var pass = 0; pass < 5; pass++) { Application.DoEvents(); await Task.Delay(100); }
                using var image = new Bitmap(Width, Height);
                DrawToBitmap(image, new Rectangle(0, 0, Width, Height));
                if (LauncherSkin.Dark) {
                    VerifyDarkSurfaces(image, page.Text);
                    if (page == tabs.TabPages[0]) VerifyDisabledButtonInk(image);
                }
                var name = new string(page.Text.ToLowerInvariant().Where(char.IsAsciiLetterLower).ToArray()) + ".png";
                image.Save(Path.Combine(output, name), ImageFormat.Png);
                written.Add(name);
            }
            Console.SetOut(console);
            if (LauncherSkin.Dark) Console.WriteLine("Dark skin rendering verified.");
            Console.WriteLine("Rendered " + string.Join(", ", written) + " to " + output);
            renderExit = 0;
        } catch (Exception e) when (e is IOException or UnauthorizedAccessException or InvalidDataException or JsonException or System.ComponentModel.Win32Exception
                or InvalidOperationException or System.Runtime.InteropServices.ExternalException) {
            Console.SetOut(console);
            Console.Error.WriteLine("Render failed: " + e.Message);
        } finally {
            Close();
        }
    }
}
