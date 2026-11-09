using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Text;

namespace Civ13.Launcher;

// Keeps a per-user Start-menu entry ("Civ13 Launcher") pointing at the running Civ13.exe, so the
// portable launcher shows up in Windows search and can be opened by name (Claude computer use
// resolves apps from the Start menu). The updater replaces the exe in place, so the entry stays
// valid; it is rewritten only when missing or pointing somewhere else.
public static class StartMenuShortcut {
    public const string Name = "Civ13 Launcher";

    public enum Plan { Skip, Create, Update, Current }

    // Only a published Civ13.exe outside the temp folders gets an entry: not dotnet test hosts,
    // not an updater stage, not a copy run from a download or extraction folder.
    public static Plan Decide(string exePath, string? currentTarget, string tempDir) {
        if (!string.Equals(Path.GetFileName(exePath), "Civ13.exe", StringComparison.OrdinalIgnoreCase)) return Plan.Skip;
        var full = Path.GetFullPath(exePath);
        var temp = Path.GetFullPath(tempDir).TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
        if (full.StartsWith(temp, StringComparison.OrdinalIgnoreCase)) return Plan.Skip;
        if (currentTarget == null) return Plan.Create;
        return string.Equals(Path.GetFullPath(currentTarget), full, StringComparison.OrdinalIgnoreCase) ? Plan.Current : Plan.Update;
    }

    public static string PathIn(string programsDir) => Path.Combine(programsDir, Name + ".lnk");

    // Best effort: a failure here never stops the launcher; it returns the reason for the log.
    public static string? Ensure() {
        if (!OperatingSystem.IsWindows()) return null;
        try { return EnsureWindows(); }
        catch (Exception error) { return "Start-menu entry not updated: " + error.GetType().Name; }
    }

    [SupportedOSPlatform("windows")]
    private static string? EnsureWindows() {
        var exe = Environment.ProcessPath;
        var programs = Environment.GetFolderPath(Environment.SpecialFolder.Programs);
        if (exe == null || programs.Length == 0) return null;
        var lnk = PathIn(programs);
        var link = (IShellLinkW)new ShellLink();
        try {
            var file = (IPersistFile)link;
            string? current = null;
            if (File.Exists(lnk)) {
                file.Load(lnk, 0);
                var target = new StringBuilder(1024);
                link.GetPath(target, target.Capacity, IntPtr.Zero, 0);
                current = target.ToString();
            }
            var plan = Decide(exe, current, Path.GetTempPath());
            if (plan is Plan.Skip or Plan.Current) return null;
            link.SetPath(exe);
            link.SetWorkingDirectory(Path.GetDirectoryName(exe) ?? "");
            link.SetDescription("Play and host Civ13");
            link.SetIconLocation(exe, 0);
            Directory.CreateDirectory(programs);
            file.Save(lnk, true);
            return null;
        }
        finally { Marshal.FinalReleaseComObject(link); }
    }

    [ComImport, Guid("00021401-0000-0000-C000-000000000046")]
    private class ShellLink { }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
    private interface IShellLinkW {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder file, int size, IntPtr findData, uint flags);
        void GetIDList(out IntPtr idList);
        void SetIDList(IntPtr idList);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder name, int size);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string name);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder dir, int size);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string dir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder args, int size);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string args);
        void GetHotkey(out short hotkey);
        void SetHotkey(short hotkey);
        void GetShowCmd(out int showCmd);
        void SetShowCmd(int showCmd);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder path, int size, out int icon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string path, int icon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string path, uint reserved);
        void Resolve(IntPtr hwnd, uint flags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string file);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("0000010b-0000-0000-C000-000000000046")]
    private interface IPersistFile {
        void GetClassID(out Guid classId);
        [PreserveSig] int IsDirty();
        void Load([MarshalAs(UnmanagedType.LPWStr)] string file, uint mode);
        void Save([MarshalAs(UnmanagedType.LPWStr)] string file, [MarshalAs(UnmanagedType.Bool)] bool remember);
        void SaveCompleted([MarshalAs(UnmanagedType.LPWStr)] string file);
        void GetCurFile([MarshalAs(UnmanagedType.LPWStr)] out string file);
    }
}
