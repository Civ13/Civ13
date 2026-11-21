using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace Civ13.Launcher;

// Process checks and kills that never go through tasklist, taskkill or WMI (CIM).
//
// On 2026-11-19 a broken WMI provider ("Provider load failure") made tasklist hang and kept Gaia
// down. The launcher follows the host's criticality rules (scripts/gaia-host/README.md, Process
// safety): looking never kills and answers "unknown" when it cannot tell; a kill only ends a
// process it has verified (program file and start time) on the same handle it then terminates,
// so a reused pid can never redirect it; a start never depends on WMI.
public static class ProcessSafety {
    public sealed record Identity(int Pid, DateTime StartUtc, string? Image);

    // Ended: the root process is gone. Refused: why it was left running (null when it was ended or already gone).
    public sealed record EndResult(bool Ended, string? Refused);

    // A process younger than its recorded parent by more than this still counts as its child.
    private static readonly TimeSpan Slack = TimeSpan.FromSeconds(2);

    // Why ident is not what expect describes, or null when it matches. Pure, so it is tested off Windows.
    public static string? Problem(Identity? ident, IReadOnlyCollection<string> images, DateTime? bornBeforeUtc = null) {
        if (ident == null) return "it could not be inspected";
        var name = Path.GetFileName((ident.Image ?? "").Replace('\\', '/')).ToLowerInvariant();
        if (name.Length == 0 || !images.Any(image => string.Equals(image, name, StringComparison.OrdinalIgnoreCase)))
            return "it is " + (ident.Image ?? "an unknown program");
        if (bornBeforeUtc is { } before && ident.StartUtc > before + Slack) return "it started after the recorded process (the pid was reused)";
        return null;
    }

    // The process's identity, or null when it is gone or cannot be inspected.
    public static Identity? Inspect(int pid) {
        if (!OperatingSystem.IsWindows() || pid <= 0) return null;
        using var handle = Native.OpenProcess(Native.QueryLimited, false, (uint)pid);
        return handle.IsInvalid ? null : Read(handle, pid);
    }

    // The command line of a running process, read from the kernel (Windows 8.1 and later), or null.
    public static string? CommandLine(int pid) {
        if (!OperatingSystem.IsWindows() || pid <= 0) return null;
        using var handle = Native.OpenProcess(Native.QueryLimited, false, (uint)pid);
        if (handle.IsInvalid) return null;
        var size = 0;
        Native.NtQueryInformationProcess(handle, Native.ProcessCommandLineInformation, IntPtr.Zero, 0, ref size);
        if (size <= 0 || size > 1 << 20) return null;
        var buffer = Marshal.AllocHGlobal(size);
        try {
            if (Native.NtQueryInformationProcess(handle, Native.ProcessCommandLineInformation, buffer, size, ref size) != 0) return null;
            var text = Marshal.PtrToStructure<Native.UnicodeString>(buffer);
            return text.Buffer == IntPtr.Zero ? null : Marshal.PtrToStringUni(text.Buffer, text.Length / 2);
        } finally { Marshal.FreeHGlobal(buffer); }
    }

    // Processes with this image name (no ".exe"), from the kernel's process list, not WMI.
    public static IReadOnlyList<int> ByName(string name) {
        var found = new List<int>();
        foreach (var process in Process.GetProcessesByName(name)) using (process) found.Add(process.Id);
        return found;
    }

    // Pids started (directly or not) by pid; a child only counts when it is younger than its parent,
    // since a parent pid in the table may name a process that has since been reused.
    public static IReadOnlyList<int> Descendants(int pid, DateTime startUtc) {
        if (!OperatingSystem.IsWindows()) return [];
        var parents = new Dictionary<int, List<int>>();
        foreach (var process in Process.GetProcesses()) {
            using (process) {
                if (ParentOf(process.Id) is { } parent && parent != process.Id) {
                    if (!parents.TryGetValue(parent, out var list)) parents[parent] = list = [];
                    list.Add(process.Id);
                }
            }
        }
        var born = new Dictionary<int, DateTime> { [pid] = startUtc };
        var found = new List<int>();
        var queue = new Queue<int>([pid]);
        while (queue.Count > 0) {
            var parent = queue.Dequeue();
            if (!parents.TryGetValue(parent, out var children)) continue;
            foreach (var child in children) {
                if (born.ContainsKey(child) || Inspect(child) is not { } ident) continue;
                if (ident.StartUtc + Slack < born[parent]) continue; // older than its "parent": that pid was reused
                born[child] = ident.StartUtc;
                found.Add(child);
                queue.Enqueue(child);
            }
        }
        return found;
    }

    // Ends pid, and with tree everything it started, after checking it against images (and bornBeforeUtc,
    // for a pid recorded earlier). An unverified process is left running and Refused says why.
    public static EndResult End(int pid, IReadOnlyCollection<string> images, DateTime? bornBeforeUtc = null, bool tree = true) {
        if (!OperatingSystem.IsWindows()) return new(false, "ending processes is only supported on Windows");
        if (pid <= 0 || pid == Environment.ProcessId) return new(false, $"refusing to end process {pid}");
        using var handle = Native.OpenProcess(Native.Terminate | Native.QueryLimited | Native.Synchronize, false, (uint)pid);
        if (handle.IsInvalid) {
            var error = Marshal.GetLastWin32Error();
            return error == Native.ErrorInvalidParameter ? new(true, null) // no such process: already gone
                : new(false, $"process {pid} could not be opened ({new Win32Exception(error).Message}); it was left running");
        }
        if (!StillActive(handle)) return new(true, null);
        var ident = Read(handle, pid);
        if (Problem(ident, images, bornBeforeUtc) is { } problem) return new(false, $"process {pid} {problem}; it was left running");
        var children = tree && ident != null ? Descendants(pid, ident.StartUtc) : [];
        if (!Native.TerminateProcess(handle, 1) && StillActive(handle))
            return new(false, $"process {pid} could not be ended ({new Win32Exception(Marshal.GetLastWin32Error()).Message})");
        var ended = Native.WaitForSingleObject(handle, 5000) == 0 || !StillActive(handle);
        foreach (var child in children) EndChild(child);
        return new(ended, ended ? null : $"process {pid} was told to end but is still running");
    }

    private static void EndChild(int pid) {
        using var handle = Native.OpenProcess(Native.Terminate | Native.Synchronize, false, (uint)pid);
        if (!handle.IsInvalid && Native.TerminateProcess(handle, 1)) Native.WaitForSingleObject(handle, 1000);
    }

    // Starts a program outside the caller's job object when the job allows it (so it outlives a remote
    // helper that started this launcher), without WMI. Returns the new process id.
    public static int StartDetached(string commandLine, string workingDirectory) {
        if (!OperatingSystem.IsWindows()) throw new PlatformNotSupportedException("Detached starts are only supported on Windows.");
        foreach (var breakaway in new[] { true, false }) {
            var flags = Native.CreateNoWindow | Native.CreateNewProcessGroup | Native.CreateUnicodeEnvironment | (breakaway ? Native.CreateBreakawayFromJob : 0);
            var startup = new Native.StartupInfo { cb = Marshal.SizeOf<Native.StartupInfo>() };
            var command = new System.Text.StringBuilder(commandLine);
            if (Native.CreateProcessW(null, command, IntPtr.Zero, IntPtr.Zero, false, flags, IntPtr.Zero, workingDirectory, ref startup, out var info)) {
                Native.CloseHandle(info.hThread);
                Native.CloseHandle(info.hProcess);
                return info.dwProcessId;
            }
            var error = Marshal.GetLastWin32Error();
            if (!breakaway || error != Native.ErrorAccessDenied) throw new Win32Exception(error);
        }
        throw new IOException("unreachable");
    }

    private static Identity? Read(SafeProcessHandle handle, int pid) {
        if (!Native.GetProcessTimes(handle, out var created, out _, out _, out _)) return null;
        var size = 32768;
        var buffer = new char[size];
        var image = Native.QueryFullProcessImageNameW(handle, 0, buffer, ref size) ? new string(buffer, 0, size) : null;
        return new Identity(pid, DateTime.FromFileTimeUtc(created), image);
    }

    private static bool StillActive(SafeProcessHandle handle) => Native.GetExitCodeProcess(handle, out var code) && code == 259;

    private static int? ParentOf(int pid) {
        using var handle = Native.OpenProcess(Native.QueryLimited, false, (uint)pid);
        if (handle.IsInvalid) return null;
        var info = new Native.ProcessBasicInformation();
        var size = 0;
        return Native.NtQueryInformationProcess(handle, 0, ref info, Marshal.SizeOf(info), ref size) == 0 ? (int)info.InheritedFromUniqueProcessId : null;
    }

    private static class Native {
        public const uint Terminate = 0x0001, QueryLimited = 0x1000, Synchronize = 0x00100000;
        public const int ProcessCommandLineInformation = 60;
        public const int ErrorAccessDenied = 5, ErrorInvalidParameter = 87;
        public const uint CreateNoWindow = 0x08000000, CreateNewProcessGroup = 0x00000200, CreateUnicodeEnvironment = 0x00000400,
            CreateBreakawayFromJob = 0x01000000;

        [StructLayout(LayoutKind.Sequential)]
        public struct UnicodeString { public ushort Length; public ushort MaximumLength; public IntPtr Buffer; }

        [StructLayout(LayoutKind.Sequential)]
        public struct ProcessBasicInformation {
            public IntPtr ExitStatus; public IntPtr PebBaseAddress; public IntPtr AffinityMask; public IntPtr BasePriority;
            public IntPtr UniqueProcessId; public IntPtr InheritedFromUniqueProcessId;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct StartupInfo {
            public int cb; public string? lpReserved; public string? lpDesktop; public string? lpTitle;
            public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
            public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct ProcessInformation { public IntPtr hProcess; public IntPtr hThread; public int dwProcessId; public int dwThreadId; }

        [DllImport("kernel32.dll", SetLastError = true)] public static extern SafeProcessHandle OpenProcess(uint access, bool inherit, uint pid);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetProcessTimes(SafeProcessHandle process, out long creation, out long exit, out long kernel, out long user);
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool QueryFullProcessImageNameW(SafeProcessHandle process, uint flags, [Out] char[] name, ref int size);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool GetExitCodeProcess(SafeProcessHandle process, out uint code);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool TerminateProcess(SafeProcessHandle process, uint exitCode);
        [DllImport("kernel32.dll", SetLastError = true)] public static extern uint WaitForSingleObject(SafeProcessHandle process, uint milliseconds);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool CloseHandle(IntPtr handle);
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool CreateProcessW(string? application, System.Text.StringBuilder commandLine, IntPtr processAttributes, IntPtr threadAttributes,
            bool inheritHandles, uint flags, IntPtr environment, string? currentDirectory, ref StartupInfo startup, out ProcessInformation info);
        [DllImport("ntdll.dll")] public static extern int NtQueryInformationProcess(SafeProcessHandle process, int infoClass, IntPtr info, int size, ref int returned);
        [DllImport("ntdll.dll")] public static extern int NtQueryInformationProcess(SafeProcessHandle process, int infoClass, ref ProcessBasicInformation info, int size, ref int returned);
    }
}
