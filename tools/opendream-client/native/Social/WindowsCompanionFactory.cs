namespace Civ13.Launcher.Social;

public sealed class CompanionExecutable {
    public string Path { get; }
    public string Sha256 { get; }
    public CompanionExecutable(string path, string sha256) {
        ArgumentNullException.ThrowIfNull(path); ArgumentNullException.ThrowIfNull(sha256);
        // Local absolute Windows image only. No shell, URL, UNC path or arguments.
        if (path.Length < 7 || path.Length > 240 || !char.IsAsciiLetter(path[0]) || path[1] != ':' || path[2] != '\\' ||
            path[3..].Split('\\').Any(p => p.Length == 0 || p is "." or ".." || p.EndsWith('.') || p.EndsWith(' ')) ||
            path[2..].Any(c => char.IsControl(c) || c is '"' or '%' or '!' or '|' or '<' or '>' or ':' or '/' or '*' or '?') ||
            !path.EndsWith(".exe", StringComparison.OrdinalIgnoreCase) || sha256.Length != 64 || !sha256.All(Uri.IsHexDigit))
            throw new ArgumentException("Explicit local executable and SHA256 required.");
        Path = path; Sha256 = sha256.ToLowerInvariant();
    }
}

internal interface ICompanionPipePair : IDisposable {
    bool Ready { get; }
    Stream FromChild { get; }
    Stream ToChild { get; }
    bool Closed { get; }
    void CloseChildEnds();
}
internal interface ICompanionOwnedChild : IDisposable {
    bool HasExited { get; }
    bool Closed { get; }
    void ContainAndResume(CancellationToken cancellation);
    void Terminate();
}
internal interface ICompanionWindowsPlatform {
    IDisposable LockVerifiedImage(CompanionExecutable executable);
    Task<ICompanionPipePair> CreatePipesAsync(CancellationToken cancellation);
    ICompanionOwnedChild CreateSuspended(CompanionExecutable executable, CompanionLaunchTicket ticket, ICompanionPipePair pipes);
}

// Public construction is permanently inactive in this source milestone. The
// enabled constructor is internal and exercised only with an injected fake OS.
public sealed class WindowsCompanionFactory : ICompanionProcessFactory {
    private readonly CompanionExecutable executable;
    private readonly TimeProvider clock;
    private readonly ICompanionWindowsPlatform platform;
    private readonly bool enabled;
    private readonly Func<Func<Task<ICompanionProcessLease>>, Task<ICompanionProcessLease>> schedule;
    private int claimed;
    public WindowsCompanionFactory(CompanionExecutable executable, TimeProvider clock)
        : this(executable, clock, new WindowsCompanionPlatform(), false) { }
    internal WindowsCompanionFactory(CompanionExecutable executable, TimeProvider clock, ICompanionWindowsPlatform platform, bool enabled,
        Func<Func<Task<ICompanionProcessLease>>, Task<ICompanionProcessLease>>? schedule = null) {
        ArgumentNullException.ThrowIfNull(executable); ArgumentNullException.ThrowIfNull(clock); ArgumentNullException.ThrowIfNull(platform);
        this.executable = executable; this.clock = clock; this.platform = platform; this.enabled = enabled;
        this.schedule = schedule ?? (work => Task.Run(work));
    }
    public Task<ICompanionProcessLease> StartAsync(CompanionLaunchTicket ticket, CancellationToken cancellation) {
        ArgumentNullException.ThrowIfNull(ticket);
        if (!enabled) return Task.FromException<ICompanionProcessLease>(new InvalidOperationException("Native companion activation disabled."));
        if (ticket.Session == Guid.Empty || ticket.Profile == null || ticket.WireVersion != 1) return Task.FromException<ICompanionProcessLease>(new ArgumentException("Launch ticket/version."));
        if (cancellation.IsCancellationRequested) return Task.FromCanceled<ICompanionProcessLease>(cancellation);
        if (Interlocked.CompareExchange(ref claimed, 1, 0) != 0) return Task.FromException<ICompanionProcessLease>(new InvalidOperationException("Prior process/pipe ownership unsettled."));
        return schedule(() => StartCore(ticket, cancellation));
    }
    private async Task<ICompanionProcessLease> StartCore(CompanionLaunchTicket ticket, CancellationToken cancellation) {
        var lease = new Lease(ticket, () => Volatile.Write(ref claimed, 0));
        try {
            cancellation.ThrowIfCancellationRequested();
            lease.Image = platform.LockVerifiedImage(executable);
            cancellation.ThrowIfCancellationRequested();
            lease.Pipes = await platform.CreatePipesAsync(cancellation).ConfigureAwait(false);
            if (!lease.Pipes.Ready) throw new IOException("Private pipe construction did not settle ready.");
            lease.Io = new(lease.Pipes.FromChild, lease.Pipes.ToChild, clock);
            cancellation.ThrowIfCancellationRequested();
            lease.Process = platform.CreateSuspended(executable, ticket, lease.Pipes);
            cancellation.ThrowIfCancellationRequested();
            lease.Process.ContainAndResume(cancellation);
            lease.Pipes.CloseChildEnds();
            lease.CloseImage();
            return lease;
        } catch (Exception error) when (error is not OutOfMemoryException) {
            // An owned child/partial pipe pair is returned if cleanup is not
            // proven complete. A fault must never hide live resources from Host.
            lease.RequestStop(); lease.RequestTermination();
            if (lease.ResourcesSettled) {
                lease.Dispose();
                throw new IOException("Companion startup failed after owned cleanup.");
            }
            return lease;
        }
    }
    private sealed class ClosedChannel : ICompanionPresenceChannel {
        public bool IsOpen => false;
        public int Read(Span<byte> output) => 0;
        public bool TryWrite(ReadOnlySpan<byte> bytes) => false;
        public void Dispose() { }
    }
    private sealed class Lease(CompanionLaunchTicket ticket, Action release) : ICompanionProcessLease {
        internal ICompanionPipePair? Pipes;
        internal ICompanionOwnedChild? Process;
        internal BoundedStreamCompanionChannel? Io;
        internal IDisposable? Image;
        private readonly ClosedChannel closed = new();
        private bool stopped, terminated, disposed, uncertain, imageCloseAttempted;
        internal void CloseImage() {
            if (imageCloseAttempted || Image == null) return; imageCloseAttempted = true;
            try { Image.Dispose(); Image = null; } catch { uncertain = true; throw; }
        }
        public Guid Session => ticket.Session;
        public int WireVersion => 1;
        public ICompanionPresenceChannel Channel => Io is { IsOpen: true } && !stopped ? Io : closed;
        public bool HasExited => Process == null || Process.HasExited;
        public bool ResourcesSettled => !uncertain && Image == null && HasExited && (Io == null || Io.IsSettled) && (Pipes == null || Pipes.Closed);
        public void RequestStop() {
            if (stopped) return; stopped = true;
            try { Io?.Dispose(); } catch (Exception e) when (e is not OutOfMemoryException) { uncertain = true; }
            try { Pipes?.Dispose(); } catch (Exception e) when (e is not OutOfMemoryException) { uncertain = true; }
            try { CloseImage(); } catch (Exception e) when (e is not OutOfMemoryException) { uncertain = true; }
        }
        public void RequestTermination() {
            if (terminated) return; terminated = true;
            try { if (Process != null && !Process.HasExited) Process.Terminate(); }
            catch (Exception e) when (e is not OutOfMemoryException) { uncertain = true; }
        }
        public void Dispose() {
            if (disposed) return;
            if (!ResourcesSettled) throw new InvalidOperationException("Owned process/pipe resources unsettled.");
            disposed = true;
            try { Process?.Dispose(); if (Process != null && !Process.Closed) throw new IOException("Owned handles not closed."); }
            catch (Exception e) when (e is not OutOfMemoryException) { uncertain = true; throw; }
            release();
        }
    }
}
