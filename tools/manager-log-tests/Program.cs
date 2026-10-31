using System.ComponentModel;
using System.Text;
using Civ13.Launcher.Management;
using Civ13.ServerManagement;

var assertions = 0;
void Check(bool ok, string name) { assertions++; if (!ok) throw new Exception("Registered log: " + name); }
void Reject(Action action, string name) { bool rejected = false; try { action(); } catch (ContractException) { rejected = true; } Check(rejected, name); }
var binding = new InstanceBinding("20000000-0000-4000-8000-000000000001", "host-a", "profile-a", 1, new string('a', 64), InstanceKind.Process);
var manifest = new InstanceManifest(binding, "Synthetic", "civ13-byond", "516.1688", null, DesiredState.Running);
const string path = @"D:\synthetic\catalog.json";
var registration = new RegistrationSnapshot(path, "clock-a", 100, 100, RegistrationStatus.Available, new InstanceCatalog([manifest]));
var request = new LogRequest(binding, "world-log", 4, 8192) { MaximumBytes = 8192 };
var clock = new FakeClock();
var source = new FakeSource();
RegisteredLogResult Read(LogRequest? req = null, RegistrationSnapshot? reg = null, long age = 10000, string host = "host-a", string requested = path) =>
    new RegisteredLogReader(source, clock).Read(reg ?? registration, requested, host, req ?? request, age);
LogView View(RegisteredLogResult result, LogRequest? req = null, long now = 105) =>
    LogProjection.Project(req ?? request, result.Observation, "clock-a", now, 10000);
source.Set("alpha\nbeta\r\n");
var first = Read(); var firstView = View(first);
Check(first.Registration == RegistrationViewStatus.Available && first.Selection == RegisteredLogSelection.Admitted, "explicit registered selection");
Check(firstView.Lines.SequenceEqual(new[] { "alpha", "beta" }) && !firstView.InputTruncated && !firstView.HasMore, "complete LF and CRLF lines");
Check(firstView.NextCursor == new LogCursor(binding, "world-log", "generation-a", 12), "byte cursor after complete lines");
Check(source.Disposals == 1 && source.Opens == 1, "one source disposed");
var single = request with { MaximumLines = 1 };
var page1 = View(Read(single), single);
Check(page1.Lines.SequenceEqual(new[] { "alpha" }) && page1.HasMore && !page1.PendingFragment, "line-count pagination");
var next = single with { Cursor = page1.NextCursor };
var page2 = View(Read(next), next);
Check(page2.Lines.SequenceEqual(new[] { "beta" }) && page2.HasEarlier && !page2.HasMore, "continuation bound to generation");
source.Generation = "generation-b";
var rotated = View(Read(next), next);
Check(rotated.Status == LogViewStatus.ResetRequired && rotated.Lines.Count == 0 && rotated.NextCursor is null, "rotation requires explicit reset");
var reset = View(Read(single), single);
Check(reset.Lines.SequenceEqual(new[] { "alpha" }) && reset.NextCursor!.Generation == "generation-b", "explicit reset starts new generation");
source.Generation = "generation-a";
source.Set("alpha\npartial");
var fragment = View(Read(), request);
Check(fragment.Lines.SequenceEqual(new[] { "alpha" }) && fragment.PendingFragment && fragment.HasMore && fragment.NextCursor!.Offset == 6,
    "unterminated line retained rather than consumed");
var continuation = request with { Cursor = fragment.NextCursor };
source.Set("alpha\npartial\n");
Check(View(Read(continuation), continuation).Lines.SequenceEqual(new[] { "partial" }), "later completed line is not skipped");
source.Set(new string('x', 1025) + "\n");
var clipped = View(Read());
Check(clipped.InputTruncated && !clipped.Truncated && clipped.Lines.Single().Length == 1024 && clipped.NextCursor!.Offset == 1026,
    "oversized input is explicitly clipped and entire completed line consumed");
source.Set(new string('x', 1023) + "\U0001F642\n");
Check(View(Read()).Lines.Single().Length == 1023 && View(Read()).InputTruncated, "input clipping never splits a Unicode scalar");
source.Set("abcdef\n");
var small = request with { MaximumBytes = 4 };
var limited = View(Read(small), small);
Check(limited.Status == LogViewStatus.LimitExceeded && limited.NextCursor is null && limited.Lines.Count == 0, "over-byte-budget incomplete line does not advance");
source.Set("\u20acx\n");
Check(View(Read(small), small).Status == LogViewStatus.LimitExceeded, "UTF-8 split boundary never advances");
Check(View(Read()).Lines.Single() == "\u20acx", "larger retry decodes same line");
source.Bytes = [0xff, (byte)'\n'];
Check(View(Read()).Status == LogViewStatus.Invalid && View(Read()).Lines.Count == 0, "invalid UTF-8 not exposed");
source.Set("one\ntwo\n");
var tiny = request with { MaximumCharacters = 1 };
var rawTiny = Read(tiny);
var projected = View(rawTiny, tiny);
Check(rawTiny.Observation!.NextCursor is not null && projected.Truncated && projected.HasMore && projected.NextCursor is null,
    "render clipping cannot advance cursor over undisplayed text");
var wrongCursor = request with { Cursor = new(binding with { ProfileRevision = 2 }, "world-log", "generation-a", 0) };
var previousOpens = source.Opens;
Reject(() => Read(wrongCursor), "cross-profile cursor refused");
Check(source.Opens == previousOpens, "invalid cursor causes no source open");
var forged = first.Observation! with { NextCursor = new(binding, "other-stream", "generation-a", 12) };
Check(LogProjection.Project(request, forged, "clock-a", 105, 10000).Status == LogViewStatus.Invalid, "foreign continuation refused");
var wrongStreamCursor = request with { Cursor = new(binding, "other-stream", "generation-a", 0) };
Reject(() => Read(wrongStreamCursor), "cross-stream cursor refused");
var priorSessions = source.Sessions;
var otherStream = request with { StreamId = "other-log" };
Check(View(Read(otherStream), otherStream).Status == LogViewStatus.Unavailable && source.Sessions == priorSessions,
    "source rejects unconfigured stream before opening a session");
foreach (var changed in new[] { binding with { InstanceId = "20000000-0000-4000-8000-000000000002" }, binding with { ProfileId = "profile-b" },
    binding with { ProfileRevision = 2 }, binding with { ProfileSha256 = new string('b', 64) }, binding with { Kind = InstanceKind.Shard } }) {
    var before = source.Opens;
    Check(Read(request with { Binding = changed }).Selection == RegisteredLogSelection.NotRegistered && source.Opens == before,
        "wrong instance/profile never opens source");
}
var prior = source.Opens;
Check(Read(request with { Binding = binding with { HostId = "host-b" } }).Selection == RegisteredLogSelection.NotLocal && source.Opens == prior,
    "remote host never opened");
Check(Read(reg: registration with { Status = RegistrationStatus.Denied, Catalog = null }).Registration == RegistrationViewStatus.Denied && source.Opens == prior,
    "denied registration remains distinct and opens nothing");
Check(Read(age: 4).Registration == RegistrationViewStatus.Stale && source.Opens == prior, "stale registration opens nothing");
Check(Read(requested: @"D:\synthetic\other.json").Registration == RegistrationViewStatus.Invalid && source.Opens == prior, "wrong source path opens nothing");
source.OpenError = new FileNotFoundException("private");
Check(View(Read()).Status == LogViewStatus.Missing, "initial source missing");
source.OpenError = new UnauthorizedAccessException("private");
Check(View(Read()).Status == LogViewStatus.Denied, "access denial distinct");
source.OpenError = new IOException("private");
Check(View(Read()).Status == LogViewStatus.Unavailable, "open error sanitized");
source.OpenError = new Win32Exception(OperatingSystem.IsWindows() ? 5 : 13);
Check(View(Read()).Status == (OperatingSystem.IsWindows() || OperatingSystem.IsLinux() ? LogViewStatus.Denied : LogViewStatus.Unavailable),
    "platform access denial is distinguished where supported");
source.OpenError = null; source.ReadError = new FileNotFoundException("private");
Check(View(Read()).Status == LogViewStatus.Unavailable, "late missing is unavailable");
source.ReadError = null; source.WrongStamp = true;
Check(View(Read()).Status == LogViewStatus.Invalid, "wrong source identity withheld");
source.WrongStamp = false; source.BadRead = true;
Check(View(Read()).Status == LogViewStatus.Unavailable, "invalid reader count withheld");
source.BadRead = false; source.OnRead = () => clock.Now = 1200;
var slow = Read(age: 10000);
Check(LogProjection.Project(request, slow.Observation, "clock-a", 1200, 10000).Status == LogViewStatus.ReadTooSlow,
    "slow source does not produce lines");
clock.Now = 105; source.OnRead = () => clock.Now = 111;
Check(Read(age: 10).Registration == RegistrationViewStatus.Stale, "registration must remain fresh through read");
clock.Now = 105; source.OnRead = () => clock.Scope = "clock-b";
Check(Read().Registration == RegistrationViewStatus.ClockChanged, "clock change during read withheld");
source.OnRead = null; clock.Scope = "clock-a"; clock.Now = 105;
source.Set("abc\n"); source.GenerationOnSecondCapture = "generation-b";
var changing = request with { Cursor = new(binding, "world-log", "generation-a", 0) };
Check(View(Read(changing), changing).Status == LogViewStatus.ResetRequired, "rotation during read discards page");
source.GenerationOnSecondCapture = null;
source.LengthOnSecondCapture = 3;
Check(View(Read(changing), changing).Status == LogViewStatus.ResetRequired, "shrink during read discards page");
source.LengthOnSecondCapture = null;
source.ChunkLimit = 1;
Check(View(Read()).Lines.SequenceEqual(new[] { "abc" }), "bounded short reads are reassembled");
source.Set(new string('x', 300) + "\n");
Check(View(Read()).Status == LogViewStatus.Unavailable, "short-read call cap stops unbounded source");
source.ChunkLimit = int.MaxValue;

// The only disk fixture is a unique file created by this test itself in the temp directory.
var fixturePath = Path.Combine(Path.GetTempPath(), "civ13-synthetic-log-" + Guid.NewGuid().ToString("N") + ".txt");
var fixtureCreated = false;
try {
    using (var writer = new FileStream(fixturePath, FileMode.CreateNew, FileAccess.Write, FileShare.None)) {
        fixtureCreated = true;
        var contents = Encoding.UTF8.GetBytes("own fixture\n"); writer.Write(contents);
    }
    var own = new FileFixtureSource(fixturePath);
    var fromDisk = new RegisteredLogReader(own, clock).Read(registration, path, "host-a", request, 10000);
    Check(View(fromDisk).Lines.SequenceEqual(new[] { "own fixture" }), "owned synthetic file through injected source");
} finally { if (fixtureCreated) File.Delete(fixturePath); }
Console.WriteLine($"PASS {assertions} registered-log reader assertions; injected sources and one owned synthetic temporary file only.");

sealed class FakeClock : IProcessObservationClock { public string Scope { get; set; } = "clock-a"; public long Now = 105; public long Milliseconds => Now; }
sealed class FileFixtureSource(string path) : IRegisteredLogSource {
    public IRegisteredLogSession Open(InstanceBinding binding, string streamId) => new Session(path, binding, streamId);
    private sealed class Session(string path, InstanceBinding binding, string streamId) : IRegisteredLogSession {
        private readonly FileStream file = new(path, FileMode.Open, FileAccess.Read, FileShare.Read);
        public LogSourceStamp Capture() => new(binding, streamId, "fixture-generation", file.Length);
        public int Read(long offset, byte[] destination, int destinationOffset, int count) {
            file.Position = offset; return file.Read(destination, destinationOffset, count);
        }
        public void Dispose() => file.Dispose();
    }
}
