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
A current-world inventory for a fresh unsaved round remains missing. Existing
world/account duplicates are quarantined conservatively; canonical saved-world
versus account-home replica ownership still needs a durable owner/location
contract. Runtime movement and external writers remain outside the read lease.

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
