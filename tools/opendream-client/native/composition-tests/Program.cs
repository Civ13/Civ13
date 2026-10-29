using Civ13.Launcher.Management;
using Civ13.ServerManagement;

var count = 0;
void Check(bool result, string label) { count++; if (!result) throw new Exception(label); }
void Reject(Action action, string label) { bool rejected = false; try { action(); } catch (ContractException) { rejected = true; } Check(rejected, label); }
var binding = new InstanceBinding("20000000-0000-4000-8000-000000000001", "host-a", "profile-a", 1, new string('a', 64), InstanceKind.Process);
var manifest = new InstanceManifest(binding, "Synthetic A", "civ13-byond", "516.1688", null, DesiredState.Running);
var second = manifest with { Binding = binding with { InstanceId = "20000000-0000-4000-8000-000000000002" }, Label = "Synthetic B" };
const string path = @"D:\synthetic\catalog.json";
const long ticks = 638900000000000000;
var target = new ProcessTarget(binding, 42, ticks);
var observation = new LocalProcessObservation(target, "clock-a", 100, 101, EvidenceKind.Present, new ProcessStamp(42, ticks), ProcessReadCode.Present);
var snapshot = new RegistrationSnapshot(path, "clock-a", 100, 101, RegistrationStatus.Available, new InstanceCatalog([manifest, second]));
LocalManagementBatch Compose(RegistrationSnapshot? s = null, IReadOnlyList<SuppliedProcessObservation>? facts = null, string requested = path, string host = "host-a", string scope = "clock-a", long now = 105, long age = 10) =>
    LocalManagementComposition.Compose(s ?? snapshot, facts ?? [new(target, observation)], requested, host, scope, now, age);
string Render(LocalManagementBatch batch, long now = 105) {
    using var output = new StringWriter();
    LocalManagementPresentation.WriteInstances(output, batch.Entries, "host-a", "clock-a", now, 10);
    return output.ToString();
}
var composed = Compose();
Check(composed.Status == RegistrationViewStatus.Available && composed.Entries.Count == 2, "registered cohort composed");
Check(composed.Entries[0].Target == target && composed.Entries[0].Observation == observation, "supplied fact retained exactly");
Check(composed.Entries[1].Target is null && composed.Entries[1].Observation is null, "registration does not manufacture target");
Check(Render(composed).Contains("Ownership and backend readiness are unverified"), "no ownership inferred");
Check(Render(composed).Contains("PID: 42") && Render(composed).Contains("no explicit process target"), "existing renderer receives scoped facts");
Check(Compose(facts: []).Entries.All(x => x.Target is null && x.Observation is null), "no supplied facts remain unknown");
foreach (var status in Enum.GetValues<RegistrationStatus>().Where(x => x != RegistrationStatus.Available)) {
    var result = Compose(snapshot with { Status = status, Catalog = null });
    Check(result.Status.ToString() == status.ToString() && result.Entries.Count == 0, "registration failure distinct");
}
Check(Compose(snapshot with { SourcePath = @"D:\synthetic\other.json" }).Status == RegistrationViewStatus.Invalid, "wrong source not reused");
Check(Compose(snapshot with { Status = RegistrationStatus.Missing, Catalog = null, SourcePath = @"D:\synthetic\other.json" }).Status == RegistrationViewStatus.Invalid, "missing bound to requested source");
Check(Compose(snapshot with { Catalog = null }).Status == RegistrationViewStatus.Invalid, "available requires catalog");
Check(Compose(snapshot with { Status = RegistrationStatus.Denied }).Status == RegistrationViewStatus.Invalid, "failure cannot carry catalog");
Check(Compose(snapshot with { ClockScope = "old" }).Status == RegistrationViewStatus.ClockChanged, "clock scope bound");
Check(Compose(snapshot with { Status = RegistrationStatus.ClockChanged, Catalog = null, CompletedMilliseconds = 99 }).Status == RegistrationViewStatus.ClockChanged, "clock regression preserved");
Check(Compose(snapshot with { SampleMilliseconds = -1 }).Status == RegistrationViewStatus.Invalid, "negative sample");
Check(Compose(snapshot with { CompletedMilliseconds = 106 }).Status == RegistrationViewStatus.Invalid, "future registration");
Check(Compose(now: 111).Status == RegistrationViewStatus.Stale && Compose(now: 111).Entries.Count == 0, "stale catalog withheld");
Check(Compose(now: 110).Status == RegistrationViewStatus.Available, "registration age boundary");
foreach (var item in new[] {
    (EvidenceKind.Missing, ProcessReadCode.PidNotFound, "Registered PID absent"),
    (EvidenceKind.Denied, ProcessReadCode.PermissionDenied, "Inspection denied"),
    (EvidenceKind.Unavailable, ProcessReadCode.LookupFailed, "Inspection unavailable") }) {
    var obs = observation with { Kind = item.Item1, Code = item.Item2, Facts = null };
    var text = Render(Compose(facts: [new(target, obs)]));
    Check(text.Contains(item.Item3) && !text.Contains("PID: 42"), "nonpresent fact preserved conservatively");
}
var staleObs = observation with { SampleMilliseconds = 90, CompletedMilliseconds = 91 };
Check(Render(Compose(facts: [new(target, staleObs)])).Contains("stale-observation"), "observation age not refreshed");
foreach (var item in new[] { (EvidenceKind.Present, ProcessReadCode.Present), (EvidenceKind.Missing, ProcessReadCode.PidNotFound),
    (EvidenceKind.Denied, ProcessReadCode.PermissionDenied), (EvidenceKind.Unavailable, ProcessReadCode.LookupFailed) }) {
    var wrongObs = observation with { Target = target with { Pid = 43 }, Kind = item.Item1, Code = item.Item2,
        Facts = item.Item1 == EvidenceKind.Present ? observation.Facts : null };
    var text = Render(Compose(facts: [new(target, wrongObs)]));
    Check(text.Contains("scope-mismatch") && !text.Contains("PID: 42"), "wrong observation remains unknown for every evidence kind");
}
Check(Render(Compose(facts: [new(target, null)])).Contains("scope-mismatch"), "absent observation remains unknown");
foreach (var changed in new[] { binding with { InstanceId = "20000000-0000-4000-8000-000000000003" }, binding with { HostId = "host-b" },
    binding with { ProfileId = "profile-b" }, binding with { ProfileRevision = 2 }, binding with { ProfileSha256 = new string('b', 64) },
    binding with { Kind = InstanceKind.Shard } })
    Reject(() => Compose(facts: [new(target with { Binding = changed }, observation)]), "foreign target not joined");
Reject(() => Compose(facts: [new(target, observation), new(target, null)]), "duplicate target refused");
Reject(() => Compose(facts: [null!]), "null input refused");
Reject(() => Compose(requested: @"C:\not-local\catalog.json"), "invalid request rejected");
var remote = manifest with { Binding = binding with { HostId = "host-b" } };
var remoteSnapshot = snapshot with { Catalog = new InstanceCatalog([remote]) };
Check(Compose(remoteSnapshot, []).Entries.Single().Target is null, "remote registration remains declaration");
Reject(() => Compose(remoteSnapshot, [new(target with { Binding = remote.Binding }, null)]), "remote facts not treated as local");
var displayClock = new FakeDisplayClock();
string Display(RegistrationSnapshot? s = null, IReadOnlyList<SuppliedProcessObservation>? facts = null,
    long registrationAge = 10, long observationAge = 10, string requested = path) {
    using var output = new StringWriter();
    LocalManagementPresentation.WriteRegisteredInstances(output, s ?? snapshot, facts ?? [new(target, observation)],
        requested, "host-a", displayClock, registrationAge, observationAge);
    return output.ToString();
}
Check(Display().Contains("PID: 42") && Display().Contains("Ownership and backend readiness are unverified"), "current display is scoped and unowned");
foreach (var status in Enum.GetValues<RegistrationStatus>().Where(x => x != RegistrationStatus.Available)) {
    var text = Display(snapshot with { Status = status, Catalog = null });
    Check(text.Contains("Registration status: " + status) && text.Contains("remain unknown") &&
        !text.Contains("No registered instances") && !text.Contains("PID: 42") && !text.Contains(path),
        "failed registration not rendered as empty success or leaked");
}
var empty = snapshot with { Catalog = new InstanceCatalog([]) };
Check(Display(empty, []).Contains("No registered instances were supplied"), "available empty catalog is distinctly empty");
Check(Display(facts: []).Contains("no explicit process target"), "missing target remains unknown");
var cached = Compose();
displayClock.Now = 111;
var expired = Display();
Check(cached.Entries.Count == 2 && expired.Contains("Registration status: Stale") && !expired.Contains("Synthetic A") &&
    !expired.Contains("No registered instances"), "display recomposes rather than treating cached entries as fresh");
displayClock.Now = 110;
Check(Display().Contains("PID: 42"), "registration and observation exact age boundary admitted");
displayClock.Now = 105;
Check(Display(facts: [new(target, staleObs)]).Contains("stale-observation") &&
    !Display(facts: [new(target, staleObs)]).Contains("PID: 42"), "fresh registration does not refresh stale observation");
var missingObservation = observation with { Kind = EvidenceKind.Missing, Code = ProcessReadCode.PidNotFound, Facts = null };
Check(Display(facts: [new(target, missingObservation)]).Contains("Registered PID absent; instance state remains unknown"), "missing observation remains unknown state");
Check(Display(snapshot with { SourcePath = @"D:\synthetic\other.json" }).Contains("Registration status: Invalid"), "wrong registration source rejected");
displayClock.ScopeValue = "other-clock";
Check(Display().Contains("Registration status: ClockChanged"), "changed clock scope reported");
displayClock.ScopeValue = "clock-a"; displayClock.ChangeScopeOnSample = true;
Check(Display().Contains("Registration status: ClockChanged"), "clock change during sample reported");
displayClock.ChangeScopeOnSample = false; displayClock.ScopeValue = "clock-a";
using (var output = new StringWriter()) {
    Reject(() => LocalManagementPresentation.WriteRegisteredInstances(output, snapshot, [new(target, observation)], path,
        "host-a", displayClock, 10, 0), "invalid observation age rejected");
    Check(output.ToString().Length == 0, "invalid context emits no partial display");
}
Console.WriteLine($"PASS {count} composition assertions; synthetic snapshots and observations only.");

sealed class FakeDisplayClock : IProcessObservationClock {
    public string ScopeValue = "clock-a";
    public long Now = 105;
    public bool ChangeScopeOnSample;
    public string Scope => ScopeValue;
    public long Milliseconds { get { if (ChangeScopeOnSample) ScopeValue = "changed"; return Now; } }
}
