using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;
using System.Security.Cryptography;
using System.Security.Principal;
using System.Text;
using Microsoft.Win32.SafeHandles;

namespace Civ13.Launcher.Social;

internal sealed class WindowsCompanionPlatform : ICompanionWindowsPlatform {
    internal static (int Startup, int Security, int Limits, int ProcessInfo) Layout =>
        (Marshal.SizeOf<Native.StartupEx>(), Marshal.SizeOf<Native.Security>(), Marshal.SizeOf<Native.ExtendedLimits>(), Marshal.SizeOf<Native.ProcessInfo>());
    // Source-only milestone: no public or configuration path enables OS calls.
    private static readonly bool NativeActivation = false;
    public IDisposable LockVerifiedImage(CompanionExecutable executable) {
        if (!NativeActivation || !OperatingSystem.IsWindows() || RuntimeInformation.ProcessArchitecture != Architecture.X64)
            throw new InvalidOperationException("Native process/pipe activation disabled.");
        var path = Path.GetFullPath(executable.Path);
        for (var part = path; part != null; part = Path.GetDirectoryName(part))
            if ((File.GetAttributes(part) & FileAttributes.ReparsePoint) != 0) throw new IOException("Reparse image path refused.");
        var file = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        try {
            var digest = SHA256.HashData(file);
            if (!CryptographicOperations.FixedTimeEquals(digest, Convert.FromHexString(executable.Sha256))) throw new IOException("Image identity mismatch.");
            file.Position = 0;
            using var reader = new BinaryReader(file, Encoding.UTF8, leaveOpen: true);
            if (reader.ReadUInt16() != 0x5a4d || file.Length < 64) throw new IOException("Image format.");
            file.Position = 60; var offset = reader.ReadInt32();
            if (offset < 64 || offset > file.Length - 24) throw new IOException("Image bounds.");
            file.Position = offset;
            if (reader.ReadUInt32() != 0x4550 || reader.ReadUInt16() != 0x8664) throw new IOException("x64 image required.");
            return file; // Deny writes/deletion through CreateProcess completion.
        } catch { file.Dispose(); throw; }
    }
    public async Task<ICompanionPipePair> CreatePipesAsync(CancellationToken cancellation) {
        if (!NativeActivation || !OperatingSystem.IsWindows() || RuntimeInformation.ProcessArchitecture != Architecture.X64)
            throw new InvalidOperationException("Native process/pipe activation disabled.");
        var pair = new WindowsPipePair();
        try { await pair.Connect(cancellation).ConfigureAwait(false); }
        catch (Exception e) when (e is not OutOfMemoryException) { pair.Reject(); }
        return pair; // Partial ownership is retained even after cancelled connect.
    }
    public ICompanionOwnedChild CreateSuspended(CompanionExecutable executable, CompanionLaunchTicket ticket, ICompanionPipePair pipes) {
        if (!NativeActivation || !OperatingSystem.IsWindows() || RuntimeInformation.ProcessArchitecture != Architecture.X64)
            throw new InvalidOperationException("Native process/pipe activation disabled.");
        if (pipes is not WindowsPipePair pair || !pair.Ready) throw new IOException("Owned Windows pipe pair required.");
        return WindowsOwnedChild.Create(executable, ticket, pair);
    }

    [SupportedOSPlatform("windows")]
    private sealed class WindowsPipePair : ICompanionPipePair {
        private NamedPipeServerStream? from, to;
        internal NamedPipeClientStream? ChildOut, ChildIn;
        private bool rejected, childCloseAttempted, closeAttempted, closeFailed;
        private readonly Dictionary<PipeStream, SafePipeHandle> knownHandles = new();
        private readonly HashSet<PipeStream> closedStreams = [];
        public bool Ready { get; private set; }
        public Stream FromChild => from ?? throw new IOException("Missing input pipe.");
        public Stream ToChild => to ?? throw new IOException("Missing output pipe.");
        public bool Closed => !closeFailed && ClosedPipe(from) && ClosedPipe(to) && ClosedPipe(ChildOut) && ClosedPipe(ChildIn);
        private bool ClosedPipe(PipeStream? pipe) => pipe == null || closedStreams.Contains(pipe) || (knownHandles.TryGetValue(pipe, out var handle) && handle.IsClosed);
        public async Task Connect(CancellationToken cancellation) {
            cancellation.ThrowIfCancellationRequested();
            var inbound = "civ13-social-" + Guid.NewGuid().ToString("N");
            var outbound = "civ13-social-" + Guid.NewGuid().ToString("N");
            from = new(inbound, PipeDirection.In, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly, 4096, 4096);
            knownHandles.Add(from, from.SafePipeHandle);
            to = new(outbound, PipeDirection.Out, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous | PipeOptions.CurrentUserOnly, 4096, 4096);
            knownHandles.Add(to, to.SafePipeHandle);
            ChildOut = new(".", inbound, PipeDirection.Out, PipeOptions.Asynchronous, TokenImpersonationLevel.None, HandleInheritability.Inheritable);
            ChildIn = new(".", outbound, PipeDirection.In, PipeOptions.Asynchronous, TokenImpersonationLevel.None, HandleInheritability.Inheritable);
            await Task.WhenAll(from.WaitForConnectionAsync(cancellation), to.WaitForConnectionAsync(cancellation),
                ChildOut.ConnectAsync(cancellation), ChildIn.ConnectAsync(cancellation)).ConfigureAwait(false);
            knownHandles.Add(ChildIn, ChildIn.SafePipeHandle); knownHandles.Add(ChildOut, ChildOut.SafePipeHandle);
            if (!from.IsAsync || !to.IsAsync || !ChildOut.IsAsync || !ChildIn.IsAsync ||
                !Native.GetNamedPipeClientProcessId(from.SafePipeHandle, out var fromPid) || fromPid != Environment.ProcessId ||
                !Native.GetNamedPipeClientProcessId(to.SafePipeHandle, out var toPid) || toPid != Environment.ProcessId ||
                !Native.GetNamedPipeServerProcessId(ChildIn.SafePipeHandle, out var inPid) || inPid != Environment.ProcessId ||
                !Native.GetNamedPipeServerProcessId(ChildOut.SafePipeHandle, out var outPid) || outPid != Environment.ProcessId ||
                !Native.GetHandleInformation(from.SafePipeHandle, out var fromFlags) || (fromFlags & 1) != 0 ||
                !Native.GetHandleInformation(to.SafePipeHandle, out var toFlags) || (toFlags & 1) != 0)
                throw new IOException("Pipe pairing/async identity mismatch.");
            Ready = !rejected;
        }
        public void Reject() { rejected = true; Ready = false; try { Dispose(); } catch (Exception e) when (e is not OutOfMemoryException) { closeFailed = true; } }
        public void CloseChildEnds() {
            if (childCloseAttempted) return; childCloseAttempted = true;
            Close(ChildIn); Close(ChildOut);
            if (closeFailed) throw new IOException("Child pipe close unproven.");
        }
        private void Close(PipeStream? pipe) {
            if (pipe == null || ClosedPipe(pipe)) return;
            try { pipe.Dispose(); closedStreams.Add(pipe); } catch (Exception e) when (e is not OutOfMemoryException) { closeFailed = true; }
        }
        public void Dispose() {
            if (closeAttempted) return; closeAttempted = true; Ready = false;
            Close(from); Close(to); CloseChildEnds();
            if (closeFailed) throw new IOException("Pipe close unproven.");
        }
    }

    private sealed class OwnedHandle : SafeHandleZeroOrMinusOneIsInvalid {
        private bool released;
        internal bool Closed => IsClosed && (IsInvalid || released);
        internal OwnedHandle() : base(true) { }
        internal OwnedHandle(nint handle) : base(true) { SetHandle(handle); }
        protected override bool ReleaseHandle() { released = Native.CloseHandle(handle); return released; }
    }
    [SupportedOSPlatform("windows")]
    private sealed class WindowsOwnedChild : ICompanionOwnedChild {
        private OwnedHandle? process, thread, job, stderr;
        private bool resumeAttempted, terminateAttempted, disposed, knownExited, creationFailed;
        public bool HasExited {
            get {
                if (knownExited || process == null || process.IsInvalid) return true;
                if (process.IsClosed) throw new IOException("Process handle closed before exit proof.");
                var status = Native.WaitForSingleObject(process, 0);
                if (status == 0) { knownExited = true; return true; }
                if (status != 0x102) throw new IOException("Owned process exit query failed.");
                return false;
            }
        }
        public bool Closed => (process == null || process.Closed) && (thread == null || thread.Closed) && (job == null || job.Closed) && (stderr == null || stderr.Closed);
        internal static WindowsOwnedChild Create(CompanionExecutable executable, CompanionLaunchTicket ticket, WindowsPipePair pipes) {
            var child = new WindowsOwnedChild();
            nint attributes = 0, handles = 0, environment = 0; bool initialized = false;
            var retained = new List<SafeHandle>();
            try {
                child.job = Native.CreateJobObject(0, null);
                if (child.job.IsInvalid) throw new IOException("Job creation failed.");
                var limits = new Native.ExtendedLimits(); limits.Basic.LimitFlags = 0x2008; limits.Basic.ActiveProcessLimit = 1;
                if (!Native.SetInformationJobObject(child.job, 9, ref limits, (uint)Marshal.SizeOf<Native.ExtendedLimits>())) throw new IOException("Job limits failed.");
                var security = new Native.Security { Length = Marshal.SizeOf<Native.Security>(), Inherit = true };
                child.stderr = Native.CreateFile("NUL", 0x40000000, 3, ref security, 3, 0, 0);
                if (child.stderr.IsInvalid) throw new IOException("Stderr discard failed.");
                var list = new SafeHandle[] { pipes.ChildIn!.SafePipeHandle, pipes.ChildOut!.SafePipeHandle, child.stderr };
                foreach (var handle in list) {
                    var added = false; handle.DangerousAddRef(ref added); if (added) retained.Add(handle);
                    if (!Native.GetHandleInformation(handle, out var flags) || (flags & 1) == 0) throw new IOException("Inherited handle identity failed.");
                }
                nuint bytes = 0; Native.InitializeProcThreadAttributeList(0, 1, 0, ref bytes);
                if (bytes == 0 || bytes > 65536) throw new IOException("Attribute bounds.");
                attributes = Marshal.AllocHGlobal(checked((nint)bytes));
                if (!Native.InitializeProcThreadAttributeList(attributes, 1, 0, ref bytes)) throw new IOException("Attribute creation failed."); initialized = true;
                handles = Marshal.AllocHGlobal(3 * nint.Size);
                for (var i = 0; i < 3; i++) Marshal.WriteIntPtr(handles, i * nint.Size, list[i].DangerousGetHandle());
                if (!Native.UpdateProcThreadAttribute(attributes, 0, 0x20002, handles, (nuint)(3 * nint.Size), 0, 0)) throw new IOException("Handle-list setup failed.");
                var startup = new Native.StartupEx(); startup.Info.Size = (uint)Marshal.SizeOf<Native.StartupEx>();
                startup.Info.Flags = 0x100; startup.Info.Input = list[0].DangerousGetHandle(); startup.Info.Output = list[1].DangerousGetHandle();
                startup.Info.Error = list[2].DangerousGetHandle(); startup.Attributes = attributes;
                var plan = CompanionLaunchPlan.Create(executable, ticket, Environment.GetFolderPath(Environment.SpecialFolder.Windows), Path.GetTempPath());
                environment = Marshal.StringToHGlobalUni(plan.EnvironmentBlock);
                var command = new StringBuilder(plan.CommandLine);
                if (!Native.CreateProcess(executable.Path, command, 0, 0, true, 0x08080404, environment, Path.GetDirectoryName(executable.Path)!, ref startup, out var info))
                    throw new IOException("Suspended child creation failed.");
                child.process = new(info.Process); child.thread = new(info.Thread);
                return child;
            } catch (Exception error) when (error is not OutOfMemoryException) {
                // Even pre-process job/stderr ownership is returned to the lease:
                // an uncertain handle close must not silently release admission.
                child.creationFailed = true;
                return child;
            } finally {
                if (initialized) Native.DeleteProcThreadAttributeList(attributes);
                if (attributes != 0) Marshal.FreeHGlobal(attributes); if (handles != 0) Marshal.FreeHGlobal(handles);
                if (environment != 0) Marshal.FreeHGlobal(environment);
                foreach (var handle in retained) handle.DangerousRelease();
            }
        }
        public void ContainAndResume(CancellationToken cancellation) {
            if (creationFailed || resumeAttempted || process == null || thread == null || job == null) throw new IOException("Owned suspended child required.");
            resumeAttempted = true;
            cancellation.ThrowIfCancellationRequested();
            if (!Native.AssignProcessToJobObject(job, process)) throw new IOException("Job assignment failed.");
            cancellation.ThrowIfCancellationRequested();
            if (Native.ResumeThread(thread) != 1) throw new IOException("Single resume failed.");
        }
        public void Terminate() {
            if (terminateAttempted) return; terminateAttempted = true;
            if (!HasExited && !Native.TerminateProcess(process!, 1) && !HasExited) throw new IOException("Owned termination unproven.");
        }
        public void Dispose() {
            if (disposed) return;
            if (!HasExited) throw new InvalidOperationException("Owned child still running."); disposed = true;
            thread?.Dispose(); process?.Dispose(); job?.Dispose(); stderr?.Dispose();
        }
    }

    private static class Native {
        [StructLayout(LayoutKind.Sequential)] internal struct Security { internal int Length; internal nint Descriptor; [MarshalAs(UnmanagedType.Bool)] internal bool Inherit; }
        [StructLayout(LayoutKind.Sequential)] internal struct Startup {
            internal uint Size; internal nint Reserved, Desktop, Title; internal uint X, Y, Width, Height, CharsX, CharsY, Fill, Flags;
            internal ushort Show, ReservedBytes; internal nint ReservedData, Input, Output, Error;
        }
        [StructLayout(LayoutKind.Sequential)] internal struct StartupEx { internal Startup Info; internal nint Attributes; }
        [StructLayout(LayoutKind.Sequential)] internal struct ProcessInfo { internal nint Process, Thread; internal uint ProcessId, ThreadId; }
        [StructLayout(LayoutKind.Sequential)] internal struct BasicLimits { internal long ProcessTime, JobTime; internal uint LimitFlags; internal nuint MinWorkingSet, MaxWorkingSet; internal uint ActiveProcessLimit; internal nuint Affinity; internal uint Priority, Scheduling; }
        [StructLayout(LayoutKind.Sequential)] internal struct IoCounters { internal ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes; }
        [StructLayout(LayoutKind.Sequential)] internal struct ExtendedLimits { internal BasicLimits Basic; internal IoCounters Io; internal nuint ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory; }
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool CloseHandle(nint handle);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern uint WaitForSingleObject(SafeHandle handle, uint milliseconds);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool GetNamedPipeClientProcessId(SafePipeHandle pipe, out uint processId);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool GetNamedPipeServerProcessId(SafePipeHandle pipe, out uint processId);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool GetHandleInformation(SafeHandle handle, out uint flags);
        [DllImport("kernel32.dll", EntryPoint = "CreateJobObjectW", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern OwnedHandle CreateJobObject(nint security, string? name);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool SetInformationJobObject(SafeHandle job, int kind, ref ExtendedLimits limits, uint size);
        [DllImport("kernel32.dll", EntryPoint = "CreateFileW", CharSet = CharSet.Unicode, SetLastError = true)] internal static extern OwnedHandle CreateFile(string name, uint access, uint share, ref Security security, uint creation, uint flags, nint template);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool InitializeProcThreadAttributeList(nint list, uint count, uint flags, ref nuint size);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool UpdateProcThreadAttribute(nint list, uint flags, nuint attribute, nint value, nuint size, nint previous, nint returnedSize);
        [DllImport("kernel32.dll")] internal static extern void DeleteProcThreadAttributeList(nint list);
        [DllImport("kernel32.dll", EntryPoint = "CreateProcessW", CharSet = CharSet.Unicode, SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool CreateProcess(string application, StringBuilder command, nint processSecurity, nint threadSecurity, [MarshalAs(UnmanagedType.Bool)] bool inherit, uint flags, nint environment, string directory, ref StartupEx startup, out ProcessInfo process);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool AssignProcessToJobObject(SafeHandle job, SafeHandle process);
        [DllImport("kernel32.dll", SetLastError = true)] internal static extern uint ResumeThread(SafeHandle thread);
        [DllImport("kernel32.dll", SetLastError = true)] [return: MarshalAs(UnmanagedType.Bool)] internal static extern bool TerminateProcess(SafeHandle process, uint exitCode);
    }
}
