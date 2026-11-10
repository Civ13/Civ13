# Physical trains between player-established regions

Status: design proposal, not implemented or deployed. Source review: master
`0301cd5f7ad8b348116d05771f1fbba8bce9f27e`, 2026-11-10.

Stopping rule: document the physical-train requirements, dependency-ordered
implementation and acceptance tests; publish a draft for review without enabling
travel, altering live saves or claiming native acceptance.

## Player contract

Val's requested loop is exploration first, railway investment second:

1. Travel to an eligible region by a path and establish an outpost.
2. Build and register that party's railway station, with track to a valid map
   edge. An unexplored region is not unlocked by choosing its name in a menu.
3. Select an established destination at a station, board and drive the train.
4. At the registered departure edge, stop the entire train. Transfer its physical
   cars, people, NPCs and cargo as one custody unit, not independent teleports.
5. Reconstruct it on reserved rails at the destination edge, preserving consist
   order and occupants, then release it to continue toward the station.

The Rail Yard is a train-only hub. Paths must not grant access to it; normal
logins restoring a character already aboard/in the yard and operator recovery
are not new travel routes. Stations connect established outposts through the
Rail Yard. Direct region-to-region services may follow only where a registered
route permits them, not arbitrary destination selection.

Initial policy proposal: station construction by the party is the outpost
qualification, with the existing region/link permission checks retained. Route
management requires faction leader/delegated railway authority; riding uses the
party's existing boarding policy. Neither policy grants arbitrary remote shard
access or silently permits everyone to alter another party's destinations.

## What exists, and what does not

- `party_train.dm` and [party trains](party-train.md): a station transfers a
  character to a stationary, party-owned Rail Yard interior. Its berth returns
  the character home. This is not a moving physical train.
- `trains.dm`: `process_rail_movement()` currently stops when the next turf is
  absent. That boundary is an interception point, not a ready transfer hook.
- `train_platforms.dm`: `train_consist_list()` follows leader-to-follower links;
  it stops at 200 segments or a repeated node. A transfer must reject overflow,
  cycles and incomplete consists explicitly rather than accepting that prefix.
  Platform cars contain four segments with three-tile-wide decks. Local deck
  ownership planning prevents cargo moving twice on curves.
- [Transfer storage](../tools/transfer_storage/README.md): character payloads
  are bounded, allowlisted and journaled. Ordinary goods wait for committed save
  effects; they cannot use character-style fast replay without durable identity.
  Current HTTP request bodies are capped at 1 MiB.
- Landers use per-character messages and recreate a destination lander. Their
  special cargo list is not proof of atomic arbitrary-consist transport.

A station destination menu alone cannot deliver this feature. Do not convert
existing stationary interiors to moving cars or delete old berths automatically.
Migration must preserve existing party property and be separately specified.

## Design boundaries

### Routes and arrival geometry

Use stable station, party and train identifiers, qualified by group, region and
world generation. Faction display names are labels, not durable ownership keys.
A route names a source station/exit and destination station/entry, owner, allowed
train class, route revision and enabled state. Registration is persistent and
revalidated when scheduling and departing: station exists, ownership/access is
valid, destination is enrolled, epoch rules permit it, track reaches the edge.
Station removal, reset or generation change invalidates stale route snapshots.

For the first physical release require straight ingress track long enough for
the full manifest, with three-tile deck clearance and an entry buffer. Arrival
is stationary, facing inward; the whole consist must fit inside the map before
it becomes playable. Reserve exact rail/deck footprints, not just the leading
tile. Never truncate long trains, stack trains, push bystanders aside or spawn
on missing rails. If the strip is occupied or too short, wait/refuse while
source custody remains intact. Curved/switch arrival corridors are a later
phase with an explicit placement solver and their own tests.

Departures may approach through curves, but the initial boundary approach must
have a marked straight staging section. A bounded manifest records each
segment's order, orientation and attachments. A defined mapping preserves each
occupant's deck/seat-relative position when straightening the arrival consist.
If a layout cannot be represented without overlap, reject it before departure.
Unsupported corners, reversing across an exit or branching/multiple-powered
consists must receive explicit reasons until supported, not fall through to
ordinary null-turf movement.

### One manifest and one authority

Use a versioned allowlisted graph, not arbitrary DM vars or executable paths:
train/car/segment IDs; validated couplings; fuel, condition and doors; furnishings
and nested contents; ammo/reagent state; people, NPCs and animals; seat/buckle
links; container ownership and local coordinates. Rebuild derived train parts
through the existing restore lifecycle, not as duplicate serialized walls.
Exclude clients, runtime timers, external references and transient action state.

Declare supported types and serialized fields per phase. Refuse unknown cargo
or unresolved pointers without deleting, dropping or converting them. Validate
manifest byte, node, nesting and train-length limits before source removal.
Large manifests require a bounded staged-upload protocol or an explicit lower
limit; simply increasing the agent's request cap is not a transport design.

Reserve all bodies/accounts and train/cargo IDs together. A manifest may include
connected players, disconnected bodies, NPCs, animals and corpses, each exactly
once. Account home/custody updates must agree with the same transaction. Block
boarding, unloading, coupling, inventory mutations and train movement during
capture; settle/cancel ongoing actions. Revalidate after asynchronous calls.
This is a per-train freeze, not a server-wide save or movement freeze.

### Recoverable handoff

Proposed states (not existing API names):

`prepared -> destination_reserved -> source_escrowed -> destination_staged -> committed -> released`

A unique transfer ID, manifest hash and world generations bind every message.
Every transition is persisted, compare-and-set and idempotent. Prepare and
validate the full manifest and destination capacity before relinquishing source
custody. Destination staging is quarantined and not interactive. Only a durable
commit grants destination authority; source copies are removed/tombstoned and
never resume play. Release player connections only after the destination can
claim the committed bodies. A disconnected client can reconnect later.

Before commit, an authoritative abort restores/unfreezes the source and removes
quarantined destination objects/reservations. After commit, do not "rollback"
by recreating the source: finish destination recovery. An uncertain timeout must
query the journal or hold the train, never guess that the other world failed.
Reservations cannot expire into overlapping arrivals after commit. Operator
recovery reports the transaction and custody owner without requiring save edits.

Save/load reconciliation must remove stale pre-departure objects and reconstruct
committed arrivals absent from an older save, using stable IDs. Old backups,
world resets and mismatched generations fail closed pending reconciliation.
Ordinary save effects and fast replay must not produce two playable copies.
A coordinator restart cannot erase the authority decision or create a second
home world for an account.

## Phased work and exit criteria

1. **Route registry and station UX.** Durable station/party IDs, registered
   outpost routes, authoritative permissions, invalidation and destination menu.
   Label physical departures unavailable until later phases. Test persistence,
   ownership changes, unknown peers and Rail Yard path rejection.
2. **Manifest codec.** Encode/validate/restore bounded consists and supported
   load graphs in isolated fixtures. Add stable IDs and reference remapping.
   Prove lossless values and count conservation; no networking or live travel.
3. **Grouped transfer ledger.** Extend custody from individual characters to
   manifests with reservations and recoverable commit. Fault-inject every write
   and message boundary. No participant can become playable before commit.
4. **Destination staging and edge integration.** Connect movement/station route
   snapshots to the ledger; reserve straight entry corridors, stop/resume trains,
   redirect players and reconcile saves. Initially disabled pending acceptance.
5. **Two-region and client acceptance.** Exercise actual train movement, world
   saves, relaunches and connected/disconnected riders, then review whether a
   bounded pilot can be enabled. No live rollout is authorized by this plan.
6. **Broader layouts.** Curved arrivals, switches, reversing and extra vehicle
   types only after explicit geometry and recovery tests. Existing Rail Yard
   interior migration is its own preservation-aware task.

## Required acceptance matrix

For each test record exact revision, pinned BYOND version, fixture/map, manifest
hash and IDs, initial/final ledger, counts and field-value comparisons. Python
protocol models and static source checks are not native or graphical acceptance.

| Area | Cases and required oracle |
| --- | --- |
| Length | locomotive alone; single wagon; four-segment platform; mixed cars; longest supported consist; limit+1. Exact segment order or clean preflight rejection, never a partial train. |
| Coupling | detached cars, cycle, missing follower, two powered heads, reverse attempt, braced/wrecked car. Explicit rejection leaves source unchanged. |
| Geometry | all four edges, narrow strip, insufficient length, branch/switch/curve approach, foreign train/deck, missing rail, dense turf/object and bystander. No overlap, clipping or displacement; unsupported geometry refuses. |
| Passengers | driver, seated/buckled and standing riders, edge-of-deck rider, concurrent boarding/disembarking, disconnected/sleeping bodies, NPCs/animals/corpses. No loss, duplicate body or unowned client. |
| Cargo | nested crates, furnished cars, doors, fuel, damage, guns/ammo, reagent containers, unsupported types, unresolved references, oversize/deep payload. Exact supported state or refusal before removal. |
| Concurrency | two arrivals for one strip, opposing trips, repeated button presses, station deletion or route edits during transfer. One reservation and one effective transfer. |
| Failures | lost/duplicate/reordered messages, refused request, full disk, destination asleep/unavailable, source/destination/agent/coordinator crash at each state. Exactly one authority, deterministic recovery. |
| Saves | save during prepare/escrow/staging/commit; restart both sides from pre/post snapshots; repeated reconciliation; older backup/reset generation. No replay duplication or stale train resurrection. |
| Routes | unestablished region, unauthorized station/party, faction rename/disband, unknown peer, forbidden epoch, foot/lander access to Rail Yard. Server-side rejection, no menu-only enforcement. |
| End to end | establish outpost by path, build station/rails, choose destination, drive to boundary, transfer, reconnect, drive onward and return. Repeat for each supported layout with inventory and persistent identity conserved. |

A passing test must assert conservation of unique entities and relevant values,
not just that the destination reported success. Add negative controls which
omit a tombstone, double-apply a message, shorten a reservation or mutate a rider
mid-capture and confirm the test detects the resulting violation.

## Evidence for this draft

Source inspection establishes the gaps above. No manifest codec, physical
cross-region transfer, native acceptance or performance result is implemented
or claimed here. Compilation/gameplay tests are not applicable to this docs-only
change. Subsequent phases must report their own exact-head evidence.
