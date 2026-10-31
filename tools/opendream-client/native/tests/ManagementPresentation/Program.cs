using System.Globalization;
using Civ13.Launcher.Management;
using Civ13.ServerManagement;

var assertions = 0;
void Check(bool ok, string name) { assertions++; if (!ok) throw new Exception("Presentation failed: " + name); }
void Reject(Action action, string name) {
    var rejected = false; try { action(); } catch (ContractException) { rejected = true; }
    Check(rejected, name);
}
var binding = new InstanceBinding("20000000-0000-4000-8000-000000000001", "host-a", "profile-a", 1, new string('a', 64), InstanceKind.Process);
var manifest = new InstanceManifest(binding, "Synthetic local world", "civ13-byond", "516.1688", null, DesiredState.Running);
const long ticks = 638900000000000000;
var target = new ProcessTarget(binding, 42, ticks);
var observation = new LocalProcessObservation(target, "collector-a", 100, 102, EvidenceKind.Present, new ProcessStamp(42, ticks), ProcessReadCode.Present);
var entry = new LocalManagementEntry(manifest, target, observation);
string Render(IReadOnlyList<LocalManagementEntry>? rows = null, string host = "host-a", string scope = "collector-a", long now = 105, long age = 10) {
    using var output = new StringWriter(CultureInfo.InvariantCulture);
    LocalManagementPresentation.WriteInstances(output, rows ?? [entry], host, scope, now, age);
    return output.ToString();
}
var text = Render();
Check(text.Contains("start time matches registration", StringComparison.Ordinal), "scoped current facts displayed");
Check(text.Contains("PID: 42", StringComparison.Ordinal) && text.Contains(new DateTime(ticks, DateTimeKind.Utc).ToString("O", CultureInfo.InvariantCulture), StringComparison.Ordinal), "admitted PID and UTC start displayed");
Check(text.Contains("Desired: Running", StringComparison.Ordinal) && text.Contains("Ownership and backend readiness are unverified", StringComparison.Ordinal), "desired/facts do not grant ownership/readiness");
Check(text.Contains("No controls or automatic refresh", StringComparison.Ordinal), "display is an unwired read-only boundary");
Check(Render([]).Contains("No registered instances were supplied", StringComparison.Ordinal), "empty supplied catalog does not claim no real servers exist");
Check(Render([entry with { Target = null }]).Contains("no explicit process target", StringComparison.Ordinal), "observations cannot manufacture registration");
Check(!Render([entry with { Target = null }]).Contains("PID: 42", StringComparison.Ordinal), "unregistered facts are not disclosed as admitted");
var reused = entry with { Observation = observation with { Facts = new ProcessStamp(42, ticks + 1) } };
Check(Render([reused]).Contains("differs from registration", StringComparison.Ordinal), "PID reuse remains a mismatch");
foreach (var item in new[] {
    (EvidenceKind.Missing, ProcessReadCode.PidNotFound, "Registered PID absent"),
    (EvidenceKind.Denied, ProcessReadCode.PermissionDenied, "Inspection denied"),
    (EvidenceKind.Unavailable, ProcessReadCode.LookupFailed, "Inspection unavailable") }) {
    var output = Render([entry with { Observation = observation with { Kind = item.Item1, Code = item.Item2, Facts = null } }]);
    Check(output.Contains(item.Item3, StringComparison.Ordinal) && output.Contains("instance state remains unknown", StringComparison.Ordinal), "nonpresent evidence remains distinct and conservative");
    Check(!output.Contains("PID: 42", StringComparison.Ordinal), "nonpresent evidence has no admitted process details");
}
foreach (var changed in new[] { binding with { InstanceId = "20000000-0000-4000-8000-000000000002" }, binding with { HostId = "host-b" },
    binding with { ProfileId = "profile-b" }, binding with { ProfileRevision = 2 }, binding with { ProfileSha256 = new string('b', 64) },
    binding with { Kind = InstanceKind.Shard } }) {
    foreach (var kind in Enum.GetValues<EvidenceKind>()) {
        var code = kind switch { EvidenceKind.Present => ProcessReadCode.Present, EvidenceKind.Missing => ProcessReadCode.PidNotFound,
            EvidenceKind.Denied => ProcessReadCode.PermissionDenied, _ => ProcessReadCode.LookupFailed };
        var wrong = observation with { Target = target with { Binding = changed }, Kind = kind, Code = code, Facts = kind == EvidenceKind.Present ? observation.Facts : null };
        var output = Render([entry with { Observation = wrong }]);
        Check(output.Contains("scope-mismatch", StringComparison.Ordinal) && !output.Contains("PID: 42", StringComparison.Ordinal), "every evidence kind is instance/host/profile bound before details render");
    }
}
var remoteBinding = binding with { HostId = "host-b" };
var remoteTarget = target with { Binding = remoteBinding };
var remote = entry with { Manifest = manifest with { Binding = remoteBinding }, Target = remoteTarget, Observation = observation with { Target = remoteTarget } };
Check(Render([remote]).Contains("outside this local view", StringComparison.Ordinal), "hostname/provider identity is never assumed local");
Check(!Render([remote]).Contains("PID: 42", StringComparison.Ordinal), "nonlocal facts are withheld even if supplied");
foreach (var malformed in new[] {
    observation with { ClockScope = "prior-collector" }, observation with { SampleMilliseconds = -1 },
    observation with { CompletedMilliseconds = 106 }, observation with { Facts = new ProcessStamp(43, ticks) },
    observation with { Kind = EvidenceKind.Missing }, observation with { Code = (ProcessReadCode)99 } })
    Check(!Render([entry with { Observation = malformed }]).Contains("PID: 42", StringComparison.Ordinal), "malformed/future/clock-changed evidence never emits process details");
Check(Render(now: 111).Contains("stale-observation", StringComparison.Ordinal), "rendering never renews original sample age");
Check(!Render(now: 111).Contains("PID: 42", StringComparison.Ordinal), "stale details withheld");
Check(Render(now: 110).Contains("PID: 42", StringComparison.Ordinal), "exact age boundary admitted");
Check(Render([entry with { Observation = null }]).Contains("scope-mismatch", StringComparison.Ordinal), "missing observation remains unknown");
foreach (var desired in Enum.GetValues<DesiredState>()) {
    var output = Render([entry with { Manifest = manifest with { Desired = desired } }]);
    Check(output.Contains("Desired: " + desired, StringComparison.Ordinal) && output.Contains("start time matches", StringComparison.Ordinal), "desired does not rewrite facts");
}
var shardBinding = binding with { Kind = InstanceKind.Shard };
var shardTarget = target with { Binding = shardBinding };
var shard = entry with { Manifest = manifest with { Binding = shardBinding, ShardGroupId = "group-a" }, Target = shardTarget, Observation = observation with { Target = shardTarget } };
Check(Render([shard]).Contains("Kind: Shard | Group: group-a", StringComparison.Ordinal), "explicit process shard profile remains distinct from logical zones");
foreach (var badRows in new IReadOnlyList<LocalManagementEntry>[] { [entry, entry], [entry, entry with { Manifest = manifest with { Label = "bad\nlabel" } }],
    [null!], [entry with { Target = target with { Pid = 0 } }], Enumerable.Repeat(entry, 129).ToArray() }) {
    using var output = new StringWriter();
    Reject(() => LocalManagementPresentation.WriteInstances(output, badRows, "host-a", "collector-a", 105, 10), "invalid cohort rejected");
    Check(output.ToString().Length == 0, "invalid cohort emits no partial display");
}
foreach (var context in new[] { (Host: "", Scope: "collector-a", Now: 105L, Age: 10L), (Host: "host/path", Scope: "collector-a", Now: 105L, Age: 10L),
    (Host: "host-a", Scope: "", Now: 105L, Age: 10L), (Host: "host-a", Scope: "collector-a", Now: -1L, Age: 10L),
    (Host: "host-a", Scope: "collector-a", Now: 105L, Age: 0L) })
    Reject(() => Render(host: context.Host, scope: context.Scope, now: context.Now, age: context.Age), "invalid display context rejected");
assertions += await RegisteredInstancesCommandTests.Run();
Console.WriteLine($"PASS {assertions} launcher management presentation assertions; supplied fake facts only, no discovery, process reader, network or runtime configuration.");
