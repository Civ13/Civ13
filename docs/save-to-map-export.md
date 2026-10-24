# Saved world to reusable map: design and static-core proof

Status: the first offline static-source core is implemented for synthetic
canonical JSON only. The broader save-to-map pipeline remains a design.
Inspected Civ13 baseline: `fa363b8a01ed7d936c10a6303ce1be4c26d82ab0`.
No actual save was read and no native BYOND tool was launched. The original
geometry example is hand-authored; executable conversion fixtures now live in
`tests/save_to_map`. See [the core contract](../tools/save_to_map/README.md).

## Outcome and scope

Produce a new Civ13 source map from the static built state in a completed saved
generation. The resulting map starts a new round. It does not resume players,
inventories, research, economies, timers or an in-flight simulation. A `.dmm`
describes placed atoms and areas; compiling and playing it still requires the
matching Civ13 code, icons, sounds and reviewed map configuration. There is no
claim of a binary independent of Civ13.

The initial implemented milestone is an offline canonical-data validator,
deterministic DMM geometry writer and omission reporter using synthetic fixtures
only. Its wood/iron/chair catalog is an initial serializer proof, not useful
full-world coverage or a working full save-to-map converter. Native `.sav`
extraction requires a separate future adapter. Do not implement extraction by
loading a save into a game and calling a map writer.

## Source findings

| Evidence at this baseline | Consequence |
|---|---|
| [`saving.dm`](../code/modules/persistence/saving.dm), `save_world_contents` | A generation has `map.txt`, one `N.sav` per z, `round.json` and `save_complete.txt`. Level format 2 has generation/dimension headers, `/map/z/y/x` turf references, `/entries/floor((ref-1)/512)/ref` records, typed values and separately indexed lists. Round-v1/v2 are distinct from level format 2. |
| `BuildVarDirectory`, `encode_saved_value` in that file | Contents and arbitrary datum graphs can be present. Values have `value`, `list`, `turf`, `entry`, `area` and `map` kinds. Entry IDs are local to each level. Metadata is skipped as an ordinary placed object. |
| [`functions.dm`](../code/modules/persistence/functions.dm), `get_saved_vars` | Many objects/mobs save all changed variables, including `tmp` unless specifically excluded. Existing persistence filters are not a source-map or privacy whitelist. |
| [`loading.dm`](../code/modules/persistence/loading.dm), `Load_Entry` | The loader constructs types, changes turfs and calls recovery hooks; it is unsuitable as the extraction path. Some missing native savefile reads can create entries. |
| [`durable_world.dm`](../code/modules/persistence/durable_world.dm), `capture_durable_world` | Area rows contain one anchor, type and selected fields, not the full turf-to-area membership grid. Map graphs can include accounts, leaders, emails and player-created text. Do not forward `round.json`. |
| [`loading.dm`](../code/modules/persistence/loading.dm), `prepare_saved_roof_areas` | A narrow roof reconstruction exists using direct turf contents, explicit roof settings and exact base-area identity. It is not general area reconstruction. |
| [`normal.dm`](../code/game/objects/effects/landmarks/normal.dm), landmark `New` | Most named spawn landmarks register coordinates and delete themselves. A save alone cannot recreate all authored spawn markers. |
| [`job_controller.dm`](../code/game/jobs/job_controller.dm), `relocate` | Job `spawn_location` keys must match the restored landmarks. The hardcoded missing-marker fallback is not export acceptance. |
| [`DMM Suite`](../code/modules/dmm_suite/_preprocessor_and_utilities.dm), [`reader`](../code/modules/dmm_suite/reader.dm) | Comments describe writing, but the checked-in module and DME include only utilities and reader, with no `write_map` implementation found. Reader instantiates atoms, skips metadata and supports only a limited value subset. Do not use it for safe save extraction or as the compile oracle. |
| [`civ13.dme`](../civ13.dme) | Includes map metadata source and exactly one active DMM (`maps/nomads/nomads.dmm`). A new map needs its types declared before its DMM include. |
| [`compile_map.py`](../tests/dagger_map/compile_map.py) | Existing inactive-map compilation stages a root-local temporary DME with exactly one replaced DMM include. It provides a future native verification pattern; the static core does not execute it. |
| [`test.yml`](../.github/workflows/test.yml), [`travis_pre_byond.sh`](../scripts/travis_pre_byond.sh) | CI pins BYOND 516.1681 and requires zero errors and warnings. Its compile invocation is `DreamMaker -max_errors 0 civ13.dme`. Offline syntax checks cannot replace it. |
| [`mapswap.py`](../scripts/mapswap.py) | This deployment helper pulls/resets source, edits the DME, compiles and restarts a server. It is not an exporter or a test runner; never invoke it for this feature. |

This design uses the inspected baseline's existing source contracts. Future
topology, elevation and spawn changes require explicit integration review.
Sharding improvements and OpenDream are outside this milestone.

## Proposed pipeline and trust boundaries

1. **Admit explicit inputs.** An operator eventually selects a copied, completed
   generation, exact base source commit and map include, and a reviewed export
   profile. No auto-discovery of server data, live paths, credentials or saves.
   Version 2 level files only for the initial reader. Legacy flat saves get
   `unsupported_save_version` until a separate adapter exists.
2. **Copy and seal.** Open originals only for ordinary byte reads; never pass
   original `.sav` paths to BYOND. Reject links/reparse points, nonregular files,
   overlapping input/output, unexpected files, overwrite targets and unstable
   copies. Inventory lengths and SHA-256 before/after copying into a new private
   staging directory. Keep that inventory private. Open only disposable copies
   with the future native reader; verify original bytes remain unchanged on all
   paths. A completion marker is consistency evidence, not cryptographic proof
   that every level belongs to a coherent snapshot.
3. **Decode data without reconstruction.** A tiny reader must not include game
   startup, game constructors, `Load_Entry`, `Load_World`, `after_load`,
   `before_save`, `text2path` followed by `new`, proc calls from data, shell or
   network transports. Presence-check fields before access. Treat native type
   values as data and validate against the exact source catalog. Prototype
   `ExportText` behavior on synthetic files first; do not assume a Python `.sav`
   parser or unrecognized type-path behavior. The existing partial-save inspector
   is a useful structural pattern, but is a native, purpose-specific tool, not a
   ready exporter. Its native extraction behavior is not verified by this core.
4. **Validate a complete static projection.** Require matching generation,
   marker, map ID, dimensions, all level headers, exactly one turf per cell,
   valid level-scoped entry IDs and unambiguous direct-content ownership. Inspect
   links structurally without following excluded player/runtime graphs into the
   portable model. Reject cycles/duplicates in spatial contents. Unknown typed
   envelopes, over-budget data and missing fields needed for a decision fail
   closed. Excluded well-formed dynamic payloads are counted and not materialized.
5. **Resolve authored topology.** Parse the pinned base DMM as data to recover
   area membership and source-authored spawn markers. Do not re-add its ordinary
   objects, which could duplicate saved structures. Initial profile requires
   unchanged rectangular baseline dimensions and proven unchanged area topology.
   Added levels, arbitrary area movement, multiple indistinguishable instances
   of one area type and uncertain roof effects are blocking errors. A later roof
   adapter must reproduce existing exact-identity checks, constructor effects and
   membership ordering. Missing full topology in an old save is an information
   limit; never fill it with a guessed area. Source parity alone cannot prove
   absence of unsaved topology changes; profiles must declare their coverage,
   and lack of that provenance prevents a full-fidelity claim.
6. **Project to canonical data.** Output has explicit `(x,y,z)`, one turf, one
   area token and an ordered list of admitted placed objects per cell. Properties
   are typed scalar values; no raw DM snippets, arbitrary dictionaries, datum or
   entry references. Source metadata/spawn provenance is recorded separately.
7. **Write an unactivated package.** Deterministic DMM, portable report and
   manifest go to an exclusive new directory. Validate all files before marking
   the bundle complete. Interrupted/rejected exports leave a failure report and
   no complete marker. Input/output hashes and source provenance are checked
   again before completion. Export completion and compilation are separate flags.

Proposed initial budgets: 1,400,000 cells total, at most 32 levels of equal x/y,
256 MiB per copied input file, 2 GiB per generation, 256 MiB encoded output,
100,000 placed objects, 64 direct objects/cell, 64 fields/record, 256 bytes/text
token, and 1,000 detailed report groups with exact aggregate counters. Refuse
before exceeding a budget, including unknown graph traversal; do not silently
truncate. These are conservative tooling limits awaiting representative offline
measurement, not calibrated game-memory guarantees or overrides of z admission.
These are broader future-tooling proposals. The implemented static core uses
smaller fixed bounds: 1 MiB JSON, 2 MiB aggregate output, 4,096 cells, eight
levels, 4,096 objects, 32/cell, depth 16 and 64 report groups. Its first fixture
is 3x2x2; broader dimensions require later acceptance.

## Proposed whitelist v0

This is an exact catalog, not inheritance permission. A new subtype or field
needs source review, explicit provenance and a constructor/round-trip fixture.
The machine-readable [policy example](save-to-map/policy.example.json) captures
the initial grammar. The static core enforces this catalog for synthetic inputs
only. It is not a production save-export policy or evidence of native fidelity.

| Category | Initial admitted data | Conditions and loss handling |
|---|---|---|
| Terrain | Exact `/turf/floor/wood`, `/turf/wall/iron` at saved grid coordinates | Type determines normal flooring/material. No arbitrary turf vars. Unsupported terrain blocks output; never substitute dirt/void. Damage, custom materials or altered flooring require an adapter or a reported, explicitly reviewed reset. |
| Static structures | Exact `/obj/structure/bed/chair`, placed directly on a turf | `dir` is one of literal 1,2,4,8; `pixel_x`/`pixel_y` integral -32..32. Constructor-default material/padding must be proven for this profile. Default material is not inferred from type when saved data disagrees. Otherwise block this object or report an explicit reset in an incomplete preview. |
| Authored properties | The numeric fields above; source-authored literal tokens selected by the profile | Never copy saved `name`, `desc`, paper/sign text, custom codes, owner labels or arbitrary colors/icon paths. Future `icon_state` needs an exact token list verified against source assets. Player customization is not authored provenance. |
| Area | Exact `/area/caribbean/dark` membership from the reviewed base DMM | Preserve distinct authored topology only when representable. No saved area flags, lighting-clearance policy, weather, capture state or arbitrary variables. More area types require catalog entries and identity tests. |
| Spawn | Exact `/obj/effect/landmark` with `name` selected from the profile's job-key catalog | Source-authored names/coordinates only; the example uses `JoinLateCivilian`. Recreate deleted markers from pinned source, validate job availability and a valid walkable destination. Missing/ambiguous required spawns block playability. Do not read players' saved jobs/return coordinates. |
| Map metadata | One newly authored metadata subtype, ID/title, selected new-round mode/job profile | Generated from a fixed reviewed template, not saved metadata vars or arbitrary inherited source-map `New()` logic. Profile must control procedural generation so it cannot rebuild/erase exported terrain. This companion template is intentionally unimplemented at this checkpoint. |

Allow only finite, range-checked numbers, literal null where explicitly declared,
catalog tokens and exact allowlisted type/resource references. Emit literal DMM
values (`1`, not `TRUE`). Initial output contains no lists or resources. Later
text support needs a real DM literal encoder that escapes quotes, backslashes,
newlines and interpolation brackets; JSON escaping is not a DM literal encoder.
No macro/expression/proc/path text from an input may become source code.

Doors deserve their own adapter: [`door.dm`](../code/game/objects/structures/door.dm)
contains material construction and credential fields (`keycode`, `custom_code`,
`locktype`/`haslock`). Never emit access secrets or merely omit them while leaving
an apparently functional lock. The initial policy treats doors as unsupported
structures, rather than claiming their appearance/state is fully represented.

Default-excluded state: all mobs/NPCs, minds, accounts, ckeys, client/session/CID/IP
data, body ownership, inventory and contained contents, IDs/keys/passwords,
credential hashes, research/faction/economic graphs, messages, user text/art,
runtime paths/refs, cooldowns, timers, vehicles, machines/networks, reagents,
lighting/appearance/overlay graphs, crop growth and transient effects. Exclusion
is transitive across the entity's contents; never spill a player's inventory onto
the map. Static containers require a later adapter and must be empty only by an
explicit reported reset. Unsupported materials, paid stock and damage are not
silently recreated at defaults.

## Output contract

Proposed package contents after implementation:

- `maps/WIP/<export_id>/<export_id>.dmm`: all exported coordinates/levels, placed
  static atoms, areas and restored source-authored spawn markers. Same-width tile
  keys, rows from maxy down to 1, objects before turf before area, literal vars.
  Deduplicate identical definitions while preserving object order/multiplicity.
- `code/game/objects/map_metadata/exports/<export_id>.dm`: reviewed new-round
  metadata declaration. A unique map ID may be a validated literal; if using a
  `MAP_*` define, add its declaration before this include. Do not inherit a procedural subtype or
  execute a saved map subtype's arbitrary initialization.
- `<export_id>.manifest.json`: schema/policy/profile versions, Civ13 source SHA,
  relative package paths, generated-file hashes, dimensions, coverage status and
  existing asset dependencies. Portable manifest excludes save digests, generation
  identifiers, timestamps, host paths and private inventory. A private local
  receipt binds input-copy hashes to this portable artifact if later authorized.
- `<export_id>.report.json` and `.report.txt`: the portable loss/acceptance report
  described below. A renderer must escape data as text and never generate links
  from saved values.
- Integration instructions specifying the new metadata include and replacing the
  one active DMM include in a disposable DME. Do not edit the normal DME or map
  selection on export. Existing referenced code/assets remain dependencies; do
  not copy player-created images, runtime resources or external file references.

The checked-in [geometry example](save-to-map/geometry.expected.dmm) intentionally
has no metadata object and is only a geometry fragment. Its companion metadata,
job setup, DME staging and startup behavior remain acceptance work. Do not present
the fragment as a finished playable export.

## Portable report, explicit loss and failure

Report vocabulary: `excluded_by_policy`, `unsupported_static`, `reset_to_default`,
`unavailable_in_save`, `invalid_input`, `limit_exceeded`, `validation_not_run`.
Unknown state is not equivalent to an intentional reset. Every consumed spatial
entry and discovered field is assigned a disposition. If a subtree is skipped,
count its root once and mark descendants `not_inspected`; do not invent totals.

The portable report contains schema version, scope, policy/profile ID, independent
`geometry_status`, `playability_status`, `compile_status`, `privacy_validation`,
aggregate object/field/unknown-subtree counters, bounded grouped reason codes,
and next actions. Type/field labels come only from a fixed public catalog;
unknown labels become `unknown_static_type`/`unknown_field` rather than echoing
input-controlled names. Never report raw values, even in errors, exception text,
hashes of credentials, paths, generation IDs, player refs or player coordinates.
Private saved entry IDs are replaced with export-local static handles. An optional
static coordinate diagnostic requires separate local review; defaults use counts.

Return `rejected` without a complete map when terrain, topology, required
metadata/spawns, source provenance or structural integrity cannot be established.
An explicit `incomplete_preview` may retain a report and inspectable geometry
where unsupported objects are omitted, but it is never marked reusable/ready.
There is no automatic acceptance of losses by a `--force` switch. Deliberate
new-round resets are documented in the selected reviewed profile and the report;
unsupported static loss requires review of a concrete report before integration.
Excluded player/runtime state is always disclosed by category, without identities.

[The report example](save-to-map/report.example.json) is generated from a
synthetic preview scenario with an unsupported door and excluded data. Its counts
describe synthetic input, not a measured save. The golden geometry fixture is a
separate all-static case. All current packages remain geometry-only and
`ready: false`; the core emits no companion metadata or job registration.

## Verification stages and review decision

1. **Initial design evidence:** the original 63 checks validated hand-authored
   examples. They rendered the tiny palette in memory for golden comparison,
   without executing an exporter or converting any saved world.
2. **Implemented offline core:** canonical validator/writer/reporter and tests
   execute real conversions of synthetic canonical JSON. Cover malformed/missing/duplicate cells; uniform key widths; multi-z edge
   cells; stable repeated bytes; text injection (`[]`, quotes, slashes, newlines);
   unknown types/fields; nonfinite/out-of-range values; traversal/cycles; nested
   player contents; fake credential canaries absent from every output and error;
   failed writes; input/output aliasing, reparse/hardlink and overwrite rejection;
   report saturation and file/graph/cell budgets. No `.sav` reading in this stage.
3. **Future native reader, unimplemented and unverified:**
   prepare and generate tiny synthetic native format-2 files with the actual
   serializer in isolated adapters. Establish scalar/type extraction without
   constructing saved entities; optional-field absence and closed-file original
   hashes must remain unchanged on success/rejection. Mixed generations, marker
   failures, missing shards, invalid references and legacy input must reject.
   Use synthetic data only. A native reader fixture needs its own reviewed
   finite-run/isolation procedure.
4. **Native compilation, unrun:** stage a unique DME in an isolated source tree with
   the new companion declaration and exactly one DMM include, following the
   inactive Dagger pattern. Require BYOND 516.1681, zero warnings/errors and a DMB;
   preserve a missing-type control and exact source/package hashes. Compilation
   proves source compatibility, not startup equivalence or playability.
5. **Later authorized isolated new-round acceptance:** fresh-process map start
   without any save present; compare static geometry, authored properties,
   object multiplicity, constructor-adjusted materials, area identities, spawn
   registry/job landing and absence of procedural regeneration/duplicate roofs.
   Require actual native source-to-map-to-startup comparison before calling a
   type/field round-trippable. Test map scale separately from the tiny fixture.

The [proposed synthetic companion profile](save-to-map/synthetic-profile.md)
traces a direct base metadata subtype and a new civilian proof job. It is not
registered, generated by the core, compiled or established as playable. Review
its declaration and registration requirements before integration. Native save
extraction, complete real-world topology provenance and constructor fidelity
remain unresolved future work. No static-core test establishes those properties.
