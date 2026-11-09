using Civ13.Launcher;

// Start-menu entry decisions; the COM write itself runs only in the Windows window build.
static class StartMenuShortcutTests {
    public static int Run(string root) {
        var assertions = 0;
        void Require(bool condition, string message) {
            assertions++;
            if (!condition) throw new Exception("Start-menu shortcut: " + message);
        }
        var temp = Path.Combine(root, "shortcut-temp");
        var exe = Path.Combine(root, "Civ13-Launcher-Windows", "Civ13.exe");
        Require(StartMenuShortcut.Decide(exe, null, temp) == StartMenuShortcut.Plan.Create, "missing entry is created");
        Require(StartMenuShortcut.Decide(exe, exe, temp) == StartMenuShortcut.Plan.Current, "matching entry left alone");
        Require(StartMenuShortcut.Decide(exe, exe.ToUpperInvariant(), temp) == StartMenuShortcut.Plan.Current, "path case ignored");
        Require(StartMenuShortcut.Decide(exe, Path.Combine(root, "old", "Civ13.exe"), temp) == StartMenuShortcut.Plan.Update, "moved launcher repoints the entry");
        Require(StartMenuShortcut.Decide(Path.Combine(temp, "x", "Civ13.exe"), null, temp) == StartMenuShortcut.Plan.Skip, "temp copy skipped");
        Require(StartMenuShortcut.Decide(Path.Combine(root, "dotnet"), null, temp) == StartMenuShortcut.Plan.Skip, "test host skipped");
        Require(StartMenuShortcut.Decide(Path.Combine(root, "Civ13.exe.stage"), null, temp) == StartMenuShortcut.Plan.Skip, "updater stage skipped");
        Require(StartMenuShortcut.PathIn(Path.Combine(root, "Programs")) == Path.Combine(root, "Programs", "Civ13 Launcher.lnk"), "entry name");
        Require(StartMenuShortcut.Ensure() == null, "non-Windows or test host writes nothing and reports nothing");
        return assertions;
    }
}
