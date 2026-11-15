# Packed multi-depth mining: implementation and acceptance plan

Status: **design only; no playable feature or runtime foundation is implemented**.
Reviewed against master `853ba40e6a8ad1bc36fd35621d30a5399d043895` on
2026-11-13. The proposed first playable version is opt-in, bounded, resident
and persistent. Unloading and slot reuse are later work.

## Decision and evidence

Several logical mine depths can share rectangles on a capped physical plane.
That avoids allocating a whole native plane *per logical depth*. It does not
prove that the resulting lit caves, objects or save peaks fit available RAM.
BYOND still allocates every cell of any added plane. A full-size underground
world at every depth cannot be made cheap merely by calling it an instance.

| Current source | Consequence for this design |
| --- | --- |
| [dug_underground.dm](../code/modules/multiz/dug_underground.dm), `dug_underground_supported`, `underground_admitted`, `dug_underground_create` | An opted-in single compiled level can gain exactly one cave. Creation fills the entire plane and initializes cave lighting. This is not a multi-depth allocator. |
| [world_z_budget.dm](../code/modules/multiz/world_z_budget.dm) and [allocation policy](new-z-budget.md) | Whole-world target dimensions, reservations and purpose admission remain mandatory. Arithmetic capacity is not memory admission. No new mine exception is authorized here. |
| [nomads_gaia.dmm](../maps/nomads/nomads_gaia.dmm) | The shipped map is 500 x 350 x 2: 350,000 cells. Each further physical plane adds 175,000 cells regardless of rectangle occupancy. A generated single-level map has a different starting cost. |
| [building_admission.dm](../code/modules/multiz/building_admission.dm) | Its empty-sky measurements describe optimized building levels, not lit cave rock. Do not extrapolate those numbers to mines. |
| [practice_rooms.dm](../code/modules/1713/practice_rooms.dm), `slot_origin`, `drop_level`, `wipe_room` | Rectangular packing exists, but rooms are disposable, excluded from saves, cleared and removed. Reuse the geometric idea only; neither deletion nor admission is a mine persistence contract. |
| [functions.dm](../code/modules/persistence/functions.dm), `sparse_level_kind` | Generated dug caves explicitly do not use a sparse baseline. Sparse disk encoding never implies a sparse native grid. |
| [saving.dm](../code/modules/persistence/saving.dm), `level_link_target`, `finish_level_links` | Declared cross-z movable links have a codec. It does not identify logical floors sharing one z or make them independently unloadable. |
| [persistence guide](agent-guides/persistence/README.md) | Cross-z movement gates and durable zone IDs exist. Same-z slot transfer, slot lifetime and logical reconnect need explicit integration; zone IDs are not geographic floor identities. |

Searches of open PRs and issues for mining/underground/mine depth, and branches
for mine/mining/depth/underground, found no matching active packed-depth owner.
Related resource progression is [#3046](https://github.com/Civ13/Civ13/issues/3046),
[#3047](https://github.com/Civ13/Civ13/pull/3047) and
[#3053](https://github.com/Civ13/Civ13/issues/3053); retain their depletion,
construction and machinery contracts. Offline cavern generation and playable
exports already exist in [#3617](https://github.com/Civ13/Civ13/pull/3617) and
[#3697](https://github.com/Civ13/Civ13/pull/3697). They are useful terrain
precedents, not runtime slot persistence. Recheck ownership before each source
slice; one owner edits and publishes each branch. This review contacted no
other agent or service owner.

The safe foundation in this draft is the contract below. An unconnected DM
registry would prematurely freeze save identity and allocation ownership while
offering no usable floor. Do not wire a flag, global singleton, generation hook
or player entrance until the corresponding acceptance gates are implemented.
The OpenDream hold remains in force; this plan targets the pinned BYOND engine.

## Identity and first-version boundaries

Proposed durable key: `(world_lineage, mine_id, depth)`, where `mine_id` is an
opaque server-issued identifier and depth is a bounded positive integer. Never
derive identity from player name, physical z, a mutable entrance coordinate or
current occupancy. Multiple entrances may lead to the same mine; creating or
removing an entrance does not create new ore. Depth is display/geology order,
not `z + 1` or `z - 1`.

Keep existing surface/compiled cave geography unchanged. Start with an authored
entrance to a separate bounded mine, rather than converting all existing Gaia
caves or all tunnels. A mine's horizontal edge is solid bedrock; it cannot
extend into the next rectangle. This means separate mines do not organically
meet through digging in version 1. If contiguous geographic mines are wanted,
design explicit shared ownership/topology before lifting that restriction.

Proposed schema, to be finalized with the persistence implementation:

| Record | Required durable fields and checks |
| --- | --- |
| Registry header | Schema version, world lineage, committed save generation, next identity counter, validated limits; reject unsupported versions and wrong world. |
| Floor | Unique mine/depth, fixed local width/height, generator version and seed, creation receipt, terrain snapshot/deltas, durable entity ownership and zone identities. Missing state for an existing ID is corruption, never a request to generate. |
| Placement | Floor key, physical plane, bounded rectangle including border, placement generation; validate containment, disjointness and reserved-region conflicts before mutation. Version 1 persists fixed placements. |
| Shaft | Unique link ID, two typed endpoint identities (surface anchor or mine/depth/local tile), direction and usable state; validate both endpoints and permitted destination geometry. |
| Occupant/reconnect | Existing character identity plus floor key/local location and committed generation; preserve body, inventory and death state through the existing character owner. Never create a second body as a fallback. |

Use structured fields, not ambiguous concatenated keys. Reject fractional,
negative, oversized, duplicate or missing identities/coordinates. Bound record
counts, string lengths and decoded payload sizes before allocating lists.
Runtime indexes, leases, busy flags, callbacks and live references are rebuilt
and explicitly excluded through the custom save policy (DM `tmp` alone is
insufficient). Keep local entity references distinct from inter-floor links.

## Allocation and spatial containment

Choose a finite layout at map configuration time. For a reserved region of
width `W`, height `H`, outer margin `m`, interior floor size `w x h`, solid
border `b` and gutter `g`, use pitches `px = w + 2b + g` and
`py = h + 2b + g`. With a trailing gutter reserved, capacity is
`floor((W - 2m) / px) * floor((H - 2m) / py)`, additionally capped by configured
floor, per-mine depth and global entity limits. Validate all inputs as bounded
integers before division/multiplication. This is capacity arithmetic only;
no production sizes or guard-band widths are approved here.

Reserve the complete rectangle and its border before generation, with no yield
between overlap check and ownership acquisition. Include compiled terrain,
other mines, practice rooms, building levels, orbit and extraction reservations
in the conflict inventory. An existing plane is usable only when its owner
explicitly reserves an empty region; never overwrite an inhabited cave because
it fits. Growth must still go through `world_z_budget` and
`building_allocate_level` conventions, holding ownership through initialization.
Unknown purpose, capacity exhaustion or unmeasured admission returns a clear
refusal with no item debit or fallback allocation. Do not borrow the practice,
roof, instance or safehouse allowance.

Initially keep admitted floors resident for the whole world lifetime. A full
pool refuses new floors; disconnecting everyone does not reset a mine. Cap the
registry as well as active slots so empty abandoned entrances cannot grow
unbounded metadata. IDs and depletion tombstones must never wrap or be recycled.

A border and separate area alone do not isolate same-z simulation. Audit each
consumer and use logical floor membership at its admission/range boundary:

| System | Required separation and test |
| --- | --- |
| Sound, speech, radio, remote views | Ordinary spatial sound/speech cannot reach neighboring slots; intended radios retain explicit range/channel semantics. Test nearest opposing edges and remote eyes. |
| Lighting and vision | No corner/overlay/light propagation across slots; settle updates after load and turf replacement. Test bright boundary torches and open/closed doors. |
| Pathfinding, NPCs, projectiles | Search expansions and movement remain inside the owning floor except admitted shafts; no diagonal/corner escape or target acquisition in adjacent slots. |
| Explosions, collapse, fluids, fire and weather | Clip affected cells to the logical floor. Prove oversized effects cannot cross a gutter, remove borders or damage another mine. Define shaft propagation separately; initially no automatic propagation between floors. |
| Power, pipes, crafting and machinery | Cable/pipe adjacency, bench proximity, water searches and factory inventories cannot bridge slots. Existing recipes/debits remain authoritative. Test construction at edges and contained inputs across save/load. |
| Terrain tools and admin/transport movement | Replacement, digging, falling, teleport, pulling, riding and forced movement must honor containment or explicit audited rescue paths. Do not rely only on ordinary Move(). |

Spacing is defense in depth, not the sole guarantee: unbounded-radius or
whole-z consumers can ignore any fixed gutter. Record each audited call site,
supported interaction and rejected unsupported behavior before enabling access.

## Generation, saves and transfers

Generate only for a newly reserved, never-before-committed floor ID. Use
coordinate-stable local generation with a stored generator version; preserve
biome, era and ore rules from existing mining. A deterministic seed describes
original terrain, not current depletion. The first implementation should save
the full materialized floor through existing world persistence; introduce delta
storage only after proving it preserves every mutable field and empty cell.
Never regenerate a missing/corrupt saved floor from its seed.

Bind registry, topology, terrain, contents, shaft links and character locations
to the **same committed world save generation**, using the existing completion
marker/backup protocol. Do not independently commit a JSON registry beside an
older terrain save. Acquire operation admission before capturing or replacing
state; retain it across yields. Freeze logical-floor transfers during capture,
including same-z transfers that today's cross-z check does not reject. Ordinary
within-floor movement still needs the existing moving-save ownership semantics.

Restore order: validate the complete candidate and dimensions without changing
the world; reserve/admit physical capacity; reconstruct proven area/topology;
restore terrain and owned object graphs; bind typed shaft/cross-floor links;
reconcile character ownership and reconnect locations; publish ready floors.
Quarantine the whole dependent generation on missing/duplicate links or floors.
Preserve original files and block subsequent overwrite; after destructive map
mutation, use the existing recovery hold rather than claiming in-memory rollback.
Legacy saves with no mine registry remain legacy worlds. Older binaries must
refuse newer mine-bearing saves rather than silently dropping the registry.

Shaft travel resolves source and destination through floor identities, never
the generic z-only helpers. Revalidate actor/body, held or pulled companions,
endpoint identity, placement generation, save admission, landing occupancy and
capacity after every wait and immediately before commit. For version 1, refuse
unsupported vehicles, buckled groups and ambiguous pulls before moving anyone.
Emit landing effects and success only after movement succeeds. Destroying a
shaft disables that route, not its saved floor or contents; keep a tested rescue
route to an authored safe surface location. A temporarily unavailable floor
holds reconnect/entry with an explanation, without deleting, duplicating or
silently relocating its body. Rescue must preserve inventory and record the
change in the next coherent save.

For eventual unload/reuse, require an empty active-client set **and** an audited
durable snapshot of sleepers, corpses, items, containers, structures, machinery,
timers, power/water networks and external references. Occupant absence alone
is insufficient. Define whether each process pauses or accrues bounded elapsed
time; no offline ore refill or duplicate production. Commit the snapshot before
retiring runtime ownership, drain callbacks/registries, then clear the slot and
increment its placement generation. A late callback or link from the previous
tenant must fail. Restore from that snapshot exactly once. If any durable graph
cannot be detached safely, keep the floor resident and refuse reuse. Do not
shrink native z as rollback or promise that clearing a slot returns RAM to the OS.

## Ordered delivery and acceptance gates

Each row is a separate reviewable slice, not an assertion of implementation.
Recheck current master, scoped guidance, ownership and CI selection each time.

| Phase | Deliverable | Exit evidence |
| --- | --- | --- |
| 0: contract (this PR) | Design, source inventory and failure policy. | Relative links, source symbols, map arithmetic and docs-only CI selection checked. No feature activation. |
| 1: registry/schema | Uninstantiated bounded types, pure validation, versioned save contract and fixtures; no world growth or entrances. | Duplicate/malformed/oversize/unknown-version rejection, stable IDs and fixed placement round trip. Production-source tests and negative controls; no Python-only model presented as DM runtime proof. |
| 2: allocation/admission | Opt-in reservation owner and bounded fixed layout; test-only tiny compiled region first. | Same-slot races, all pair overlaps, edges, exhaustion, save/allocation exclusion and failures at every yield; no unauthorized resize or debris after refusal. Production remains off until memory admission is separately justified. |
| 3: generation/isolation | Versioned local terrain, immutable border and audited spatial consumers. | Stable same-seed geometry, distinct IDs, existing mining yields/depletion, no neighbor effects in the matrix above, bounded initialization/lighting queues. No player entrance yet. |
| 4: persistence | Coherent whole-world save/import of fixed resident floors and typed links. | Disk round trips of excavations, depleted ore, rubble, structures, nested items, machines, corpses and sleeping players; reconnect exactness; crash injection before/after marker publication; malformed generation refused before mutation. Repeated reload never adds resources or drops entities. |
| 5: travel/playable pilot | Authored entrance, explicit two-way shafts and rescue; opted-in disposable world only. | Two players racing/landing, interrupted waits, full slots, deleted shafts, death/disconnect/reconnect, same-z travel during save and rejected movement with no effects; real client movement/lighting/UI verified separately. |
| 6: memory/rollout | Calibrated bounded production profile, diagnostics and operator recovery instructions. | Measurements below plus long-session save/load/concurrency evidence; reviewed opt-in map and limits. No default enablement based solely on compilation. |
| 7: unload/reuse (optional) | Snapshot-backed eviction and remapping with generation tokens. | Full durable graph audit, no stale callback/ID alias, repeated unload/reload conservation, delayed reconnect and failure recovery. Resident fallback if any invariant fails. |

## Measurement, rollout and rollback

No RAM benchmark was run for this proposal. Before admission, compare sequential
fresh processes on the pinned engine, same OS/build/map/save/population and
settled lighting: baseline, one empty backing plane, increasing generated slots,
excavated/furnished slots, active players/machines, save/import peak and repeated
reuse (when implemented). Record process RSS/private or committed bytes with
platform definitions, high-water marks, entity/lighting counts, init/save/load
time, worst tick/latency, address-space limits and repeated-run variation.
Include player and save scratch headroom. Do not convert mixed-world observations
into bytes-per-tile or treat a lower save file size as recovered heap.

Native runs are allowed only in isolated cloud/GitHub fixtures whose launcher
constrains **initial port binding and outbound account/network effects before
process start**. A world.New() port close, `-close`, or sampled sockets is not
that proof. If the runner cannot enforce it, use static/offline preparation and
report native execution unrun. Preserve failed evidence. No OpenDream work,
desktop checkout, live-save import, deployment, merge, restart, data deletion,
credential or security-setting change is included in these phases' source work.

Roll out first on a disposable opted-in map with very few resident slots and
documented capacity refusal. Enable production only under separate operational
authorization after acceptance. Diagnostics expose bounded scalar floor IDs,
slot occupancy, lifecycle states, refused admission reasons and generation IDs;
do not retain live atom graphs for telemetry.

Before any mine-bearing save exists, disabling the feature can return to legacy
behavior. Afterwards, disabling new entrances must preserve the registry,
existing exit/rescue routes and readers. Reverting to an older binary is unsafe
without an explicitly reviewed migration. Quarantine damaged generations and
use a coherent copied backup under authorized recovery; never reset a mine to
fresh terrain, delete occupants, or overwrite the last known good save to make
startup succeed.
