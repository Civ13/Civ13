using System.ComponentModel;
using System.Diagnostics;

namespace Civ13.ServerManagement;

// Operator-selected display target, never a launch receipt, lease or ownership grant.
public sealed record ProcessTarget(InstanceBinding Binding, int Pid, long ExpectedStartTimeUtcTicks) {
    public void Validate() {
        if (Binding is null) throw new ContractException("missing-process-binding");
        Binding.Validate();
        InstanceBinding.Require(Pid > 0 && ExpectedStartTimeUtcTicks > 0 &&
            ExpectedStartTimeUtcTicks <= DateTime.MaxValue.Ticks, "invalid-process-target");
    }
}
public sealed record ProcessStamp(int Pid, long StartTimeUtcTicks, bool HasExited = false) {
    internal bool IsValid => Pid > 0 && StartTimeUtcTicks > 0 && StartTimeUtcTicks <= DateTime.MaxValue.Ticks && !HasExited;
}
public enum ProcessReadCode { Present, PidNotFound, PermissionDenied, LookupFailed, ChangedDuringRead,
    InvalidFacts, UnsupportedPlatform, InvalidReaderEvidence, ClockChanged, ReadTooSlow }
public sealed record ProcessReadResult(EvidenceKind Kind, ProcessStamp? Facts, ProcessReadCode Code);
public interface IProcessFactsReader { ProcessReadResult Read(int pid); }
public interface IProcessReadSession : IDisposable { ProcessStamp ReadStamp(); }
public interface IProcessAccessor { IProcessReadSession Open(int pid); }

// Only read APIs, for one explicitly requested PID. Construction performs no inspection.
// Tests supply IProcessAccessor doubles and never construct an OS process session.
public sealed class SystemProcessAccessor : IProcessAccessor {
    public IProcessReadSession Open(int pid) {
        if (!OperatingSystem.IsWindows() && !OperatingSystem.IsLinux()) throw new PlatformNotSupportedException();
        return TranslatePermission(() => new Session(Process.GetProcessById(pid)));
    }
    private static T TranslatePermission<T>(Func<T> read) {
        try { return read(); }
        catch (Win32Exception e) when (OperatingSystem.IsWindows() ? e.NativeErrorCode == 5 : e.NativeErrorCode is 1 or 13) {
            throw new UnauthorizedAccessException(); // Do not expose OS messages or process paths.
        }
    }
    private sealed class Session(Process process) : IProcessReadSession {
        public ProcessStamp ReadStamp() => TranslatePermission(() => {
            process.Refresh();
            return process.HasExited ? new ProcessStamp(process.Id, 0, true) :
                new ProcessStamp(process.Id, process.StartTime.ToUniversalTime().Ticks);
        });
        public void Dispose() => process.Dispose(); // Releases this query object, never the target process.
    }
}

public sealed class ProcessFactsReader(IProcessAccessor accessor) : IProcessFactsReader {
    private readonly IProcessAccessor source = accessor ?? throw new ArgumentNullException(nameof(accessor));
    public ProcessReadResult Read(int pid) {
        InstanceBinding.Require(pid > 0, "invalid-process-pid");
        try {
            IProcessReadSession session;
            try { session = source.Open(pid); }
            catch (ArgumentException) { return new(EvidenceKind.Missing, null, ProcessReadCode.PidNotFound); }
            using (session) {
                var first = session.ReadStamp(); var second = session.ReadStamp();
                if (first.HasExited || second.HasExited || first != second)
                    return new(EvidenceKind.Unavailable, null, ProcessReadCode.ChangedDuringRead);
                if (!first.IsValid || first.Pid != pid)
                    return new(EvidenceKind.Unavailable, null, ProcessReadCode.InvalidFacts);
                return new(EvidenceKind.Present, first, ProcessReadCode.Present);
            }
        } catch (UnauthorizedAccessException) { return new(EvidenceKind.Denied, null, ProcessReadCode.PermissionDenied); }
        catch (NotSupportedException) { return new(EvidenceKind.Unavailable, null, ProcessReadCode.UnsupportedPlatform); }
        catch (Exception e) when (e is Win32Exception or InvalidOperationException or ArgumentException or IOException) {
            // A later exit/query failure is uncertainty, not confirmed initial PID absence.
            return new(EvidenceKind.Unavailable, null, ProcessReadCode.LookupFailed);
        }
    }
}

public interface IProcessObservationClock {
    string Scope { get; }
    long Milliseconds { get; }
}
public sealed class MonotonicProcessObservationClock : IProcessObservationClock {
    public string Scope { get; } = Guid.NewGuid().ToString("N");
    public long Milliseconds => Environment.TickCount64;
}
public sealed record LocalProcessObservation(ProcessTarget Target, string ClockScope, long SampleMilliseconds,
    long CompletedMilliseconds, EvidenceKind Kind, ProcessStamp? Facts, ProcessReadCode Code);

// No enumeration, discovery, adoption, readiness or implicit host-name resolution.
public sealed class LocalProcessObserver {
    private readonly string hostId;
    private readonly IProcessFactsReader reader;
    private readonly IProcessObservationClock clock;
    private readonly long maximumReadMilliseconds;
    public LocalProcessObserver(string localHostId, IProcessFactsReader reader, IProcessObservationClock clock,
        long maximumReadMilliseconds = 1000) {
        InstanceBinding.Require(InstanceBinding.Token(localHostId), "invalid-local-host");
        InstanceBinding.Require(maximumReadMilliseconds is > 0 and <= 5000, "invalid-read-budget");
        hostId = localHostId; this.reader = reader ?? throw new ArgumentNullException(nameof(reader));
        this.clock = clock ?? throw new ArgumentNullException(nameof(clock)); this.maximumReadMilliseconds = maximumReadMilliseconds;
    }
    public LocalProcessObservation Observe(InstanceManifest manifest, ProcessTarget target) {
        if (manifest is null || target is null) throw new ContractException("missing-process-request");
        manifest.Validate(); target.Validate();
        InstanceBinding.Require(target.Binding == manifest.Binding, "process-request-scope-mismatch");
        InstanceBinding.Require(target.Binding.HostId == hostId, "process-request-not-local");
        var scope = clock.Scope; var start = clock.Milliseconds;
        InstanceBinding.Require(InstanceBinding.Token(scope) && start >= 0, "invalid-observer-clock");
        var read = reader.Read(target.Pid);
        var end = clock.Milliseconds;
        if (scope != clock.Scope || end < start)
            return new(target, scope, start, end, EvidenceKind.Unavailable, null, ProcessReadCode.ClockChanged);
        if (end - start > maximumReadMilliseconds)
            return new(target, scope, start, end, EvidenceKind.Unavailable, null, ProcessReadCode.ReadTooSlow);
        if (!ValidRead(read, target.Pid))
            return new(target, scope, start, end, EvidenceKind.Unavailable, null, ProcessReadCode.InvalidReaderEvidence);
        return new(target, scope, start, end, read.Kind, read.Facts, read.Code);
    }
    internal static bool ValidRead(ProcessReadResult? read, int pid) => read is not null && (read.Kind switch {
        EvidenceKind.Present => read.Code == ProcessReadCode.Present && read.Facts is { IsValid: true } && read.Facts.Pid == pid,
        EvidenceKind.Missing => read.Code == ProcessReadCode.PidNotFound && read.Facts is null,
        EvidenceKind.Denied => read.Code == ProcessReadCode.PermissionDenied && read.Facts is null,
        EvidenceKind.Unavailable => read.Facts is null && read.Code is ProcessReadCode.LookupFailed or
            ProcessReadCode.ChangedDuringRead or ProcessReadCode.InvalidFacts or ProcessReadCode.UnsupportedPlatform or
            ProcessReadCode.InvalidReaderEvidence or ProcessReadCode.ClockChanged or ProcessReadCode.ReadTooSlow,
        _ => false
    });
}

public enum ProcessFactMatch { Unknown, Missing, MatchingStart, DifferentStart }
public sealed record ProcessFactView(DesiredState Desired, EvidenceKind? Evidence, ProcessFactMatch Match, string Reason);
public static class ProcessFactProjection {
    public static ProcessFactView Project(InstanceManifest manifest, ProcessTarget target, LocalProcessObservation? observation,
        string clockScope, long nowMilliseconds, long maximumAgeMilliseconds) {
        if (manifest is null || target is null) throw new ContractException("missing-process-request");
        manifest.Validate(); target.Validate();
        InstanceBinding.Require(InstanceBinding.Token(clockScope) && nowMilliseconds >= 0 && maximumAgeMilliseconds > 0,
            "invalid-clock-context");
        ProcessFactView Unknown(string reason) => new(manifest.Desired, null, ProcessFactMatch.Unknown, reason);
        if (target.Binding != manifest.Binding || observation is null || observation.Target != target) return Unknown("process-observation-scope-mismatch");
        if (observation.ClockScope != clockScope) return Unknown("clock-scope-changed");
        if (observation.SampleMilliseconds < 0 || observation.CompletedMilliseconds < observation.SampleMilliseconds ||
            observation.CompletedMilliseconds > nowMilliseconds) return Unknown("invalid-sample-time");
        if (nowMilliseconds - observation.SampleMilliseconds > maximumAgeMilliseconds) return Unknown("stale-observation");
        if (!LocalProcessObserver.ValidRead(new(observation.Kind, observation.Facts, observation.Code), target.Pid))
            return Unknown("invalid-process-evidence");
        if (observation.Kind != EvidenceKind.Present) return new(manifest.Desired, observation.Kind,
            observation.Kind == EvidenceKind.Missing ? ProcessFactMatch.Missing : ProcessFactMatch.Unknown, observation.Code.ToString());
        return new(manifest.Desired, EvidenceKind.Present,
            observation.Facts!.StartTimeUtcTicks == target.ExpectedStartTimeUtcTicks ? ProcessFactMatch.MatchingStart : ProcessFactMatch.DifferentStart,
            "os-facts-only-ownership-and-readiness-unverified");
    }
}
