# Integration and persistence contract

## Ownership and shared room producer

Shared producer design: [draft #3346](https://github.com/Civ13/Civ13/pull/3346),
[ERA-AND-SCENARIOS.md](https://github.com/Civ13/Civ13/blob/26c05cd8f85821c3ce76dcc72e3f0e61378c7ac4/docs/liminal/ERA-AND-SCENARIOS.md)
and `docs/liminal/ROOM-GENERATION.md`, profile
INDOOR_LIMINAL, authored catalog liminal-authored-rooms/0.1.0 with digest
`7ee6647de885a921746f9ac9d0ec5fa9e5140a30a8c06294cd4ff16c3d37c95b` at audit
time. Do not copy its generator, room masks, RNG or escape-mode state machine.
This branch must remain independently reviewable without those unmerged files.
Use that proposal's three separate authorities: immutable LevelTemplateRef,
mutable LevelInstanceRef and scenario policy in ScenarioSpec. A template ID is
a geometry-input hash; an instance ID is authority-minted mutable-world lineage.
Two colonies can use the same template without sharing an instance or inventory.
ScenarioSpec binds EXPEDITION, version, year and era catalog admission separately
from geometry. None of these identifiers implies a loaded, native-ready world.

Required producer contract, to be supplied through a separately pinned dependency:

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

Do not assume native z2, room IDs or current catalog digest remain constant in a
new producer version. The colony binding is immutable and rejects mismatches.
The first foundation stores the complete **manifest SHA-256** as content identity;
this binds more than the catalog alone. It does not generate a room or validate
the producer's geometry itself.

## Narrow power seam and independent first slice

Implement standalone `/datum/backrooms_supply` and
`/datum/backrooms_gateway_core` in `code/modules/1713/backrooms/gateway_core.dm`.
No singleton, process, map metadata, live doorway or default-enable setting.
The file can be included for type availability without instantiating anything.

The supply has finite integral charge/capacity and connected status. Its
`draw(units)` rejects invalid requests/insufficient/disconnected supply without
partial debit. `credit(units)` is an accounting seam; a future paid pack handler
must perform exact item debit and credit in one no-yield section. Direct calls
are internal trusted code, not player authority or a recipe implementation.

The core binds immutable `scenario_id`, `colony_id`, `gateway_id`, `instance_id`,
`template_id`, `scenario_spec_sha256` and `manifest_sha256`, plus year/tier policy.
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
unknown schema, fractional/out-of-range charge, year/tier/content/identity
mismatch reject before changing the current controller or source. Records use
bounded ASCII opaque IDs and lowercase 64-hex digests. No native object refs,
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
| docs/new-z-budget.md, tests/new_z_budget | Dynamic allocation is held UNMEASURED; no new production bypass |
| docs/liminal/ROOM-GENERATION.md on generator-owner branch | Shared abstract authored rooms; native teleporting explicitly unsupported |

Use in-repository doorway/computer/light/material art only after exact state and
constructor audits. No new image generation or third-party asset transfer.
Full-game acceptance needs actual captures, never topology diagrams as gameplay.
