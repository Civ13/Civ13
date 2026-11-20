# Treasure maps and leased dungeons

**Draft contract, not playable.** This proposal covers the on-foot route only.
The dungeon is a separately leased Expedition region, never a new Gaia
z-level. See the [four seeded layouts with furnished rooms](FURNISHED.md)
and the [latest matching floor families](COHESIVE_FLOORS.md). The earlier
[five-style pattern study](FLOOR_PATTERNS.md) remains available for comparison.
The [threshold follow-up](THRESHOLDS_AND_CRAFTING.md) applies the approved
palette to arrivals and reviews which finishes players can actually build.
The latest [corridor pass](CORRIDORS_AND_DOORS.md) adds continuous paving,
open landings, and optional stock doors.
Diving, underwater sites, and live activation are out of scope.

## Find and follow the map

1. A found map uses the normal [cartography paper and canvas](../../code/game/objects/items/cartography.dm).
   It doesn't need a special interface. The clue is a conventional mark in an
   approximate search area; players can still draw or take notes as usual.
2. The world issues an original only when a discovery tile and exact
   excavation tile are on-foot reachable from established public terrain in
   the origin region. The two sites need separate path/claim/coverage checks.
   No ocean requirement, unsupported crossings, locked passage, roofs,
   constructed floors, buildings, or enclosed house sites. The route and both
   tiles are checked against the authoritative world, not the paper's pixels.
3. The original has a private server-minted item identity and one-use key.
   The authoritative immutable blueprint is separate from the chart: schema,
   key/original binding, origin region, world lineage and terrain version,
   surface level, discovery and exact dig cells, bounded search rectangle,
   generator release/profile/config digest, seed, loot-table revision/digest
   and budget. Generator retries, if supported, have a pinned bounded
   algorithm and the resolved seed/attempt/hash is fixed before spending.
4. A [normal copy](../../code/game/objects/items/cartography_notes.dm)
   can reproduce every visible clue but never the original's identity, key,
   or blueprint. Drawing over a mark cannot move the site, change loot, or
   reroll generation. Copy machines, handwritten copies, inspect data,
   transfers, and persisted wrappers must preserve that boundary. The
   player-facing chart never serializes hidden coordinates, seeds, loot or
   the key as UI data.

## Commit the stair, or keep the original

- The original must be personally held at a reachable, supported exact
  surface coordinate matching the same origin and terrain version. Resolve
  the actor, real original and site server-side. Separate non-authority player
  reports (wrong place/blocked) from private journal diagnostics.
- Confirm plan availability and a provisional dungeon lease, then use a
  stationary timed dig with the ordinary [excavation](../underground-excavation.md)
  interruption contract. A provisional lease may prepare a verified map
  without exposing an entrance or any usable copy. No slot, generator failure,
  incompatible pin, movement, blocked terrain, or map/item change means no
  visible committed mouth and no key expenditure. Cancel a reservation or
  return the unused slot without changing seed or budget.
- Just before commit, re-resolve the same origin and item and revalidate
  location, path/ownership, blocking terrain, safe entrance clearance,
  generation receipt and live lease. Never trust a stale preview or old
  caller-supplied truth flags. If an area changed, keep the item and refuse;
  do not pick another tile or ledger key.
- Atomic durable commit records one unique spend, one mouth identity and one
  lease binding together. A journal may reserve beforehand but spending is
  not successful until the stair is durable. After commit, the original is
  retired; replay after a response loss consults the same committed receipt,
  never creates a second stair or consumes a replacement item. After a crash
  after durable commit but before paper removal, the spent record fences that
  paper on restore before any new dig admission. Uncertain writes stay fenced
  until reconciled, not falsely presented as a cancel.
- Use [Expedition slot](../expedition-slots.md) allocation and generation
  placement/lineage patterns, not temporary cells on the origin region.
  Dungeon leases are bounded and separate from ordinary lands; no eviction,
  chart unlock, home move, or route interference as a side effect.

## Embark, recover and return

| State | Custody and player consequence |
| --- | --- |
| Stair committed | Host lease identifies run and exact world. Entrance awaits a solo invite or fixed party. No run timer yet. |
| Ready | Lock one roster; recheck all members alive, present, willing and personally carrying supported gear. Separation or any failure aborts the group admission. No pulling, vehicle inventory, companions, depots, or unsupported graphs. |
| Admitting | Every traveler gets an original authoritative snapshot and a one-owner custody journal. Fence origin before destination activation. Admit everyone together or recover everyone; no partially activated party. Start a bounded deadline only on durable group admission. |
| Active | Walk away through the entrance to end your participation early. Dungeon loot comes from the pinned table under the pinned budget; local finds are run-scoped and not interchangeable with original gear. |
| Success | Restore the original character/gear snapshot to a validated mouth return tile. Carry out eligible dungeon loot and send any explicit extraction-chest loot to a single origin-mouth container, linked to idempotent per-item award receipts, never re-create the original kit from destination state. |
| Defeat | Intercept lethal outcome before ordinary death/loot/ghost hooks; fence destination custody, return that traveler immediately via the durable origin snapshot and original kit, award no dungeon loot, and never spawn a duplicate origin corpse or new body. If origin is unavailable recover when it is safe; the traveler is parked, not killed or allowed to resume both copies. |
| Timeout / restart | The deadline is durable and is not reset by reconnect, host restart, or slot reuse. Reconcile journal and receipts before admitting a body or reopening the exit. Unsettled participants/loot are quarantined and recovered per documented outcome. Release/archive the lease only after current custody and awards are terminal. |

Group admission and transition identifiers must include both world lineages,
lease generation, run, roster/member, and source/destination generations.
Capture original items including nested supported contents; temporary native
refs or copied atoms are not identity. Pin a reviewed allowlist and stage
return before marking it terminal. Surviving state follows the original-snapshot
policy, not an incomplete home-moving codec. Base the durable invariants on
[transfer bridge](../../code/modules/persistence/transfer_bridge.dm),
[declared transfers](../save-declared-transfers.md), and
[one-owner custody guidance](../extraction-custody-fence-audit.md).
Reusing the incomplete home route or an unchecked character/item graph is
explicitly out of scope; missing compatible codec means fail closed.

## Implementation and verification order

| Slice | Delivery | Evidence needed before claiming it works |
| --- | --- | --- |
| 1. Immutable issue and spend foundation | Server-owned blueprint and identity contract, issuance/dig guards, provisional and commit receipts. No gameplay flag, lease activation, or account changes in the initial offline model. | Exact/mismatched original, copy/ink/reroll rejection, path/roof/floor/house variants, stopped dig, unsupported versions, two simultaneous commits, replay/crash after durable spend, invalid lease preserves the map. |
| 2. Bounded producer | Versioned seed/profile/config to validated layout, private loot socket metadata and stable output hash; publish four distinct map previews for review. | Repeatability, connected entrances/rooms, no accidental padding route, seed/profile differences, valid tile/art/type constraints, bounded dimensions and reachability. A preview is not a compiled region or BYOND gameplay. |
| 3. Origin + lease adapter | Render original as ordinary chart; connect real discovery and dig authorization, one durable mouth and no-effect feature-default. | Existing copy/UI compatibility, same-site revalidation, all resource returns on precommit failure, suspended/recovered actual interrupted slot, no changes to Gaia z. |
| 4. Cross-world custody | Solo/party ready lock, atomic admission, deadline, early exit, death interception, idempotent original restore and capped loot receipts. | Fault injection at every journal phase; crash, restart, duplicate requests, wrong lease, disconnected/not-ready member, terminal outcomes, exactly-one body/equipment and exactly-once awards. |
| 5. Acceptance | Native isolated verification and later real-client QA; explicit rollout decision separate from merge. | Exercise normal cartography, route/dig, solo and multi-person flow, timed return and recovery. Record what was and wasn't actually tested. No live testing, merge, deployment or feature activation from this draft. |

Implementation and test artifacts must never include a live save, player
identity, logs, credentials, lease key, or production map origin.
