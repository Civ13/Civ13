# Persistent native areas and spawn registries

Native topology persistence supports the existing Gaia and Nomads Europe
durable profiles. It records native area membership and the five spawn
registries; it does not implement sharding or transfer custody. The separately
merged optional geographic elevation component is independent of native zones.

## Representations and format

Native zones are `/area` instances, one per turf. Type, name and instance
identity differ. Named landmarks register turf references then usually delete
themselves; they cannot own persistent spawn state. The mutable registries are
`latejoin_turfs`, `newplayer_start`, `latejoin`, `paradrop_landmarks` and
`supplydrop_turfs`. Paradrop registers in two lists; battle royale consumes named
destinations; supply rockets temporarily modify supplydrop destinations. Named
groups also serve NPCs, supply and teleporters. FOB structures and squad/job
selectors are separate existing mechanisms, not additional registry snapshots.

Durable world schema 2 embeds topology schema 2: `schema`, `allocator`, `zones`
and `spawns`. Every live registered area is represented by an opaque ID, exact
type and selected scalar fields, including empty roof bases. Ordinary/durable
area references use typed zone-ID envelopes in this revision. Legacy coordinate
area envelopes remain readable through their old path.

Each first admitted turf serializer frame writes native scalar metadata at
`/zone_capture/<entry>/index` and `/zone_capture/<entry>/id` in its level file.
The index encodes x/y/z with x fastest. Membership is not copied into world JSON
or an RLE JSON payload. A completed generation still contains every level from
1 through its saved maxz; arbitrary selected-level saves are unsupported.

All five spawn registry fields are required in the new topology. A missing
named group means deleted; a present empty group means explicitly no destinations.
Both override startup defaults. Missing topology in legacy durable schema 1
means use the existing reader, not delete every spawn. Original saves are not
rewritten. Old readers reject the unfamiliar durable metadata/zone envelopes.

## Lineage identity and rollback branches

Initial placed areas retain deterministic `map:<type>:<minimum coordinate>` IDs.
Previously unassigned areas receive `zone:<namespace>:<counter>` on capture.
The namespace reuses an ordinary save-generation token; the allocator makes no
new gameplay RNG calls. The existing generation-token creation still uses its
existing rand call. IDs are not credentials or guaranteed cross-server identities.

The allocator persists a namespace and canonical positive decimal next counter,
bounded to 12 digits. Incrementing uses decimal text, not floating-point integer
arithmetic. Allocation reserves imported/live/captured identities, skips occupied
IDs within 32 attempts and fails explicitly on exhaustion. Reservations retain
an owner record even when native deletion clears its owner pointer. Duplicate
owners reject. Failed-save allocation may advance process-local high water;
allocator/capture object pins are released after the operation.

Imported IDs are never silently renamed. The saved next counter must follow all
issued IDs in its own namespace. Restoring an older generation retains a higher
known process-local counter for that namespace. A fresh process restoring an old
generation cannot know an abandoned future: rollback branches may reuse IDs.
That explicit lineage divergence is allowed; generations must not be merged by
ID equality. There is no external allocator ledger or namespace provisioning.

## Captured-generation consistency

The topology hook runs after before_save_context, frame revalidation and paid
transfer checks, before recursive contents traversal. Already captured turf
references retain their first membership record. Area descriptors and registry
entries become operation-owned scalar records; references bind to captured IDs.

After level files close, the candidate is validated in yielding batches before
round.json and the completion marker are published. Validation checks complete
grids, required metadata presence, coordinate-to-entry membership, unique IDs,
counter bounds, descriptors, spawn identity, roofs and reference closure. Durable
area fields are derived from captured descriptors and anchors, not a later live
rescan. Malformed candidate output aborts with the prior completed backup intact.

This is internally consistent per-entry/per-registry capture over time. It is
not a simultaneous world snapshot or equality with the live world at completion.
Concurrent edits after capture can belong to the next generation. Observed
dimension changes, duplicate/missing captures, conflicting references, retired
uncaptured owners and spawn/roof membership disagreement abort. Raw privileged
edits to private capture state or candidate files during an owned save are not a
supported mutation API. No partial mutation epoch is treated as complete coverage.

The former non-yielding full-world JSON comparison is removed. Per-cell native
save metadata and an import validation grid still cost memory/storage and repeated
O(cells) passes; native scale and latency remain unmeasured. Existing final JSON
encoding of metadata/graphs is not claimed to be bounded by this patch.

## Restore and publication

All malformed-input preflight precedes ClearMap. Membership is projected for
ordinary and durable validation. An operation-owned context quarantines area
registration during ClearMap, including transient base areas created by old roof
destruction. Reconstruction then accepts only requested saved IDs/types; an
unexpected constructor becomes a sticky failure. Terrain and membership restore
before object fields, after_load, metadata and final lighting.

New areas do not append to area_list during this reconstruction. Old instances
are nevertheless mutable, so load/recovery admission is essential. Existing
operation/recovery/startup state gates public area helpers, weather entry,
admin-zone jumping and sky landing. Save-time behavior is
preserved. Busy helper access raises an explicit unavailable error rather than
pretending the requested area is absent. Initial startup area.initialize has a
one-shot capability supplied by world/New to the initial initialization pass. The
capability closes on completion/error; public helpers have no startup bypass.
Snapshot readers recheck admission and a registry epoch after season pauses,
predicate callbacks, modal input and landing callbacks. Load mutation and final
publication replace the epoch, so a completed intervening import also invalidates
an older snapshot. This is not universal raw-mutation tracking. Standalone historical
fixtures omit the full-game feature define; the full-source zone fixture includes it.

Every obsolete empty-area retirement is fallible and occurs before publication.
Membership and staging are checked again after retirement; all spawn destinations
resolve before final no-yield pointer assignments. Only then are area/spawn
indexes published and staging detached. Unexpected constructors, failed retirement
or changed membership prevent publication.

There is no rollback after ClearMap. Engine/callback failure leaves the recovery
hold active and requires recovery from the original disk generation. The old
registry is not advertised as a usable snapshot of the partially mutated world.
Native constructor-surprise and retirement-failure injection, lighting/weather
correctness and connected-client behavior remain unverified. Successful synthetic
restores do not establish those dedicated acceptance cases.
Public callbacks deliberately bypassing admission are unsupported. The existing
pure-predicate contract for get_area_turfs remains required.

Roofs still retain base type rather than base instance ID; switched roofs require
a unique saved base type. Ambiguity is an explicit error, not guessed identity.
The existing roof omission controls need fresh native adjudication for this new
format; earlier roof-format results do not establish acceptance for topology saves.

## Verification and integration seam

tests/zone_persistence contains independent Python models, source omission controls
and an 8x8x2 native writer/reader. The models remain offline evidence; the frozen
fixtures are unchanged. A separately versioned `zone-native-516.1688-v2-jobmaster`
adapter now has bounded native Linux BYOND 516.1688 acceptance on source
`8144be445fa0492a515b6bb47b9692e0edc1830b`.

[Hosted attempt 2](https://github.com/Civ13/Civ13/actions/runs/40165392581),
controller `6895f1079ee0ea2fcc98c16fcdecb2b261a2d881`, compiled the synthetic
fixture with zero errors/warnings and passed all 14 modes: write/read,
write-sequence/read-sequence, legacy-write/legacy-read and eight malformed-input
modes. The retained per-mode results total 313 assertions with zero failures.
This is actual native execution, not the earlier QEMU compile preparation.

The successive-generation reader checks baseline, changed and deleted generations
twice each, including all five spawn registries, cross-z membership changes,
created/deleted areas, aliases, stable IDs and authoritative empty/absent groups.
Malformed-input controls check rejection before ClearMap with sentinel/index
preservation. Expected rejection diagnostics are retained and phase-scoped, not
blanket-suppressed. See tests/zone_persistence/README.md for evidence bindings,
adapter corrections and the preserved failed first attempt.

The canonical world-save prepare-only runner still refuses native zone execution;
this result belongs to the reviewed hosted adapter/controller, not a change to
that guard. The synthetic metadata subtype overrides New and loads no Gaia map.
No production saves, players or connected clients participated. Listener closure
and owned-process cleanup receipts were retained for every mode.

Native roof-format/omission controls, constructor-surprise and retirement-failure
injection, lighting/weather correctness, connected-client behavior and scale/latency
remain open. Ordinary synthetic area creation/deletion and successful round restore
do not substitute for those dedicated controls. No production-scale or full-map
acceptance is claimed.

The serializer integration seam is inside BuildVarDirectory after
before_save_context/require_export_frame/ticket checks and before child traversal.
Future serializer changes must preserve first-admission membership capture,
reference binding, traversal ownership and work-budget checks.

## Future boundaries, not implementations

Local generations and zone IDs cannot provide shard, global character, transfer
or custody identity. Shared character custody needs an authoritative provider.
Persistence capture and custody-changing transfer must share owned operation
admission and durable-state reconciliation, not just a pause boolean. A future
handoff needs fenced ownership epochs, idempotent transfer IDs, source-generation
binding and crash recovery for prepared/committed/aborted states. Activation must
wait for authoritative custody reconciliation. In a custody-enabled deployment,
an old save or absent transfer field cannot restore departed characters; unknown
legacy identity must quarantine rather than guess from ckey/name. Local-only
behavior can remain unchanged when custody is not configured and no transfer
state exists. No such authority or runtime transfer hook is implemented here.

Destination mapping should resolve a logical spawn key against the destination's
validated current generation and admission rules. Inventory/object graphs need
closed transferable ownership, explicit rejection of external references and
durable receipts. Failure after committed handoff requires reconciliation or a
new compensating transfer, not resurrection by loading an older source save.
Shared era/mode/calendar require a versioned authoritative world contract; weather
can remain local. No network service, credentials, custody store or live transfer
is part of this zone patch.

The following transfer foundation remains a proposal: shared save/load/transfer
operation admission, a versioned scalar transfer record and an activation
reconciliation interface tested with an offline custody provider. No runtime
transfer hook is implemented by this change. A configured custody deployment must
check authoritative custody even when an old save lacks a transfer field; absence
is not proof of local ownership. Fencing must bind character, transfer and owner
epoch to the admitted operation, and crash recovery must reconcile durable receipts
before either process activates a body. A fake provider proves local contract
behavior only, never real cross-server ownership.

For a future USA pilot, logical region, shard process and physical host are
separate concepts. A shared authoritative timeline can drive regional clock and
daylight rules while biome/elevation stay independent coordinate layers. The
travel graph is independent of hosting adjacency: Florida, Georgia and California
may share a hosting assignment without California becoming geographically adjacent
to Florida; Texas and Louisiana can have separate assignments. Begin with two
logical regions/two processes, explicit transit and measured capacity. State-wide
scale and player limits remain measurements to establish, not promises. No USA
mode, map, service, process or deployment is implemented by this note.

Future rail transit can reuse connectivity/component and invalidation lessons
from power-grid work, not electrical rules or runtime object references. Each
shard publishes a versioned local graph summary of established stations and
boundary crossings; global routes compose those summaries. Neither shard hosting
nor cached known topology proves currently admitted travel. New crossings become
edges only after their explicit establishment and validation.

For a continuous-route travel model, every required segment needs current
admission, bounded freshness and a lease/reservation policy before departure;
long trips need renewal at defined safe checkpoints. An intermediate outage or
changed track invalidates affected cached versions. Before departure, refuse
without moving custody. After departure, retain one authoritative in-transit
custody record and reconcile/replan or wait at a defined safe checkpoint; do not
activate speculative bodies or resurrect the source from a save. A different
express/endpoints-only model would need explicit rules and must not silently use
continuous-route assumptions. Cached routes never authorize arrival; destination
spawn/capacity admission must be current.

Reservation and transfer retries reuse fenced idempotent identities, not repeated
inventory debits. Cancellation before committed departure requires authority to
confirm no custody change before releasing reservations. After commit, return is
a reconciled compensating operation, not local cancellation. Lease expiry alone
does not establish custody. These are transit architecture proposals, not rail,
cache, service or transfer implementations.

Future shards can remain stopped while lightweight generation/save inventory and
versioned route summaries stay available. Deduplicate concurrent wake requests,
admit measured resource use and fence lifecycle epochs. A destination is usable
only after restore, custody reconciliation, timeline policy and readiness checks;
failed startup leaves the traveler at the source. Idle shutdown must drain/block
admissions, confirm no players or pending custody work, complete and verify a
generation, then stop. Serialize wake-versus-sleep with demand reservations and
lifecycle fencing; a stale sleep decision cannot stop a newly admitted arrival.
Choose offline progression explicitly, separating shared calendar advancement
from local simulation/weather rather than replaying arbitrary elapsed ticks.
No actual server lifecycle operation is added here.

The official launcher can be a future connection orchestrator for discovery,
wake/load status, compatible-client selection and destination reconnect. Its
actual capabilities remain unverified in this task. It is not custody authority,
route validity or transfer approval. Server-side fenced/idempotent recovery must
survive launcher loss/restart, and secrets must not appear in public arguments.
There are no launcher edits or new connection behavior in this slice.

Launcher use must remain optional. Manual/direct BYOND connections to running
servers receive the same server-side identity, custody, readiness and admission
checks. Transfer correctness cannot depend on trusted launcher state or exclusive
launcher credentials. Sleeping shards need an explicit supported manual discovery
and wake-request path; a stopped port cannot accept a direct join. That fallback
path is a future interface requirement, not a service implemented here.

Logical geographic layers such as biome and elevation are independent of the
native room/roof area and engine z. The separately merged optional geographic
elevation component binds elevation to coordinates, survives turf replacement and
defaults to zero when absent; it is not a dependency of native topology persistence.
See docs/elevation.md for its own format and acceptance limits. Native topology and
optional geographic components retain separate version/validation contracts; unknown
component versions must reject before mutation, not silently disappear. This format
does not claim to encode all future zone layers, and the native zone fixture does
not establish combined nonzero-elevation/topology acceptance.

Future ocean voyages, offshore rigs, submarines and pressurized bases, and later
satellite/station/Moon/Mars modes remain roadmap scope. Physical depth/elevation
and pressure/atmosphere state are distinct from native area and engine z. Vessel,
passenger and object-group custody requires a later atomic transfer/closure design;
a character-only handoff does not solve it. No implementation is added here.

Weather appearance is captured as scalar icon_state in topology schema 2. Reconciliation under the owning restore context preserves the
constructed/source-authored icon resource and restores saved icon_state, then
final topology validation runs before registry publication. It checks and preserves each area's saved weather
and weather_intensity; it does not reapply global weather policy or radiation.
This avoids ambiguous reconstruction (for example, snow1 versus snow2 can share
local wet weather). Legacy schema-1 imports retain their original path; the new
appearance guarantee is for topology generations. There is no rollback after
ClearMap. The native round trips above do not establish dedicated weather or
lighting correctness acceptance.

Remaining native acceptance is tracked in [#3311](https://github.com/Civ13/Civ13/issues/3311).
Source merge is distinct from deployment or approval to use production saves.
