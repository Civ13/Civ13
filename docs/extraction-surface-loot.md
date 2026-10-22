# Durable surface loot contract

Human scope includes visible items on the ground and world supports: canned food
on store shelves, mode-appropriate money at cash registers, fuel cans and tires
in parking. This is a shared contract proposal pending frozen agreement, not an
accepted surface system. A disabled placement schema is implemented in
`code/modules/1713/extraction/surface_loot.dm`. The staged service implements
finite prepare, materialization and ordinary pickup intents/acknowledgements.
It is not installed by map startup and defaults to disabled.
Native execution remains on hold.

The marker path is `/obj/effect/extraction_surface_source`. Map variables are
`source_id` (integer 1..128), `pool_id` (one of `parking_fuel`, `parking_wheel`,
`repair_parts`, `canned_food`, `register_cash`), `support_kind` (`floor`, `shelf`,
`table`, `register`) and `support_type` (a DM structure path, null for floor). These pool
names are reserved placement identifiers; every pool is disabled. Schema
validation checks shape only and does not approve a support type, reachability,
unique IDs, codec support or issuance. No constructor registers or spawns items.
Exact mall support approval remains pending integration with its map-owned
types; do not treat an arbitrary structure path as an approved support.

Mall placement agreement uses exact `/obj/structure/table/extraction_mall/shelf`
for `shelf` and exact `/obj/structure/table/extraction_mall` for `table`. These
map-owned fixed supports are suitable for disabled marker placement; enabling
items still requires support existence, direct item interaction and custody
acceptance. Nightstands are outside the current 40-source placement scope.
The reviewed `/obj/structure/extraction_mall_fixture/register` is approved for
disabled placement support. It is fixed scenery without native closet storage, currency
generation or interactive contents. Its sprite does not grant currency authority.

The existing container journal plans finite equipment graphs and debits before
delivery. `track_loot()` records runtime cleanup references only. It does not
provide durable surface materialization, pickup or restart reconciliation.
The existing container epoch increments on world initialization; using it alone
would allow surface refill on restart and does not satisfy this contract.

Each source requires explicit map ID, unique source ID, persisted epoch, exact
pool, finite planned graphs and reachable placement/support metadata. Persist
the epoch across restarts. Advance only at an agreed authoritative round boundary
after outstanding ownership is settled; constructors and loaders never advance
it. Keep surface source IDs in a separate namespace from the 64 containers.

Commit planned identity before materialization. Materialization has durable
pending and acknowledged phases. Failed or uncertain issuance quarantines the
source; never reroll or recreate a second copy. Roots are actual obtainable items
with stable IDs and FIR, not decorative sprites or a hidden container menu.
Supports must permit visible reachable interactions and preserve all nested
equipment, fuel, condition and quantity through the existing codec.

Pickup, dragging, consumption and destruction need explicit custody hooks. A
durable claim binds source/epoch/item ID and actor before ownership changes;
acknowledge only the observed successful transition. Reject concurrent claims,
wrong identities and pending recovery. Failed placement or destroyed supports
must not create replacement rolls. Consumed or extracted roots never respawn.

Restart reconciliation must join source receipts with actual world/account item
identities before issuing any root. A materialization receipt alone cannot prove
that an item survived or was not claimed. Missing, duplicated or ambiguous roots
stay quarantined. Existing active-raid recovery remains unproven; do not replace
that uncertainty with automatic refunds or regenerated surface items.

Use a bounded source registry, finite per-source node limits and the shared
2048 tracked-node budget. Process bounded batches; avoid full-world scans and
per-item sleeping chains. Food requires exact supported types and a codec that
retains its actual contents. Tires must remain actual supported wheel graphs.
Money must use each mode's existing authoritative currency policy and atomic
claim/credit receipts, never Discord currency or invented cross-mode funds.

Core owns source lifecycle, claim/custody hooks, codec and save reconciliation.
The mall owner places source markers and reachable supports after the API is
frozen. Existing ordinary container additions remain map-owned. Preserve normal
maps and the separately owned container-key presentation region.

Acceptance requires visible placement and pickup, nested/FIR identity, finite
rolls, support destruction, failed construction, concurrent claim/consume,
rollback and materialization/claim/ack crashes, save/restart/extraction ownership
reconciliation, wrong epochs, currency conservation and node-budget overflow.
Native fixtures and genuine gameplay acceptance remain separate evidence gates.

Current staged implementation uses one exact root per source: gasoline jerrycan,
boxed native wheel or salvage for parking fuel, parking wheel and repair parts.
Food and cash cannot prepare, even when an isolated fixture enables the service.
Explicit registration is capped at 128. Reconciliation batches visit at most 16
registered sources; graphs are capped at 16 identities including packed wheels.
Materialization checks the shared 2048 tracked-item limit before construction.
The map-namespaced epoch is initialized once and retained on restart.

Ordinary item `attack_hand` delegates linked roots to the source claim. The
service writes actor/identity/epoch intent, moves that actual root through native
hand placement, verifies observed custody and acknowledges. Failed acknowledgement
locks the actor and source and returns the actual root to its source when possible.
Base item `attackby`, forced movement, walking movement and native human hand
insertion reject unacknowledged roots. Native storage insertion and human slot
equipment reject them before direct location or slot changes. Exact gasoline-container interaction
handlers prevent consumption through their subtype overrides. Disposal records
an unresolved intent and quarantines the source; a cleanup callback does not
prove engine deletion. Runtime item, marker and metadata links are excluded from
native variable persistence.

Explicit discovery inputs accept at most 16 roots or account entries per batch
and retain at most 2048 identities. Malformed graphs, mismatched account root IDs
and duplicate world/account identities lock discovery. Reconciliation can bind
an actual loaded root only when its identity, graph and source position match;
missing roots and pending operations quarantine without regeneration. The optional
world-loader feed and explicit account passes below do not prove complete
ownership or active-raid recovery. Direct `loc` assignments can bypass movement
hooks; audited storage and equipment paths are guarded, while loader construction
and canonical saved-world/account replica ownership still require acceptance.
The account feed must cover all durable profiles and shared ownership records,
not only currently connected sessions.

Round-close processing visits at most 16 manifest sources per call. Forfeiture
writes intent, removes the actual unclaimed root from world custody, then
acknowledges terminal state. A null location proves retirement into the legacy
deletion queue, not that garbage collection has finished. Explicit epoch advance
requires a completed closed round, no sessions and only terminal claimed or
forfeited sources. Preparing a new epoch retains the previous retired entry and
plans a distinct identity. Historical snapshot reconciliation remains incomplete.
These limitations prohibit enabling the service on an actual map.

`tests/extraction/surface_probe.dm` exercises the production journal and codec
for disabled issuance, durable finite identity, restart epoch preservation,
missing-root quarantine, busy pickup, interrupted claim acknowledgement,
duplicate IDs, food/cash rejection and shared-node exhaustion. Additional vectors
cover alternate movement/hand/nesting rejection, fuel interaction, explicit
loaded-root binding, malformed and duplicate discovery, forfeiture and terminal
next-epoch reset. These assertions
are authored but UNRUN under the native hold. `run.py --probe mode --compile-only`
compiles the isolated fixture and returns before DreamDaemon; the offline boundary
tests verify both mode and store compile-only paths cannot launch the runtime.
Generated `--surface-negative-control epoch|claim|duplicate|movement|discovery|forfeit` variants remove
one production guard and must fail at their exact fixture assertion. They are
authored and UNRUN; compile-only does not establish control detection.

Compile-only verification also exposed the earlier vehicle-key declaration on
an internal-engine subtype while axis/workshop/codec hold base engine references.
The authority link and saved-variable declaration now live on the engine parent.
Integrated project and isolated mode fixture compile cleanly with pinned BYOND
516.1681. Vehicle-key cancellation/concurrency/crash/save runtime acceptance
remains unproven.

The custody audit guards storage eligibility/removal and generic safe
equipment/equip-or-drop before destructive failure handling or direct location
assignment. Quick-equip uses the guarded safe equipment path. Fixture negatives
exercise linked-root rejection and ordinary unlinked storage insertion/removal;
these native assertions remain UNRUN.


Discovery failure fences planning, materialization, claims, forfeiture and epoch
mutation. Materialization checks issued, discovered-world and account identities
before decoding. Authored fence vectors prepare a source, then supply malformed
input or a world/account copy of its planned graph; each must retain the planned
state with no live root. These vectors remain native UNRUN.

## Staged loader and account inventory candidate

`Load_World` now feeds an explicitly installed optional surface service after
real `after_load` callbacks on every saved level. Outer item graphs are submitted
in batches of 16; nested item IDs and actual loaded vehicle-part IDs share the
2048-identity cap. A missing, repeated or failed level locks discovery, and a
successful final callback seals only the world portion. Ordinary maps and absent
surface services use their existing loader path. No service is installed by this
change. A started inventory blocks surface mutation until all ownership portions
are complete.

The explicit account feed enumerates the actual configured account directory,
rejects unknown directories and caps the listing at 4096 entries. It reads at
most 16 owners per call, validates current stash, garage graphs/cargo and legacy
profile mailbox entries, and registers all their nested and vehicle identities.
Uncommitted newest journal slots, raid profiles and pending deliveries/purchases
block the feed without rollback or repair. Revision digests and owner-directory
membership are checked in a second bounded pass. Empty directories without a
committed account are rejected. The feed acquires a bounded in-process read lease
before listing owners and retains it across both passes. All account-store
instances refuse phase writes beneath that root, including direct shared-journal
projections. Root aliases and overlapping root leases are rejected; changing the
store root or revoking its token invalidates the census. Failed inventories retain
the fence until explicit disabled-service abandonment, which releases writes but
locks that census. There is no expiry or automatic failure unlock.

This is not an OS or cross-process lock. The caller must still establish exclusive
startup/maintenance ownership against external writers. The lease covers the
account-store phase writer; arbitrary external/direct filesystem writes and
runtime world movement are not covered. No host installation or activation path
has been granted by this source change.

The profile pass validates market listings against actual escrow stash graphs:
each active listing must bind the stored root ID and SHA-256 graph digest, no root
can serve two active listings, and every current escrow root must be bound. Closed
listings are historical references rather than additional owned copies. Actual
escrow graphs enter the common account identity registry once.

The read-only auxiliary census in `surface_inventory.dm` lists at most 4096
records across settlement, groups, insurance, resolved rounds, NPC receipts,
bot receipts and sharded mail. Each batch reads at most 16 actual journal profiles,
rejects pending or unsupported records, then rechecks directory membership and
profile digests. It never calls recovery, repair or equipment decoding helpers.
Terminal NPC history is validated but is not treated as another live copy or a
permanent tombstone: insurance can legitimately return the same identity.

Mail pages contribute their actual equipment graphs to the shared 2048-ID registry.
The final pass traverses at most 16 pages per call and rejects missing links,
orphan pages and mismatched active node indices. Every active node must bind the
same owner, page sequence and graph root as the stored mail graph. Historical
inactive indices do not own equipment. Auxiliary completion requires both the
second journal pass and this page/index reconciliation under the account lease.

These feeds do not establish total ownership or provide an activation procedure.
A current-world inventory for a fresh unsaved round remains missing. Runtime
movement and external writers remain outside the account read lease.

`home_replica.dm` provides an explicit, disabled-service maintenance binding for
floor roots in an unoccupied private room. It reads the actual committed account,
requires every supplied root to match its stash graph without assigning new IDs,
and commits map/room/coordinates, the next account revision, graph digests and
exact floor placements. The marker retains the same owner, revision and binding
digest for a subsequent native world save. The account commit and world save are
separate: interrupted or older world copies fail agreement rather than repairing
or silently reassigning a room. The host must hold exclusive maintenance ownership.

The account census must precede loaded-root reconciliation. Only an identical
floor root with a matching actual saved marker and complete account read lease
can join that account's identity set. Wrong owner, revision, graph, room, placement,
overlapping room footprints and a second physical copy reject. Nested identities
must all belong to the same approved graph. Bodies, secure crates, benches and
vehicles have no canonical placement contract in this first candidate.

Admission rejects a profile with a durable replica binding before decoding any
equipment, including when no surface service is installed. No retirement/unbinding
or admission handoff is implemented; accepting one world/account representation
does not authorize materializing another. Ordinary profiles have no binding.

Room selection separately rejects every full or partial persisted marker binding.
Only no session, null owner/digest and numeric revision zero permit admission or
maintenance binding. Empty owner/digest strings, missing/non-numeric revisions and
nonzero revisions reserve the room. This prevents an unrelated unbound account
from taking a replica owner's room even while its runtime session is absent.
The marker's parent-calling persistence allowlist explicitly includes `room` and
all three durable binding fields, preserves inherited effect fields and excludes
the runtime `session` on both variable enumeration and runtime-field filtering.

Loaded feeds also snapshot the map object, dimensions, map ID and world tick.
Sessions or an advanced tick invalidate the barrier. Final checks process at most
16 indexed roots per call and compare their actual graphs and location identities,
including marker agreement for approved home replicas. This deliberately cannot
accept a loader that yields into a later tick. It is a conservative disabled
candidate, not proof of exclusive runtime-world ownership or production loading.

The separate `current_world_complete` gate stays false. BYOND's built-in DMM
construction has no complete pre-map opt-in ledger in this checkout; restored
`all_loaded` lists omit unsaved/unrestored constructors. A supplied list cannot
prove completeness. Fresh census remains unsupported until a bounded constructor
ledger is established before map construction, with lifecycle/overflow/generation
coverage. No broad world traversal or global constructor hook was added.

Forfeited graph identities enter a durable epoch retirement index before advancing
the epoch. The index retains at most 2048 IDs with no eviction; exhaustion blocks
advance rather than permitting historical replay. Claimed identities remain owned
by account/world reconciliation and are not marked forfeited. Both materialization
and discovery reject retired identities. This is a bounded lifetime fence, not an
unbounded history ledger or permission to restore historical snapshots.

Authored native vectors cover missing-level refusal, successful world-only
completion, refusal of missing auxiliary completion, stable offline-account
inventory, competing store/child-journal writes, revoked leases, pending account
commits, pending shared projections, actual escrow digest/root binding, sharded
mail graph/index reconciliation, mismatched active mail indices and a retired snapshot
loaded after restart. They are UNRUN until native testing is released. Compile-only
success does not establish successful world restoration, multi-account inventory,
garage/mail conservation, runtime performance or OpenDream acceptance.

Discovery and custody reconciliation use the codec's explicit no-new-IDs mode.
Missing loaded item identities fail rather than being minted during inspection;
ordinary encoding retains its existing identity-assignment behavior. The added
missing-ID vector checks rejection and that the real item's ID remains absent.

Generated `--surface-negative-control inventory|retirement|identity` variants
omit the expected-level guard, retired-ID persistence or no-new-ID encoding
respectively. Each must fail only its named fixture assertion. These controls
are authored and native UNRUN; compilation is not omission detection evidence.

Generated `--surface-negative-control escrow|mail_binding|auxiliary_pending`
variants omit the escrow digest comparison, active mail graph/index comparison,
or shared-journal terminal-phase check. They must fail only their named assertions.
They are authored and native UNRUN while the quiet window remains active.

The native queue also includes identical approved replicas, wrong owner/revision/
graph/placement, second-copy refusal, stale load barriers and refusal of incomplete
fresh-world coverage. Generated controls `home_owner|home_graph|home_placement|
home_revision|world_stale|fresh_incomplete` omit each named guard in a temporary
source copy. These fixtures and omission detection remain native UNRUN.

The corrective queue adds an actual second unbound account admitted to a different
room, denial of entry into the bound owner's room, preservation of that owner's
real stash, refusal of bound-owner decode, partial marker fields and a production
disk-backed entry save/load for marker room/binding/inherited fields with no restored
session. `home_admission` restores session-only selection; `marker_save` omits the
durable marker allowlist. Both must fail their exact named assertions and remain
native UNRUN during the quiet window.

## Floor-replica retirement preparation (disabled maintenance)

`prepare_home_retirement` now writes an independent account-store journal under
`_home_replica/` before touching actual roots. It binds the exact account digest,
original marker binding and retained runtime roots. Initial preparation validates
actual root graphs and placements. Preparation replay requires the same runtime
references and unchanged account/binding digests; retirement revalidates surviving
graphs and placements before removal. Foreign ownership and partial marker fields
reject both operations. Account and marker binding fields are not cleared.

`retire_home_replica` validates all remaining roots before removing any, supports
same-process continuation after partial removal, then journals a retired receipt.
Preparation and retirement receipt failures retain the existing account binding
and privacy guard. Restart cannot supply missing roots as evidence, including
when a retired receipt exists: success is scoped to the original runtime. The
caller must own exclusive offline maintenance. There is no automatic entry point.

This is the preparation/physical-retirement portion of a handoff, not completed
unbinding or admission. A retired receipt does not prove an old world save cannot
restore those atoms. No authoritative durable world-save generation and complete
restored-world coverage are available here, so final marker release/account decode
remain unsupported and blocked. `account_directories()` rejects the new unfinished
`_home_replica/` journal directory before the auxiliary census begins, rather than
treating it as completed ownership. Native fixture and
six `home_retire_owner|home_retire_partial|home_retire_graph|home_retire_remove|
home_retire_restart|home_retire_prepare` omission controls are authored but UNRUN under the quiet hold.

## Durable world-generation handoff requirements

The current saver writes `save_complete.txt` last and preserves the preceding
completed generation in backups. Its completion marker contains a timestamp,
not a content-bound generation tying `map.txt`, every level file and a retirement
receipt together. `validate_world_save()` checks structural completeness and map
compatibility, but does not establish that binding. `Load_World()` yields between
batches, so the candidate's same-tick inventory barrier rejects ordinary restores.
`persistence_save_in_progress` prevents overlapping wrapper operations; it does
not fence gameplay constructors, item movement or direct saver calls.

A future handoff must commit a generation manifest only after all save files are
closed, bind their hashes and map dimensions to the exact retirement operation,
and validate that manifest before mutating the loaded world. A generation-bound
mutation fence must remain valid across yielded restore batches. Recovery must
reject older saves that could recreate retired roots before releasing the account
and marker bindings. Hashes alone cannot make an old generation safe to admit.

Complete restored coverage also needs a genuine opt-in constructor ledger
established before DMM construction, including fresh and late-created roots.
Saved `all_loaded` entries alone cannot prove that coverage. These are required
contracts for the next implementation, not capabilities of the current saver or
surface service. Native interrupted-save, old-generation restore and coverage
controls remain pending until the local execution hold is explicitly released.

### Shared persistence ownership dependency

The memory owner confirmed no active saver, loader or bootstrap edits on
2026-10-13. The shared API decision is pending with the main coordinator and
persistence/serializer owner. Extraction must preserve the current shared files
until their frozen head and path ownership are coordinated. The decision needs
to cover these concrete boundaries:

| Boundary | Required contract | Shared source affected |
| --- | --- | --- |
| Generation publication | Close level save handles, bind metadata and every expected level's bytes, then publish one complete manifest. Failed publication cannot authorize release. | `code/modules/persistence/saving.dm` |
| Restore admission | Validate the selected generation against durable retirement state before `ClearMap()` or any turf/entry mutation. Reject a stale backup even if its hashes and structure are valid. Direct restore calls must enforce the same guard. | `code/modules/persistence/functions.dm`, `loading.dm` |
| Mutation fence | Identify one operation and generation across yielding clear/load batches and `after_load()` callbacks. Unexpected construction, custody changes or a failed fence invalidate completion; every failure path keeps admission reserved. A wrapper Boolean alone is insufficient. | `functions.dm`, `loading.dm`, selected constructor/custody entry points |
| Constructor coverage | Establish an opt-in ledger before DMM construction; include constructor-created children, restored identities assigned after construction and later creations. Maintain deletion/replacement bookkeeping and detect missed registration. | `code/world.dm`, item lifecycle and identity restoration hooks |
| Final release | Bind the exact owner, account revision/digest, marker binding and retirement operation to a validated generation. Persist a recovery barrier before independently changing account and marker state; interruption cannot permit duplicate decode. | `code/modules/1713/extraction/home_replica.dm`, account admission, generation recovery |

`/datum/global_init/New()` is the documented pre-map phase; `world/New()` runs
after DMM objects exist. Installing a ledger in `world/New()` would miss those
constructors. An opt-in parent hook also needs a defined policy for subtypes that
omit their parent constructor, and identity assignment during `Load_Entry()` must
not leave the ledger indexed under a temporary identity. These coverage decisions
must precede a claim that a loaded-root list is authoritative.

Legacy version-2 saves must remain usable by ordinary persistence without being
upgraded into retirement evidence. A valid hash authenticates selected content;
it does not establish freshness, exclusion of retired roots or a crash-safe
cross-store release. The serializer owner must decide the durable anti-rollback
record location, backup-selection policy, operation-fence ownership and ledger
scope, or explicitly delegate those shared paths to extraction. Until then this
is a blocking source contract, with no new disabled adapter or release bypass.
