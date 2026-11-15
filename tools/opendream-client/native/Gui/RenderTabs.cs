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
            Directory.CreateDirectory(output);
            var written = new List<string>();
            foreach (TabPage page in tabs.TabPages) {
                tabs.SelectedTab = page;
                // Let the tab lay out and paint before it is copied.
                for (var pass = 0; pass < 5; pass++) { Application.DoEvents(); await Task.Delay(100); }
                using var image = new Bitmap(Width, Height);
                DrawToBitmap(image, new Rectangle(0, 0, Width, Height));
                var name = new string(page.Text.ToLowerInvariant().Where(char.IsAsciiLetterLower).ToArray()) + ".png";
                image.Save(Path.Combine(output, name), ImageFormat.Png);
                written.Add(name);
            }
            Console.SetOut(console);
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
