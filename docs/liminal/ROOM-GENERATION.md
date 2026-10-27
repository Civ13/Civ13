# Authored rooms, indoor topology and deterministic generation

Profile: INDOOR_LIMINAL. This is separate from geographic SURFACE, OCEANIC and
UNDERGROUND_CAVERN terrain semantics. Indoor cells model walls, solid authored
props, floor and sealed void, with room identity, typed connections and shared
progression. Native turf types, items, assets and z IDs belong to an adapter.

## Ten original room families

Dimensions below are abstract collision cells; row zero is south. Every family
has an original authored mask, role/zone, anchors, typed sockets and light/sound/
rarity/material intent. No game/show room raster or third-party sprite is used.
Masks are collision plans, not an image or a native visual acceptance result.
The [ten static asset/layout previews](ROOM-PREVIEWS.md) apply a proposed existing
Civ13 palette without changing masks, sealed sockets, solid cells or anchors.

| Family | Cells | Role/zone | Human sockets | Spatial purpose |
| --- | --- | --- | --- | --- |
| Arrival vestibule | 9 x 9 | ARRIVAL/OFFICE | E | Safe spawn, orientation and briefing |
| Office columns | 11 x 11 | HUB/OFFICE | W,E,N | Repeated columns with protected crossing |
| Offset office | 13 x 11 | HUB/OFFICE | W,E,N | Offset partitions with an authored wide aperture |
| Cubicle repetition | 15 x 13 | HUB/OFFICE | W,E,N | Repeated bays and a reserved central route |
| Archive stacks | 13 x 13 | HUB/OFFICE | W,E,N | Shelving masses, central aisle and side discovery |
| Acoustic atrium | 15 x 13 | HUB/OFFICE | W,E,N | Contrasting open volume; audio intent only |
| Threshold buffer | 9 x 9 | TRANSITION/BUFFER | W,E | Visible transition between office and service |
| Utility gallery | 13 x 9 | SERVICE/UTILITY | W,E | Service objective with guaranteed work approach |
| Maintenance alcove | 7 x 7 | ALCOVE/OFFICE | S | Authored optional detour holding discovery site |
| Extraction airlock | 9 x 9 | EXIT/EGRESS | W | Safe terminal extraction anchor |

The current canonical catalog is liminal-authored-rooms/0.1.0, SHA-256
`7ee6647de885a921746f9ac9d0ec5fa9e5140a30a8c06294cd4ff16c3d37c95b`.
Changing any geometry, socket, anchor or intent requires a new content version
and reviewed goldens. Rarity is a positive bounded integer selection weight,
not a promise of exact percentages in one small chapter.

## Grammar and zoning

The first assembly recipe has exact roles:
ARRIVAL -> HUB -> TRANSITION -> SERVICE -> EXIT. A single ALCOVE may attach to
the HUB. Discovery is in the alcove when present, otherwise the hub. The service
action requires discovery; the final connection and exit require service done.
All room instances must be reachable, including the detour. This is a deliberate
finite authored chapter, not a random spanning maze relabelled as rooms.

Cross-zone links are limited to OFFICE<->BUFFER, BUFFER<->UTILITY and
UTILITY<->EGRESS; same-zone links are allowed. A direct OFFICE<->UTILITY shortcut
is invalid. Entry/exit role counts, bounded work and progression are mandatory.
Later chapters may introduce repeated modules, return loops or another threshold
under a new recipe/version; those extensions must retain explicit room programs.
A walking graph may have loops. Surface river drainage rules do not apply.

## Typed sockets and portal contracts

Each socket declares stable ID, facing, center offset, aperture width, clearance
class, connection kind and native-admission state. All unused sockets must be
explicitly sealed; every used physical socket has exactly one mate. The baseline
prototype implements HUMAN_DOOR only, width 3, with opposing aligned apertures.
It rejects unknown sockets, multiple mates, mismatched facings/widths and implicit
cross-room openings. Sockets are walls in the mask until an approved link opens
both mating apertures. Solid furniture never fills a reserved approach.

Other kinds are implementation contracts, not working features:

| Kind | Required contract | Current prototype |
| --- | --- | --- |
| HUMAN_DOOR | Paired physical apertures, actor clearance, explicit gate flags | Implemented as abstract traversal edge |
| SERVICE_SOCKET | Power/audio/utility relationship, not a movement shortcut | Unsupported; reject |
| MAINTENANCE_HATCH | Audited actor class/size and access policy | Unsupported; reject |
| LEVEL_PORTAL | Exact paired logical destination, safe landing, unique IDs and lifetime/round checks | Unsupported; reject |

No native door lock, power connection or teleporter is implied by these data.
The initial finite round does not require level portals. A future portal graph
must prove destinations and return/egress behavior; it cannot invent an external
level or bypass a lock because two socket names look compatible.

## Geometry, clearance and progression

The blueprint has V=sealed void, W=wall intent, B=solid authored prop intent and
F=floor. An independent reconstruction from catalog+placements+sockets must
equal the stored blueprint. Rectangles cannot overlap. Rooms keep authored
anchor sites; geometry cannot smuggle an undeclared floor seam between modules.
The small proof supports rotation 0 only. Future quarter turns must transform
mask, anchors, footprint, offsets and facing together, with new fixtures; native
sprite directions are a separate audited mapping.

The point graph is insufficient. For actor radius r, navigable centers require
the entire (2r+1) x (2r+1) floor footprint. Authored room interiors and all their
inward socket approaches must connect at default r=1. This is conservative
abstract tile clearance, not proof of current pixel/sub-tile actor collision.
Native collision/pathfinding must be validated against the chosen target source.

State search uses(position, monotone shared flags). Discovery grants FOUND_MARKER;
the service action requires it and grants SERVICE_DONE. The exit requires the
service flag and every required objective. Search starts independently at every
spawn, checks gate predicates on every aperture crossing, and requires all rooms,
required objectives and at least one final exit to be reachable. Keys behind
their own lock, cyclic prerequisites, unproduced flags and blocked anchors fail.
Items are not consumed or dropped in this proof; any future such mechanics need
a different native/state model. Extraction time, health and AI are not simulated.

## Determinism, controls and bounded failure

The prototype reuses verbatim existing stable_u64/canonical_hash helpers from
Civ13 commit 8f819a586484dadc66cb8b330df56922b699b7ff and the strict JSON/new-output
helpers. Geometry generation never loads DM code or an asset. Seed, exact config,
algorithm, content/catalog digest and profile version frame each random choice.
No wall clock, traversal-order RNG or process hash seed selects content.

The versioned configuration exposes:

| Control | Small-proof bounds/meaning |
| --- | --- |
| seed | ASCII 1-128 characters, explicit default liminal-0 |
| hub_allowlist | Nonempty unique subset of the five authored hub families |
| branch_alcove | Whether the authored discovery detour is present |
| actor_radius_tiles | 0 or 1; native capability remains unverified |
| min_spawn_exit_tiles |1-256 completed progression-route steps |
| max_rooms |5-8 resource cap; this recipe actually has 5 or 6 rooms |
| max_blueprint_tiles |256-16384 finite cell cap |
| max_candidates |1-4; each attempt retained in the manifest ledger |
| max_search_states |1-100000; total exploration bound, never a partial pass |

Full configuration is part of the seed frame, including budgets. Changing it
can change selected content; replay requires the exact manifest. The larger mode
will add bounded room recipes/mix, group start sites and an approved native palette
version, rather than silently accepting unsupported controls. These caps are
engineering limits for an offline proof, not measured native host capacity.

Authoring catalog checks run first. Each bounded candidate assembles the chapter,
then validates graph, raster, clearance, zoning and progression independently.
A failed candidate is recorded with its reason; no invariant is relaxed. Candidate
or state budget exhaustion rejects the seed/config, without an accepted output.
No repair, global search, runtime mutation or overwrite of an existing file/save
is performed. Config, catalog, plan and output hashes bind a complete bundle.

The narrow proof writes JSON plan/manifest/proof/complete files only. It does not
emit a DMM, native assets, screenshots or a game-mode registration. Native export
is a separate source-backed slice, specified in SOURCE-AND-ACCEPTANCE.md.
