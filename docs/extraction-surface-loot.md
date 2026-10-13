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
insertion reject unacknowledged roots. Exact gasoline-container interaction
handlers prevent consumption through their subtype overrides. Disposal records
an unresolved intent and quarantines the source; a cleanup callback does not
prove engine deletion. Runtime item, marker and metadata links are excluded from
native variable persistence.

Explicit discovery inputs accept at most 16 roots or account entries per batch
and retain at most 2048 identities. Malformed graphs, mismatched account root IDs
and duplicate world/account identities lock discovery. Reconciliation can bind
an actual loaded root only when its identity, graph and source position match;
missing roots and pending operations quarantine without regeneration. These
inputs are not yet connected to authoritative world/account loaders, and do not
prove completeness or active-raid recovery. Direct `loc` assignments can bypass
movement hooks and require an audit before enablement.

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
