# Source/asset boundary, export and staged acceptance

## Source provenance

The native design audit baseline is Civ13 commit
`10d264e5896221b34949ee4b67c0fd2b94bde249`. Read-only source references are
capability evidence, not new-mode gameplay acceptance. Existing surface/oceanic
source remains at its own reviewed commits; cavern work remains separately private.

| Reference | Established observation | Reuse limit |
| --- | --- | --- |
| code/game/objects/map_metadata/lights_out.dm | Survivor/extraction foundation; increment-per-spawn(10) timer toward 300 conflicts with 30-second comment | Do not inherit jungle constructor effects or copy timing blindly |
| code/modules/1713/lantern.dm | Unlimited flashlight variants and darknight light range/color fields; separate fuel-based variants | No assumed battery scarcity or new asset/visibility proof |
| code/game/objects/effects/bump_teleporter.dm | Target-ID lookup, delayed movement and persistence_set_loc | Not proof of unique/safe paired indoor portals |
| code/game/mob/living/simple_animal/hostile/monsters.dm | Root audit verified echofiend sound investigation | Door/pixel-pathing, spawn safety and pacing unproved |
| code/game/sound.dm | Root audit verified sound integration | No measured acoustic occlusion from authored tags |
| Existing carpet floors, footsteps and ambience | Root audit identified reusable hooks | Exact per-file native palette/appearance remains a mapping task |

The first three files were independently read at the pinned baseline while
preparing these documents. Echofiend/sound/carpet findings reuse the root audit
rather than duplicating its ownership. Primary links are in MODE-DESIGN.md.

Offline shared helpers are copied verbatim from
tools/procedural_maps/validator.py and io.py at
`8f819a586484dadc66cb8b330df56922b699b7ff`. This reuses deterministic framing,
strict JSON, new-output guards and manifest principles, without modifying or
calling the geographic generator as an indoor backend. Indoor topology has its
own schema/profile. Native type/palette mapping is deliberately not Nomads export.

## Asset policy

Use existing Civ13 assets first. Original collision masks and descriptions are
new design data, not copied rooms or artwork. No third-party art/audio/RSI/DMI
file has been transferred. Do not infer a whole repository's license from one
metadata file. In particular, the audited Civ14 carpetoffice candidate has an
NC license; the Humanity replacement has different CC-BY-SA attribution. They
are not interchangeable. A suggested Civ14 light_tube RSI metadata file is
CC-BY-SA-attributed, but this is not approval for a port or its dependencies.

Any proposed external file needs a record of repository, full revision, exact
path and SHA-256, copyright holder, exact license/version, attribution, dependency
files, modifications and compatibility with Civ13 distribution. Ambiguous, NC,
unlicensed or incompatible entries remain quarantined. Approval is per file.
No asset is copied merely to make a generated screenshot look convincing.

The native palette catalog must independently record the chosen in-repo floor,
wall, dense prop, doorway, light, marker, extraction area and optional portal
types/vars with exact source and asset references. Source presence is necessary
but does not prove constructor behavior, licensing, collision or appearance.

The [version-1 asset-mask previews](ROOM-PREVIEWS.md) are rejected historical
evidence. Their hashes/mappings are retained but must not be promoted to accepted
room design or native export approval. The [renderer fidelity study](RENDERER-FIDELITY-STUDY.md)
separately audits connected wall junctions, real open hall context, correct
directional furniture, and the width/state limits of native doors. Revised
catalog geometry stays with the design owner. This advances no native acceptance.

## DMM export contract

The target is a finite static DMM loaded before the round, with an explicit
logical-level-to-native-z mapping. Do not assume indoor0 means native z2, create
dynamic levels, or reuse the Nomads metadata object. Any extra plane must obey
repository size/admission rules; the first target can use one fixed plane.

The exporter consumes validated authored topology and a separately approved
indoor native catalog. W/B cells require verified collision-compatible native
wall/solid mappings. Door apertures require explicit static layout and later
native gate ownership. Critical blockers cannot be dropped or represented only
in a sidecar. Reject unknown types/vars/materials/rotations/portals; do not emit
undefined DM vars or substitute a floor-only color mask.

Use uniform dictionary key widths, literal override values, object-before-turf-
before-area ordering, equal row sizes, north-first DMM rows and one-based x/y.
Preserve the topology/room/zone/progression manifest in a semantic sidecar.
Static parse-back must equal the intended native layout and complete sidecar
semantics. Room tags and progression require the sidecar plus mode adapter;
DMM text alone does not prove runtime gates or extraction.

Output layout: map.dmm, semantic topology, exact seed/config/version manifest,
source/type/asset catalog pins, sidecar, parse-back proof and complete.json
written last. Existing destinations and native saves are never overwritten.
Static generation/parse-back, native compilation, editor appearance and an
actual round are separate acceptance claims. Constructors can alter appearance
and schedule native work even when static DMM text is deterministic.

## Mandatory acceptance versus tuning

Mandatory invariants:

1. Authored catalog/version and required functional room program are valid.
2. Typed physical sockets have one compatible aligned mate; unused sockets seal.
3. No overlap, hidden opening, blocked anchor or insufficient actor clearance.
4. Zoning requires buffers; solid props preserve the authored walk reserve.
5. Every spawn reaches required objectives and an exit with keys before locks.
6. No unproduced flags, circular progress, unresolved required destination or
   budget exhaustion can receive an acceptance result.
7. Exact seed/config/algorithm/content/profile/source pins and all rejection
   reasons are retained; no silent repair or player-world overwrite.
8. No unreviewed external assets or unsupported native behavior is admitted.

Tunable controls: allowed family mix/weights, optional detour, finite scale/caps,
grace/round/extraction duration proposals, approved steady light/ambience choices
and later threat eligibility. Tuning cannot disable the invariants.

The private small proof currently passes 45 explicit tests on Python 3.11 and 3.13.
Its default 6-room layout has 1060 blueprint cells, 152 navigable footprint centers,
393 explored progression states and a 60-step completed route. Default topology
SHA-256 is 6e4e1946ee62525bad82681d6b7cb5b0d2b8d8c03472b8856009108a93bcad40.
These are reproducible offline measurements, not playability or visual evidence.
Catalog/all-hub tests, reverse traversal, malformed input, overlap, socket
mismatch, missing links, zone shortcuts, keys behind locks, cyclic prerequisites,
blocked anchors, output tampering and hard candidate/state limits are covered.

## Implementation slices and independent review

Keep design changes separate from implementation commits and drafts.

1. **Design milestone:** publish these coherent documents for root review; freeze
   initial decisions, room vocabulary, finite map boundary and source caveats.
   Preserve existing terrain profiles and their branch/history/evidence.
2. **Small independent authored-room tool:** source-backed deterministic catalog,
   config/topology validators, bounded chapter assembly and reproducible offline
   fixtures. Public-safe tests/commands; no native mode activation or copied art.
3. **Indoor static native catalog and DMM exporter:** verify chosen existing
   floors/walls/props/doors/areas, emit correct DMM with sidecar and parse-back,
   reject unsupported semantics, test deterministic small layout. Remain explicit
   that abstract progression is not yet native door/interaction behavior.
4. **Finite mode adapter:** separate map metadata, 1-4 participant start admission,
   original marker/service interactions, shared idempotent progress, gate/escape
   registry and elapsed-time extraction/failure state. Do not inherit Lights Out
   jungle constructor hazards or unreviewed timing. Keep live map selection off.
   Enforce the 1990-default equipment/prop/recipe/research policy from
   ERA-AND-SCENARIOS.md; do not substitute a year label for native filtering.
5. **Threat/light/audio pass:** use only approved existing capabilities; prove
   real sound investigation, door/collision behavior, safe threat sites, light
   visibility and action pacing. No new battery system or imported assets.
6. **Acceptance and tuning:** exact-head ordinary CI plus source/offline controls;
   separately authorized isolated native tests and real client evidence for
   objectives, interruption/death, group extraction, timers, threat navigation,
   scene/lighting/audio and round teardown. Record failures and resource bounds.
   Native execution, public assets, merges and live activation remain separate.

No design decision currently blocks slices 1-2. Choosing/validating the native
indoor catalog and mode handlers is necessary for slices 3-4. Native runtime,
visual/audio acceptance and host capacity cannot be established by the private
topology proof. Root retains design/source review and all merge decisions.
