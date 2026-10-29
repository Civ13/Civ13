# Integration and persistence contract

## Ownership and shared room producer

Shared producer design: [merged #3346](https://github.com/Civ13/Civ13/pull/3346),
[ERA-AND-SCENARIOS.md](../liminal/ERA-AND-SCENARIOS.md) and
[ROOM-GENERATION.md](../liminal/ROOM-GENERATION.md). The separate
[offline topology tool #3348](https://github.com/Civ13/Civ13/pull/3348) is merged;
it emits JSON, not native DMMs or a playable scenario. Its profile is
INDOOR_LIMINAL. The original liminal-authored-rooms/0.1.0 catalog/digest is
historical proof input, not an expedition content pin. Version-1 previews were
rejected as room designs; [the shared status](../liminal/README.md) records that
limitation. Revised room geometry is not approved by either merge.
Do not copy its generator, room masks, RNG or escape-mode state machine.
Use that proposal's three separate authorities: immutable LevelTemplateRef,
mutable LevelInstanceRef and scenario policy in ScenarioSpec. A template ID is
a geometry-input hash; an instance ID is authority-minted mutable-world lineage.
Two colonies can use the same template without sharing an instance or inventory.
ScenarioSpec binds EXPEDITION, version, year and era catalog admission separately
from geometry. None of these identifiers implies a loaded, native-ready world.

Required expedition producer contract, still to be supplied through a separately
pinned dependency rather than inferred from the escape tool's example output:

1. A verified finite room manifest: profile/schema/algorithm/catalog/palette
   versions and SHA-256, exact seed/config, stable room/zone/socket IDs, tile
   footprint, logical layer ID, geometry and complete validation receipt.
2. An expedition recipe using the same room profiles, with ARRIVAL plus safe
   colony construction space, survey branches, supply/utility space and return
   approaches. Do not reuse escape progression requiring FOUND_MARKER or
   SERVICE_DONE to return home. A new recipe belongs to the generator owner.
3. Native export pins and literal DMM parse-back proof for the exact output;
   same-size surface/backrooms planes with explicit logical-layer mapping.
4. Stable authored anchor IDs for primary arrival/return, 4 ordered landing-pad
   candidates per end, a separate emergency home evacuation pad, colony stores,
   construction exclusions and no-threat/safe route reserves. Prove conservative
   actor clearance and return reachability independently of escape flags.
5. Reject unsupported LEVEL_PORTAL sockets. They are unsupported in the current
   room proof; this scenario binds explicit anchors at its native gateway seam
   only after reviewed export. Room connection metadata is not an actual portal.
6. Provide semantic against-wall/open-floor/narrow-passage furnishing slots,
   functional room themes and deterministic initial placement records. Preserve
   construction plots and every arrival, return, rescue, socket and work approach;
   validate the dressed geometry, not just its previously empty room graph.

Do not assume native z2, room IDs or current catalog digest remain constant in a
new producer version. The colony binding is immutable and rejects mismatches.
The first foundation stores the complete **manifest SHA-256** as content identity;
this binds more than the catalog alone. It does not generate a room or validate
the producer's geometry itself.

### Template ID representation boundary

The merged tool's `civ13-generated-level-template/1` contract in
`tools/liminal_maps/contracts.py` emits `template_id = "sha256:" + digest`, with
the digest computed over canonical immutable identity inputs. The merged power
foundation's schema-1 binding field named `template_id` accepts only the raw
lowercase 64-hex digest. They are different wire representations, not competing
instance IDs. Passing the prefixed tool value directly must reject.

A future versioned adapter must validate the exact supported template schema,
recompute its canonical identity hash and require the exact `sha256:` prefix plus
64 lowercase hex characters before extracting that digest into the core field.
Round-trip reconstruction must equal the original full template ID. Reject
unknown algorithms, schema versions, malformed/extra prefixes or identity
mismatches; do not truncate arbitrary strings or hash the printed ID again.
Keep the full template contract and its manifest/content pins alongside the
binding. This is a specified adapter, not one implemented by these documents or
by the standalone core. Neither successful decoding nor a topology receipt can
approve geometry, era policy or a loaded instance.

## Narrow power seam and independent first slice

The merged [#3351](https://github.com/Civ13/Civ13/pull/3351) supplies standalone
`/datum/backrooms_supply` and `/datum/backrooms_gateway_core` in
`code/modules/1713/backrooms/gateway_core.dm`.
No singleton, process, map metadata, live doorway or default-enable setting.
The file can be included for type availability without instantiating anything.

The supply has finite integral charge/capacity and connected status. Its
`draw(units)` rejects invalid requests/insufficient/disconnected supply without
partial debit. `credit(units)` is an accounting seam; a future paid pack handler
must perform exact item debit and credit in one no-yield section. Direct calls
are internal trusted code, not player authority or a recipe implementation.

The core binds immutable `scenario_id`, `colony_id`, `gateway_id`, `instance_id`,
`template_id`, `scenario_spec_sha256` and `manifest_sha256`, plus scenario year.
The period tier/roster policy belongs to the separately hashed ScenarioSpec and
future admission provider; the core does not enforce a research catalog.
The immutable template digest and mutable instance lineage are both required;
neither a seed nor a template digest can substitute for instance identity.
`start(now, destination_ready)` charges
startup and first maintenance interval together. `service(now, destination_ready)`
charges one upcoming interval only at its exact deadline, faults on missed
intervals, disconnect/invalid supply, time reversal or lost destination, and
becomes READY only after the uninterrupted startup deadline. `stop()` is immediate;
`can_cross(now, destination_ready)` is a **power-state predicate**, not movement,
authorization, a crossing payment, an occupancy slot or a transaction token.
The future native adapter must execute all DESIGN.md guards independently.
In particular, core READY means only power readiness. Actual scenario/native
readiness must remain false until the period roster/research catalog, physical
destination and rescue contracts are admitted. A true test argument is an
adapter input, not proof that any of those integrations exists.

Time is explicit integral deciseconds in 0..16776000 from the scenario owner,
monotone within its clock epoch. The bounded core fails closed beyond that range;
a future long-running owner must renew its clock epoch while OFF, never reset a
live lease. It has no production clock/scheduler adapter. The first foundation uses fixed reviewed costs and times;
configurable overrides wait for validation tests. Faults preserve every colony
identity and charge. Repair/start is explicit. `can_cross` requires current
maintenance (now strictly before its next deadline); service handles the boundary
first. Crossing energy remains unavailable if less than its fixed cost remains.
Callers must notice source disconnection directly at transfer admission; they
cannot rely on a delayed polling update.

## Save identity, validation and publication

The first slice has an explicit scalar/list snapshot contract, **not** automatic
integration with Civ13's world serializer. Snapshot schema 1 has exactly four
fields: schema, binding, supply_capacity and supply_charge. Binding contains only
scenario_id, colony_id, gateway_id, instance_id, template_id, scenario_spec_sha256,
manifest_sha256 and scenario_year. Restore compares against expected identity/policy
provided by trusted scenario construction. Missing/extra/malformed fields,
unknown schema, fractional/out-of-range charge, year/content/identity
mismatch reject before changing the current controller or source. Tier/roster
enforcement remains a separate scenario-owner gate, not a schema-1 scalar test.
Records use bounded ASCII opaque IDs and lowercase 64-hex digests. No native object refs,
runtime endpoint pointers, ready/start flags, charge connection, clocks,
reservations, cooldowns or active operations survive restoration. Successful
restore publishes a disconnected supply and OFF core; a new paid start is needed.
Exporting while powered preserves spent charge but never resumes powered state.

Before physical deployment, a scenario metadata owner must integrate this record
into the **same complete world-save generation** as both surface and colony:
durable colony UUID, parent scenario/world lineage, gateway pair IDs, logical
layer bindings, source/content/recipe/policy versions, survey state, emergency
return entitlements, material stocks and actual native construction/contents.
Use the existing serializer, zone identities, complete-generation admission,
preflight and atomic publication. Do not invent another world save format.
The ordinary per-z cross-reference guard stays intact: persistent portal links
store scalar IDs, resolved after every level is restored, never cross-z object
pointers. Explicitly exclude all future runtime controller fields on **export
and legacy import**; custom saves enumerate changed tmp fields too.

Save/load gates suspend new crossings; no half-captured transfer is allowed.
Both planes and scenario metadata restore together, validate expected content
and identity before ClearMap, then rebind logical anchors, reclaim occupancy from
actual bodies and rebuild runtime ownership only after world readiness. Restored
gateway starts OFF even if the old save was READY. Retain original generations
on malformed data and never replace a missing colony with a fresh seed. No partial
surface-only recovery, identity reuse, silent reset or automatic UUID migration.
If capacity is exceeded by an old save, preserve all inhabitants, block new entry
and permit safe powered returns. Body ownership must follow current reclaim,
not nickname or lastKnownCkey guesses.

Full-game save tests must use tests/world_save's actual serializer and temporary
files, including construction, nested/aliased contents, injury, zone IDs, both
levels and rejected mismatches. The foundation's snapshot disk test proves only
its scalar ABI and atomic rejection; it does not establish world-save support.

## Audited source and asset seams

Baseline `10d264e5896221b34949ee4b67c0fd2b94bde249` observations:

| Source | Observation and limit |
| --- | --- |
| code/game/objects/effects/bump_teleporter.dm | First matching ID, delayed spawn and persistence_set_loc; no power, unique-pair, footprint or stale-epoch guarantee |
| code/game/atoms_movable.dm | persistence_set_loc checks save movement then raw loc; forceMove has Entered/Crossed callbacks |
| code/modules/1713/machinery/cables.dm, engines/engines.dm, batteries.dm | Real capacity/demand, fuel and storage mechanics exist; no automatic gateway consumer |
| code/modules/1713/machinery/modern_generation.dm | Modern generators require ordinal_age >=8; runtime supply/registration excluded from saves |
| code/modules/1713/structures.dm /obj/structure/props/power_transformer | Anchored dense visual prop; no generation or cable accounting handler |
| code/game/objects/items/paper/photography.dm | Film camera/coldwar and video-camera declaration; video recording not established |
| code/modules/1713/radio.dm | Existing frequency/radio types; cross-z availability/occlusion needs native testing and policy |
| code/modules/1713/lantern.dm | Existing flashlights; do not invent battery scarcity from their appearance |
| code/modules/1713/modern_terminal.dm | Powered local cable text terminal; not an Internet/email system |
| code/game/objects/structures/table.dm, filingcabinet.dm; code/modules/1713/structures.dm | Wooden table work surfaces, functional paper cabinets and the 1980_computer_on prop are candidates for purposeful office dressing; type presence does not admit a desk assembly, working computer or worn/native visual result |
| docs/new-z-budget.md, tests/new_z_budget | Dynamic allocation is held UNMEASURED; no new production bypass |

Later shared dependencies are the merged `docs/liminal/ROOM-GENERATION.md` and
`tools/liminal_maps/contracts.py` from #3346/#3348. They are not part of the
historical baseline above. Current native export/era admission and the expedition
recipe remain absent; version-1 room previews are rejected.

Use in-repository doorway/computer/light/material art only after exact state and
constructor audits. No new image generation or third-party asset transfer.
Full-game acceptance needs actual captures, never topology diagrams as gameplay.
The Art of the Deal may inform office composition and environment-appropriate
asset use; its room raster, object coordinates and generic modern loadouts are
not inputs copied into the expedition template.

## External code references and import limits

These pinned source files were read as design references. No external code,
layout, sprite or audio is copied into this scenario:

| Reference | Useful observation | Boundary for this scenario |
| --- | --- | --- |
| [BackroomStation modular loader](https://github.com/Posshum/backroomstation/blob/6c247ffb57193e2e550eb8ea9f3112eedbad795c/code/modules/mapping/modular_map_loader/modular_map_loader.dm) | Selects an authored DMM module from a configuration key and offsets its load origin using a connector marker | Marker alignment is not a multi-socket topology solver, collision proof or progression validator. Do not inherit its asynchronous live-loading lifecycle or random selection as our generation contract. |
| [Yogstation maintenance dressing](https://github.com/yogstation13/Yogstation/blob/ae2886be95c234202212a3090ee7637173ea2c1d/code/datums/mapgen/dungeon_generators/maintenance_generator/maintenance_generator.dm) | Separates against-wall, open-floor and narrow-hallway feature lists; its Backrooms theme supplies floor/wall/feature choices | Reuse the semantic distinction in our own profile requirements. Independent pick/weighted selection is not deterministic replay or a return-route proof. Its Backrooms subclass disables APC/firedoor generation; do not import a station power system with the dressing idea. |

Other researched lifecycle/teleporter patterns remain candidates for a separately
pinned source audit: distinguishing a template key from an allocated round-level
does not establish durable colony identity, and checking powered/engaged state
does not make sequential movement of buckled entities atomic. Keep explicit
instance lineage and the single-actor crossing transaction in this contract.

Before proposing any code or asset port, record the exact repository revision,
file path/hash, applicable per-file license and notices, dependencies and planned
modifications, then review compatibility with Civ13 distribution. A repository's
AGPL or MIT label is not blanket clearance for its artwork/audio or every file.
Maintrooms-BG's NC-licensed candidates, mixed Goon artwork and unattributed audio
remain held; consideration is not import approval. Existing Civ13 art and our own
authored layouts remain the first implementation choice. This reference audit
does not clear any third-party file for copying or native execution.
