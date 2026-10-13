# Durable surface loot contract

Human scope includes visible items on the ground and world supports: canned food
on store shelves, mode-appropriate money at cash registers, fuel cans and tires
in parking. This is a shared contract proposal pending frozen agreement, not an
accepted surface system. A disabled placement schema is implemented in
`code/modules/1713/extraction/surface_loot.dm`; issuance and custody are not.
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
The proposed `/obj/structure/extraction_mall_fixture/register` is pending source
review. It must be fixed scenery without native closet storage, currency
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
