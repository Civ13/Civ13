namespace Civ13.Launcher.Social;

// A launch ticket fences factory results; it is not wire authentication and must
// not be printed or used as a credential. Exclusive private pipes are the gate.
public sealed record CompanionLaunchTicket(Guid Session, CompanionProfile Profile, int WireVersion = 1);
public interface ICompanionProcessLease : IDisposable {
    Guid Session { get; }
    int WireVersion { get; }
    ICompanionPresenceChannel Channel { get; }
    bool HasExited { get; }
    // True only after child exit AND all owned I/O has settled. Never reuse pipes.
    bool ResourcesSettled { get; }
    void RequestStop();
    void RequestTermination();
}
public interface ICompanionProcessFactory {
    // Only the exact child created for this ticket may be returned/stopped.
    // Once a child exists, cancellation must still return its lease, or the
    // factory must finish cleanup before faulting. All operations return promptly.
    Task<ICompanionProcessLease> StartAsync(CompanionLaunchTicket ticket, CancellationToken cancellation);
}
public enum CompanionHostState { Disabled, Idle, Starting, Running, Stopping, Failed, Quarantined }
public enum CompanionHostFailure { None, StartFailed, Cancelled, StartTimeout, WrongPeer, Exited, ChannelClosed, Clock, Process }

// Pure owner-thread lifecycle; no OS factory, timer, worker or startup hook.
// Keep pumping until IsSettled, even after Stop/opt-out. Optional cleanup must
// never be a prerequisite for manual game access. There is no automatic retry.
public sealed class CompanionProcessHost {
    private readonly CompanionProfile profile;
    private readonly ICompanionProcessFactory factory;
    private readonly TimeProvider clock;
    private readonly Func<Guid> session;
    private readonly int owner = Environment.CurrentManagedThreadId;
    private Task<ICompanionProcessLease>? starting;
    private ICompanionProcessLease? child;
    private CancellationTokenSource? cancellation;
    private CompanionLaunchTicket? ticket;
    private Guid previousSession;
    private long began, previous, stopBegan;
    private bool enabled, stopping, stopSent, terminateSent, clockFailed, disposeAttempted;
    public CompanionHostState State { get; private set; } = CompanionHostState.Disabled;
    public CompanionHostFailure Failure { get; private set; }
    public CompanionProcessHost(CompanionProfile profile, ICompanionProcessFactory factory, TimeProvider clock, Func<Guid>? session = null) {
        ArgumentNullException.ThrowIfNull(profile); ArgumentNullException.ThrowIfNull(factory); ArgumentNullException.ThrowIfNull(clock);
        this.profile = profile; this.factory = factory; this.clock = clock; this.session = session ?? Guid.NewGuid;
    }
    private void Owner() { if (Environment.CurrentManagedThreadId != owner) throw new InvalidOperationException("Companion host owner."); }
    public bool IsSettled { get { Owner(); return starting == null && child == null; } }
    public ICompanionPresenceChannel? Channel { get { Owner(); return State == CompanionHostState.Running ? child!.Channel : null; } }
    public void SetEnabled(bool value) {
        Owner(); enabled = value;
        if (!value) { Stop(); if (IsSettled) State = CompanionHostState.Disabled; }
        else if (IsSettled) State = CompanionHostState.Idle;
    }
    public bool Begin(CancellationToken token = default) {
        Owner(); if (!enabled || !IsSettled || token.IsCancellationRequested) return false;
        var id = session(); if (id == Guid.Empty || id == previousSession) throw new InvalidOperationException("Fresh launch ticket required."); previousSession = id;
        ticket = new(id, profile); began = previous = clock.GetTimestamp(); Failure = CompanionHostFailure.None;
        stopping = stopSent = terminateSent = clockFailed = disposeAttempted = false;
        cancellation = CancellationTokenSource.CreateLinkedTokenSource(token); State = CompanionHostState.Starting;
        try { starting = factory.StartAsync(ticket, cancellation.Token) ?? throw new IOException("Missing startup task."); }
        catch (Exception e) when (e is not OutOfMemoryException) { Failure = CompanionHostFailure.StartFailed; Reap(); return false; }
        return true;
    }
    public void Stop() { Owner(); if (!IsSettled) BeginStop(); else State = enabled ? CompanionHostState.Idle : CompanionHostState.Disabled; }
    private void BeginStop() {
        if (!stopping) {
            stopping = true; stopBegan = clock.GetTimestamp();
            try { cancellation?.Cancel(); } catch (Exception e) when (e is not OutOfMemoryException) { Failure = CompanionHostFailure.Process; }
        }
        State = terminateSent ? CompanionHostState.Quarantined : CompanionHostState.Stopping;
    }
    public void Pump() {
        Owner(); if (IsSettled) return;
        var now = clock.GetTimestamp();
        if (now < previous) { clockFailed = true; Failure = CompanionHostFailure.Clock; BeginStop(); }
        previous = now;
        if (!stopping && cancellation!.IsCancellationRequested) { Failure = CompanionHostFailure.Cancelled; BeginStop(); }
        if (!stopping && starting != null && clock.GetElapsedTime(began, now) >= TimeSpan.FromSeconds(3)) {
            Failure = CompanionHostFailure.StartTimeout; BeginStop();
        }
        if (starting is { IsCompleted: true }) {
            var completed = starting; starting = null;
            try {
                child = completed.GetAwaiter().GetResult() ?? throw new IOException("Missing child lease.");
                if (child.Session != ticket!.Session || child.WireVersion != 1) { Failure = CompanionHostFailure.WrongPeer; BeginStop(); }
                else if (!stopping) State = CompanionHostState.Running;
            } catch (Exception e) when (e is not OutOfMemoryException) {
                if (Failure == CompanionHostFailure.None) Failure = CompanionHostFailure.StartFailed;
                if (child == null) { Reap(); return; } BeginStop();
            }
        }
        if (child == null) return; // Retain ownership of a cancelled/late startup.
        try {
            if (!stopping && child.HasExited) { Failure = CompanionHostFailure.Exited; BeginStop(); }
            if (!stopping && !child.Channel.IsOpen) { Failure = CompanionHostFailure.ChannelClosed; BeginStop(); }
            if (stopping) {
                if (!stopSent) { stopSent = true; child.RequestStop(); }
                var settled = child.HasExited && child.ResourcesSettled;
                if (!settled && !terminateSent && (clockFailed || clock.GetElapsedTime(stopBegan, now) >= TimeSpan.FromMilliseconds(750))) {
                    terminateSent = true; if (!child.HasExited) child.RequestTermination(); State = CompanionHostState.Quarantined;
                }
                if (settled && !disposeAttempted) { disposeAttempted = true; child.Dispose(); child = null; Reap(); }
            }
        } catch (Exception e) when (e is not OutOfMemoryException) {
            Failure = CompanionHostFailure.Process; BeginStop(); State = CompanionHostState.Quarantined;
            if (!terminateSent) { terminateSent = true; try { child?.RequestTermination(); } catch (Exception failure) when (failure is not OutOfMemoryException) { } }
        }
    }
    private void Reap() {
        cancellation?.Dispose(); cancellation = null; ticket = null; stopping = false;
        State = !enabled ? CompanionHostState.Disabled : Failure == CompanionHostFailure.None ? CompanionHostState.Idle : CompanionHostState.Failed;
    }
}
