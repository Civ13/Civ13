using System.ComponentModel;
using Civ13.ServerManagement;

internal static class LocalProcessObservationTests {
    private sealed class Accessor(Func<int, IProcessReadSession> open) : IProcessAccessor {
        public int Calls;
        public IProcessReadSession Open(int pid) { Calls++; return open(pid); }
    }
    private sealed class Session(Func<int, ProcessStamp> stamp) : IProcessReadSession {
        public int Reads, Disposals;
        public ProcessStamp ReadStamp() => stamp(++Reads);
        public void Dispose() => Disposals++;
    }
    private sealed class Clock : IProcessObservationClock {
        public string Scope { get; set; } = "observer-a";
        public long Now = 100;
        public long Milliseconds => Now;
    }
    private sealed class Reader(Func<int, ProcessReadResult> read) : IProcessFactsReader {
        public int Calls;
        public ProcessReadResult Read(int pid) { Calls++; return read(pid); }
    }
    public static int Run() {
        var count = 0;
        void Check(bool ok, string name) { count++; if (!ok) throw new Exception("Process fact contract failed: " + name); }
        void Reject(Action action, string name) {
            var rejected = false; try { action(); } catch (ContractException) { rejected = true; }
            Check(rejected, name);
        }
        var facts = new ProcessStamp(42, 1000);
        var session = new Session(_ => facts); var accessor = new Accessor(_ => session);
        var actualAlgorithm = new ProcessFactsReader(accessor);
        var present = actualAlgorithm.Read(42);
        Check(present == new ProcessReadResult(EvidenceKind.Present, facts, ProcessReadCode.Present), "two equal read-only samples are present");
        Check(accessor.Calls == 1 && session.Reads == 2 && session.Disposals == 1, "one explicit PID session is always disposed");
        foreach (var pid in new[] { 0, -1 }) Reject(() => actualAlgorithm.Read(pid), "invalid PID rejected before open");
        Check(accessor.Calls == 1, "invalid PID has no OS-accessor call");
        foreach (var exception in new Exception[] { new ArgumentException("synthetic missing"), new UnauthorizedAccessException("private text"),
            new Win32Exception(123), new InvalidOperationException("private text"), new IOException("private path"), new PlatformNotSupportedException() }) {
            var fake = new Accessor(_ => throw exception); var result = new ProcessFactsReader(fake).Read(42);
            var expected = exception is ArgumentException ? EvidenceKind.Missing : exception is UnauthorizedAccessException ? EvidenceKind.Denied : EvidenceKind.Unavailable;
            Check(result.Kind == expected && result.Facts is null && fake.Calls == 1, "open failure classified without retry or exception text");
        }
        foreach (var exception in new Exception[] { new ArgumentException(), new UnauthorizedAccessException(), new Win32Exception(123),
            new InvalidOperationException(), new IOException(), new PlatformNotSupportedException() }) {
            var late = new Session(i => i == 1 ? facts : throw exception);
            var result = new ProcessFactsReader(new Accessor(_ => late)).Read(42);
            Check(result.Kind == (exception is UnauthorizedAccessException ? EvidenceKind.Denied : EvidenceKind.Unavailable), "late query failure never asserts missing");
            Check(late.Disposals == 1, "failed read releases only its query session");
        }
        foreach (var changed in new[] { facts with { Pid = 43 }, facts with { StartTimeUtcTicks = 1001 }, facts with { HasExited = true } }) {
            var raced = new Session(i => i == 1 ? facts : changed);
            var result = new ProcessFactsReader(new Accessor(_ => raced)).Read(42);
            Check(result.Kind == EvidenceKind.Unavailable && result.Code == ProcessReadCode.ChangedDuringRead && raced.Disposals == 1,
                "PID/start/exit change during inspection is uncertainty");
        }
        foreach (var invalid in new[] { facts with { Pid = 43 }, facts with { StartTimeUtcTicks = 0 }, facts with { StartTimeUtcTicks = long.MaxValue } }) {
            var result = new ProcessFactsReader(new Accessor(_ => new Session(_ => invalid))).Read(42);
            Check(result.Code == ProcessReadCode.InvalidFacts && result.Facts is null, "invalid or wrong requested PID facts refused");
        }
        var binding = new InstanceBinding("20000000-0000-4000-8000-000000000001", "host-a", "profile-a", 1, new string('a', 64), InstanceKind.Process);
        var manifest = new InstanceManifest(binding, "Synthetic instance", "civ13-byond", "516.1688", null, DesiredState.Running);
        var target = new ProcessTarget(binding, 42, 1000);
        var clock = new Clock(); var reader = new Reader(_ => present);
        var observer = new LocalProcessObserver("host-a", reader, clock, 10);
        var observation = observer.Observe(manifest, target);
        ProcessFactView View(LocalProcessObservation? sample, long now = 105, long age = 10, ProcessTarget? request = null) =>
            ProcessFactProjection.Project(manifest, request ?? target, sample, "observer-a", now, age);
        Check(View(observation).Match == ProcessFactMatch.MatchingStart && View(observation).Desired == DesiredState.Running,
            "matching facts preserve desired state without ownership/readiness claim");
        Check(View(observation with { Facts = facts with { StartTimeUtcTicks = 1001 } }).Match == ProcessFactMatch.DifferentStart, "recycled PID does not match registration");
        foreach (var other in new[] { binding with { InstanceId = "20000000-0000-4000-8000-000000000002" },
            binding with { HostId = "host-b" }, binding with { ProfileId = "profile-b" }, binding with { ProfileRevision = 2 },
            binding with { ProfileSha256 = new string('b', 64) }, binding with { Kind = InstanceKind.Shard } }) {
            Reject(() => observer.Observe(manifest, target with { Binding = other }), "wrong request scope refused before IO");
            foreach (var kind in Enum.GetValues<EvidenceKind>()) {
                var code = kind switch { EvidenceKind.Present => ProcessReadCode.Present, EvidenceKind.Missing => ProcessReadCode.PidNotFound,
                    EvidenceKind.Denied => ProcessReadCode.PermissionDenied, _ => ProcessReadCode.LookupFailed };
                var sample = observation with { Target = target with { Binding = other }, Kind = kind,
                    Code = code, Facts = kind == EvidenceKind.Present ? facts : null };
                Check(View(sample).Evidence is null, "every evidence kind including absence is instance/host/profile bound");
            }
        }
        var calls = reader.Calls;
        var remote = manifest with { Binding = binding with { HostId = "host-b" } };
        Reject(() => observer.Observe(remote, target with { Binding = remote.Binding }), "nonlocal registered host rejected");
        foreach (var bad in new[] { target with { Pid = 0 }, target with { ExpectedStartTimeUtcTicks = 0 }, target with { ExpectedStartTimeUtcTicks = long.MaxValue } })
            Reject(() => observer.Observe(manifest, bad), "invalid target before IO");
        Check(reader.Calls == calls, "scope/target rejection invokes no process read");
        foreach (var result in new[] { new ProcessReadResult(EvidenceKind.Missing, null, ProcessReadCode.PidNotFound),
            new ProcessReadResult(EvidenceKind.Denied, null, ProcessReadCode.PermissionDenied),
            new ProcessReadResult(EvidenceKind.Unavailable, null, ProcessReadCode.LookupFailed) }) {
            var sample = new LocalProcessObserver("host-a", new Reader(_ => result), clock).Observe(manifest, target);
            Check(sample.Target == target && sample.Kind == result.Kind && View(sample).Evidence == result.Kind, "missing/denied/unavailable remain distinct and request-bound");
            Check(View(sample).Match == (result.Kind == EvidenceKind.Missing ? ProcessFactMatch.Missing : ProcessFactMatch.Unknown), "absence is PID absence, not instance stopped");
        }
        foreach (var corrupt in new[] { new ProcessReadResult(EvidenceKind.Present, null, ProcessReadCode.Present),
            present with { Facts = facts with { Pid = 43 } }, present with { Code = ProcessReadCode.PidNotFound },
            new ProcessReadResult(EvidenceKind.Missing, facts, ProcessReadCode.PidNotFound),
            present with { Kind = (EvidenceKind)99 }, present with { Code = (ProcessReadCode)99 }, null! }) {
            var sample = new LocalProcessObserver("host-a", new Reader(_ => corrupt), clock).Observe(manifest, target);
            Check(sample.Kind == EvidenceKind.Unavailable && sample.Code == ProcessReadCode.InvalidReaderEvidence && sample.Facts is null, "malformed reader output fails closed");
        }
        foreach (var altered in new[] { observation with { ClockScope = "other-clock" }, observation with { SampleMilliseconds = -1 },
            observation with { CompletedMilliseconds = 99 }, observation with { CompletedMilliseconds = 106 },
            observation with { Target = target with { Pid = 43 } }, observation with { Target = target with { ExpectedStartTimeUtcTicks = 1001 } },
            observation with { Kind = EvidenceKind.Denied }, observation with { Code = (ProcessReadCode)99 } })
            Check(View(altered).Evidence is null, "stale/contradictory/scoped display evidence is unknown");
        Check(View(null).Match == ProcessFactMatch.Unknown, "missing observation unknown");
        Check(View(observation, now: 111).Reason == "stale-observation", "sample age is never renewed by projection");
        Check(View(observation, now: 110).Match == ProcessFactMatch.MatchingStart, "exact freshness boundary admitted");
        var slowClock = new Clock();
        var slow = new LocalProcessObserver("host-a", new Reader(_ => { slowClock.Now = 111; return present; }), slowClock, 10).Observe(manifest, target);
        Check(slow.Kind == EvidenceKind.Unavailable && slow.Code == ProcessReadCode.ReadTooSlow && slow.SampleMilliseconds == 100,
            "slow completed read keeps original start and is not admitted");
        foreach (var changeScope in new[] { false, true }) {
            var unstableClock = new Clock();
            var sample = new LocalProcessObserver("host-a", new Reader(_ => {
                if (changeScope) unstableClock.Scope = "new-clock"; else unstableClock.Now = 99;
                return present;
            }), unstableClock).Observe(manifest, target);
            Check(sample.Kind == EvidenceKind.Unavailable && sample.Code == ProcessReadCode.ClockChanged && sample.Facts is null, "clock restart/regression cannot freshen facts");
        }
        foreach (var badClock in new[] { new Clock { Scope = "" }, new Clock { Now = -1 } }) {
            var noRead = new Reader(_ => present);
            Reject(() => new LocalProcessObserver("host-a", noRead, badClock).Observe(manifest, target), "bad initial clock rejected");
            Check(noRead.Calls == 0, "bad clock avoids inspection");
        }
        foreach (var desired in Enum.GetValues<DesiredState>())
            Check(ProcessFactProjection.Project(manifest with { Desired = desired }, target, observation, "observer-a", 105, 10).Desired == desired,
                "desired never overwrites OS facts");
        Console.WriteLine($"PASS {count} process-fact assertions; injected sessions/clocks only, no real process inspection.");
        return count;
    }
}
