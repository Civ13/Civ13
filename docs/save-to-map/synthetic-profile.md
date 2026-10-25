# Proposed synthetic new-round companion profile

Status: proposed, unregistered and not native-tested. Profile ID:
`synthetic-static-v0`. This is a minimal future acceptance fixture for the static
source core, not a gameplay map or evidence of full-world export. No executable
DM companion or DME registration is generated in the current milestone.

## Source trace at fa363b8a01ed7d936c10a6303ce1be4c26d82ab0

- `code/game/objects/map_metadata/_map_metadata.dm`: the base metadata `New()`
  sets global `map`, copies faction organization and creates the win-condition
  datum; it also starts wind/religion/tip scheduling. Its random berry placement
  branch requires `nomads`, `civilizations` or selected preexisting map IDs.
- `code/modules/1713/roundstart_etc.dm`, `nature()`: map seeding is selected by
  `(map.nomads && !map.override_mapgen) || map.force_mapgen`. A direct base
  subtype with both generation selectors disabled avoids this identified route.
  This source trace does not prove all startup side effects are absent.
- `code/modules/1713/jobs/civilian.dm`: civilian jobs have faction `"Human"`.
  `jobs/_special.dm` maps civilian job subtypes to `CIVILIAN` and declares
  `allowed_maps`, `min_positions` and `max_positions`.
- `_map_metadata.dm`, `job_enabled_specialcheck()`: a nonempty `allowed_maps`
  list matches the metadata's ID exclusively. An invented job title without a
  registered datum would not be enough.
- `code/game/jobs/job_controller.dm`, `SetupOccupations()`: constructs job
  types and keeps faction `"Human"`; `initialize_position_limits()` initializes
  each non-placeholder job's capacity from min/max. `GetJob()` resolves titles.
- `job_controller.dm`, `relocate()`: uses `H.original_job.spawn_location` when no
  override is supplied, looks up `latejoin_turfs`, and otherwise falls back to
  `(48,50,1)`. That fallback is outside the 3x2x2 synthetic fixture and cannot
  count as successful registration. Relocation also refuses a structure on the
  chosen tile; checking only turf density would miss that condition.
- `code/game/objects/effects/landmarks/normal.dm`, landmark `New()`: registers a
  normal named landmark in `latejoin_turfs[name]` and deletes the marker. Lobby
  `start` landmarks use a separate registry; they require their own future
  admission and constructor tests rather than borrowing a latejoin coordinate.

## Proposed declaration values for review

Use a new **direct child** `/obj/map_metadata/static_export_proof` of the base
metadata, with no copied save variables, no custom `New()` and no inheritance
from a procedural map subtype. Proposed fixed settings:

```dm
/obj/map_metadata/static_export_proof
    ID = "STATIC_EXPORT_SYNTHETIC_V0"
    title = "Static source export proof"
    faction_organization = list(CIVILIAN)
    availablefactions = list("Static Export Observer")
    faction1 = CIVILIAN
    faction2 = CIVILIAN
    roundend_condition_sides = list()
    nomads = 0
    civilizations = 0
    force_mapgen = 0
    override_mapgen = 1
    persistence = 0
    no_time_of_day_cycle = 1
    fob_spawns = 0

/datum/job/civilian/static_export_proof
    title = "Static Export Observer"
    faction = "Human"
    allowed_maps = list("STATIC_EXPORT_SYNTHETIC_V0")
    spawn_location = "JoinLateCivilian"
    min_positions = 1
    max_positions = 1
```

These are reviewable source declarations, not compiled fixture output. Base
metadata scheduling and ordinary civilian/base equip/name methods would still
run; the proposal does not claim an inert world. A source-only type/ID/job-key
trace is insufficient to establish lobby access, round start or safe win logic.
The proposed one-faction setup and empty round-end sides specifically need native
acceptance before being used outside the proof.

Future registration must include the companion declaration after its base
metadata/job declarations and required defines, place exactly one metadata
object at `(1,1,1)`, retain an unobstructed `JoinLateCivilian` marker and separately
provide a validated lobby `start` marker. The current core's whitelist does not
admit a metadata object or `start` token; adding them requires explicit policy,
source and fixture changes. Replace exactly one active DMM include in a
disposable root-local DME. Do not edit normal map selection to test it.

Before calling it playable, require native compilation with BYOND 516.1681 and
zero errors/warnings; a fresh new-round start without any saved state; exactly
one `map`; job discovery/enabling/capacity/title lookup; lobby and latejoin
registry membership; actual landing on the intended tile; preservation of
geometry, chair count/order/materials and area identity; and no unwanted
procedural regeneration or immediate round finish. All of these are unrun.
Complete topology provenance for real saved worlds remains unimplemented.
