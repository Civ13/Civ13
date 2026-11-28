using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace Civ13.Launcher.Gui;

// The launcher stays a console-subsystem executable so scripted --version, --self-check and
// update-helper runs keep their exit codes and output. A double-clicked window owns its console
// alone; release it so players only see the launcher window. A terminal session keeps its console.
internal static class ConsoleWindow {
    [DllImport("kernel32.dll")] private static extern uint GetConsoleProcessList([Out] uint[] processes, uint count);
    [DllImport("kernel32.dll")] private static extern bool FreeConsole();

    public static void ReleaseIfOwned() {
        var processes = new uint[2];
        if (GetConsoleProcessList(processes, (uint)processes.Length) != 1) return;
        // Never write to a released console handle.
        Console.SetOut(TextWriter.Null);
        Console.SetError(TextWriter.Null);
        FreeConsole();
    }
}

// Existing launcher steps report progress through Console; show those lines in the window log.
internal static class ConsoleBridge {
    public static TextWriter LogWriter(TextBox box) {
        var hasLines = false;
        return new LauncherLogWriter(text => {
            if (box.IsDisposed) return;
            void Append() {
                if (box.IsDisposed) return;
                if (hasLines) box.AppendText(Environment.NewLine);
                box.AppendText(text);
                hasLines = true;
            }
            if (box.InvokeRequired) {
                try { box.BeginInvoke(Append); } catch (InvalidOperationException) { /* Window closing. */ }
            } else Append();
        });
    }
}
