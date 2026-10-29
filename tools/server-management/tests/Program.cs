using System.Text.Json.Nodes;
using Civ13.ServerManagement;

var assertions = 0;
void Check(bool condition, string name) {
    assertions++;
    if (!condition) throw new Exception("Failed: " + name);
}
void Reject(Action action, string name) {
    var refused = false;
    try { action(); } catch (ContractException) { refused = true; }
    Check(refused, name);
}
using var stream = System.Reflection.Assembly.GetExecutingAssembly().GetManifestResourceStream("instance.example.json");
using var reader = new StreamReader(stream ?? throw new Exception("Missing embedded example"));
var json = reader.ReadToEnd();
var manifest = ManifestJson.ReadManifest(json);
string Change(string key, JsonNode? value) {
    var node = JsonNode.Parse(json)!.AsObject();
    node[key] = value;
    return node.ToJsonString();
}
Check(manifest.Binding.Kind == InstanceKind.Process && manifest.Desired == DesiredState.Stopped, "embedded example decodes");
foreach (var pair in new (string, JsonNode?)[] {
    ("schema", JsonValue.Create("future")), ("instanceId", JsonValue.Create("zone-1")),
    ("instanceId", JsonValue.Create(Guid.Empty.ToString("D"))), ("hostId", JsonValue.Create("host/path")),
    ("profileId", JsonValue.Create("")), ("profileRevision", JsonValue.Create(0)),
    ("profileRevision", JsonValue.Create(1.5)), ("profileRevision", JsonValue.Create("1")),
    ("profileSha256", JsonValue.Create(new string('A', 64))), ("profileSha256", JsonValue.Create("bad")),
    ("kind", JsonValue.Create("logical-zone")), ("kind", JsonValue.Create("map-layer")),
    ("backend", JsonValue.Create("unrelated-game")), ("runtimeVersion", JsonValue.Create("latest")),
    ("runtimeVersion", JsonValue.Create("516.1688;command")), ("registration", JsonValue.Create("owned")),
    ("desired", JsonValue.Create("restart")), ("shardGroupId", JsonValue.Create("group-a")),
    ("label", JsonValue.Create("secret\ncontrol")), ("label", JsonValue.Create(new string('x', 97))),
    ("label", null), ("profileId", null), ("kind", JsonValue.Create(1))
}) Reject(() => ManifestJson.ReadManifest(Change(pair.Item1, pair.Item2)), "malformed manifest rejected: " + pair.Item1);
var shard = JsonNode.Parse(Change("kind", JsonValue.Create("shard")))!.AsObject();
Reject(() => ManifestJson.ReadManifest(shard.ToJsonString()), "shard requires explicit group");
shard["shardGroupId"] = "group-a";
Check(ManifestJson.ReadManifest(shard.ToJsonString()).Binding.Kind == InstanceKind.Shard, "shard is explicit process metadata");
var removed = JsonNode.Parse(json)!.AsObject();
removed.Remove("hostId");
Reject(() => ManifestJson.ReadManifest(removed.ToJsonString()), "missing field rejected");
Reject(() => ManifestJson.ReadManifest(Change("privatePath", JsonValue.Create("not-accepted"))), "unknown fields cannot smuggle config");
Reject(() => ManifestJson.ReadManifest(json.Replace("\"schema\":", "\"schema\":\"civ13.instance.v1\",\"schema\":")), "duplicate key rejected");
Reject(() => ManifestJson.ReadManifest(json.Replace("\"schema\":", "\"SCHEMA\":\"civ13.instance.v1\",\"schema\":")), "case alias rejected");
foreach (var malformed in new[] { "null", "[]", "{", "{\"schema\":1}", "[" + new string('[', 12) + "]" })
    Reject(() => ManifestJson.ReadManifest(malformed), "malformed JSON/object/depth rejected");
Reject(() => ManifestJson.ReadManifest(new string(' ', ManifestJson.MaximumManifestBytes + 1)), "byte limit enforced");
Reject(() => ManifestJson.ReadManifest(new string('é', ManifestJson.MaximumManifestBytes)), "UTF8 byte bound enforced");
var catalogJson = "{\"schema\":\"civ13.catalog.v1\",\"instances\":[" + json + "]}";
Check(ManifestJson.ReadCatalog(catalogJson).Instances.Count == 1, "catalog parses");
Reject(() => ManifestJson.ReadCatalog(catalogJson.Replace("civ13.catalog.v1", "future")), "unknown catalog schema rejected");
Reject(() => ManifestJson.ReadCatalog("{\"schema\":\"civ13.catalog.v1\",\"instances\":null}"), "catalog requires array");
Reject(() => ManifestJson.ReadCatalog("{\"schema\":\"civ13.catalog.v1\",\"instances\":[" + json + "," + json + "]}"), "duplicate catalog instance rejected");
Reject(() => ManifestJson.ReadCatalog(new string(' ', ManifestJson.MaximumCatalogBytes + 1)), "catalog byte limit enforced");
var many = Enumerable.Range(0, InstanceCatalog.MaximumInstances).Select(i => manifest with {
    Binding = manifest.Binding with { InstanceId = $"00000000-0000-4000-8000-{i + 1:000000000000}" }
}).ToList();
var catalog = new InstanceCatalog(many);
Check(catalog.Instances.Count == InstanceCatalog.MaximumInstances, "capacity boundary admitted");
many.Add(manifest);
Reject(() => new InstanceCatalog(many), "capacity exceeded rejected");
many.Clear();
Check(catalog.Instances.Count == InstanceCatalog.MaximumInstances, "catalog detached from caller list");
Reject(() => new InstanceCatalog(new[] { manifest, manifest }), "duplicate typed catalog rejected");
Reject(() => new InstanceCatalog(null!), "null typed catalog input refused");
Reject(() => new InstanceCatalog(new InstanceManifest[] { null! }), "null typed instance refused");
Reject(() => (manifest with { Binding = null! }).Validate(), "null typed binding refused");
Reject(() => ManifestJson.ReadManifest(json.Replace("Example Civ13 instance", "\\uD800")), "invalid Unicode string refused with stable error");

var identity = new ProcessIdentity("boot-a", 123, "start-a", new string('b', 64), "run-a");
var present = new Observation(manifest.Binding, identity, "collector-a", 1000, EvidenceKind.Present, identity, false);
StatusView View(Observation? observation, long now = 1050) =>
    StatusProjection.Project(manifest, identity, observation, "collector-a", now, 100);
Check(View(null).Observed == ObservedState.Unknown, "no observation is unknown");
Check(View(present).Observed == ObservedState.AliveUnready, "presence does not establish readiness");
Check(View(present with { BackendReady = true }).Observed == ObservedState.Ready, "backend readiness is explicit supplied evidence");
foreach (var kind in Enum.GetValues<EvidenceKind>()) {
    var observation = kind == EvidenceKind.Present ? present : present with { Kind = kind, ObservedIdentity = null };
    var foreignBindings = new[] {
        manifest.Binding with { InstanceId = "22222222-2222-4222-8222-222222222222" },
        manifest.Binding with { HostId = "host-b" }, manifest.Binding with { ProfileId = "profile-b" },
        manifest.Binding with { ProfileRevision = 2 }, manifest.Binding with { ProfileSha256 = new string('c', 64) },
        manifest.Binding with { Kind = InstanceKind.Shard }
    };
    foreach (var binding in foreignBindings)
        Check(View(observation with { Binding = binding }).Reason == "observation-scope-mismatch", "every evidence kind binds full instance scope");
    Check(View(observation with { ExpectedIdentity = identity with { Pid = 124 } }).Reason == "observation-scope-mismatch", "every kind binds requested receipt identity");
    Check(View(observation with { ClockScope = "collector-b" }).Reason == "clock-scope-changed", "every kind binds collector clock");
    Check(View(observation, now: 1101).Reason == "stale-observation", "every kind rejects stale evidence");
}
Check(View(present with { Kind = EvidenceKind.Missing, ObservedIdentity = null }).Observed == ObservedState.Stopped, "receipt-bound explicit absence is stopped");
Check(View(present with { Kind = EvidenceKind.Denied, ObservedIdentity = null }).Reason == "inspection-denied", "denied remains unknown");
Check(View(present with { Kind = EvidenceKind.Unavailable, ObservedIdentity = null }).Reason == "inspection-unavailable", "unavailable remains unknown");
Check(View(present, 1100).Observed == ObservedState.AliveUnready, "freshness boundary admitted");
Check(View(present, long.MaxValue).Reason == "stale-observation", "age cannot overflow");
foreach (var sample in new[] { -1L, 1051L })
    Check(View(present with { SampleMilliseconds = sample }).Reason == "invalid-sample-time", "invalid sample time refused");
foreach (var changed in new[] { identity with { BootId = "boot-b" }, identity with { Pid = 124 },
    identity with { StartToken = "recycled" }, identity with { ExecutableSha256 = new string('c', 64) }, identity with { RunId = "run-b" } })
    Check(View(present with { ObservedIdentity = changed, BackendReady = true }).Observed == ObservedState.Held, "recycled or changed observed process held");
Check(View(present with { Kind = EvidenceKind.Missing }).Reason == "contradictory-observation", "missing cannot carry a found process");
Check(View(present with { Kind = EvidenceKind.Denied, ObservedIdentity = null, BackendReady = true }).Reason == "contradictory-observation", "denied cannot assert ready");
Check(View(present with { Kind = (EvidenceKind)99 }).Reason == "invalid-evidence-kind", "invalid evidence kind refused");
Check(View(present with { ObservedIdentity = identity with { Pid = 0 } }).Reason == "invalid-observed-identity", "malformed observed identity refused");
Check(View(present with { ObservedIdentity = null }).Reason == "invalid-observed-identity", "present needs identity");
var external = present with { ExpectedIdentity = null, BackendReady = true };
Check(StatusProjection.Project(manifest, null, external, "collector-a", 1050, 100).Receipt == ReceiptMatch.External, "external process not adopted");
Check(StatusProjection.Project(manifest, null, external with { Kind = EvidenceKind.Missing, ObservedIdentity = null, BackendReady = false },
    "collector-a", 1050, 100).Reason == "absence-without-receipt", "unowned absence cannot assert instance stopped");
foreach (var desired in Enum.GetValues<DesiredState>()) {
    var view = StatusProjection.Project(manifest with { Desired = desired }, identity, present with { BackendReady = true }, "collector-a", 1050, 100);
    Check(view.Desired == desired && view.Observed == ObservedState.Ready, "desired does not overwrite observed");
}
foreach (var context in new[] { (Scope: "", Now: 0L, Age: 1L), (Scope: "collector-a", Now: -1L, Age: 1L),
    (Scope: "collector-a", Now: 0L, Age: 0L) })
    Reject(() => StatusProjection.Project(manifest, identity, present, context.Scope, context.Now, context.Age), "invalid clock context refused");
Check(StatusProjection.Project(manifest, identity with { BootId = "" }, null, "collector-a", 1050, 100).Reason == "invalid-expected-identity", "invalid receipt refused");
Reject(() => StatusProjection.Project(null!, identity, present, "collector-a", 1050, 100), "null manifest refused");
assertions += TransferContractTests.Run();
Console.WriteLine($"PASS {assertions} offline server-management assertions; synthetic manifests and evidence only.");
