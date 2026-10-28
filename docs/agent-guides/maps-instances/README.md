# Maps instances: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- Offline procedural geography -->
`tools/procedural_maps` generates new offline IR/DMM/sidecar bundles only.
Run `python3 -I -B tests/procedural_maps/run.py --historical-catalog-root <v1-checkout> --intermediate-catalog-root <v2-checkout>` with a verified interpreter.
Keep source pins, versioned configs, graph/raster invariants and old golden hashes.
Abstract supplies and the frozen resource proposal are not native playability;
no live map, saved world or native engine is read/applied/launched by this tool.

<!-- 2026-10-27: disabled Backrooms expedition foundation -->
`docs/backrooms-expedition` separates powered colonization from finite escape.
`gateway_core.dm` contains uninstantiated finite-charge/lifecycle/identity datums,
not a teleporter or world-save adapter. Template hashes never replace mutable
instance identity. `tests/backrooms_gateway` projects pure source guards offline
and prepares native savefile/lifecycle assertions without launching. Native runs
require the bounded plan review; compilation does not prove movement or rescue.
Use the console `dm.exe`, not the GUI `dreammaker.exe`, for Windows compilation.


## Maps

<!-- 2026-10-18: centralized level admission -->
Dynamic z growth must reserve its complete target through world_z_budget before
the first native resize. The uncalibrated hard ceiling is 1,400,000 total grid cells,
with one roof-added plane and lower-only host settings. Production additionally
refuses new growth as UNMEASURED until a calibrated memory/headroom profile is
reviewed; configuration cannot bypass this. Isolated tests select a tests-only
subclass, never a production opt-out. This is not an OOM guarantee. Overcap saved expansion holds before mutation and blocks
later save overwrite. See docs/new-z-budget.md and tests/new_z_budget/prepare.py;
source preparation does not establish native acceptance.

- Maps use lowercase names with `_` for spaces.
- WIP maps go in `maps/WIP/`.
- No second z-levels unless same size as main level.
- Map backups should use Git, not saved copies in the repo.

### DMM format rules

<!-- 2026-10-16: standalone map constants -->
- Emit literal DMM overrides such as `locked = 1`, not DM macros such as `TRUE`.
  MapDiffBot's standalone map reader rejects unresolved variables in map values.

- All tile keys within a map **must be the same length** (all 2-char or all 1-char). Mixing breaks BYOND's parser.
- Every grid row must have exactly `world.maxx` tile keys. Different row widths cause load failures.
- Grid rows in the file are ordered top-to-bottom (Y=maxy first, Y=1 last).
- `(1,1,1)` is the bottom-left tile of the map.
- Tile definitions can layer multiple atoms: `(/obj/foo, /turf/floor/bar, /area/baz)`. Objects are listed before the turf, turf before area. The first element is rendered on top.
- Vars on objects use `{var = value}` syntax within tile defs: `(/obj/foo{tube_id = 3}, ...)`. Multiple vars separated by `;`.
- Object placement: to put an object on a floor tile, define a new tile key that includes the object + the floor turf + the area, then use that key in the grid at the desired position.

### Map metadata

<!-- 2026-10-27: coded minimap grid boundaries -->
get_coded_loc uses one-based tiles with fixed 22x22 default, 15x10 campaign and
40x40 Falcon cells. CAMPAIGN_MAP_LIST_MAPID_OR starts with a bare map constant;
its comparison-prefix callers differ from standalone Boolean callers. Keep the
grid's explicit ID selection local rather than globally changing that macro.
tests/aotd_map/test_coded_loc.py projects the helper offline; it is not native
HUD acceptance. Campaign DMM extents exceed the legacy ten-row/column frame;
this correction preserves those cell sizes rather than rescaling their maps.

<!-- 2026-10-24: optional geographic elevation -->
Elevation is a bounded coordinate profile on map metadata, independent of native
areas/turf identity and climate. `get_elevation(atom)` defaults to 0 metres; it
does not alter temperature or precipitation. The optional round.json snapshot
is validated before mutation and installed before replacement constructors;
missing legacy snapshots restore flat zero, overriding newer author defaults.
See docs/elevation.md and tests/elevation. Native fixture preparation does not
establish native acceptance; run only under the repository's normal
authorization/admission rules.

<!-- 2026-10-24: save-to-map design boundary -->
`tools/save_to_map` is a synthetic static-source validator/writer/reporting proof,
not a native save converter. Its exact-type policy must not imply broad coverage.
`docs/save-to-map-export.md` describes the broader design and remaining limits.
Saves lack a complete area membership grid and startup landmarks can self-delete;
require pinned source topology/spawn provenance rather than guessing from saves.
DMM Suite comments describe writing, but this checkout includes only its reader
and utilities. Never export changed vars wholesale or reconstruct a game to
extract map source. The accompanying examples are synthetic, not native evidence.

- Each map has a `/obj/map_metadata` subtype that handles game mode logic.
- The metadata object is placed in the DMM at a consistent position (conventionally `(1,1,1)`) on any turf.
- `New()` on the base `/obj/map_metadata` sets `map = src`, clears icon, copies faction lists, and starts background timers.
- Subtypes override `New()` to call `..()` then do map-specific init (spawning datums, registering turfs, etc.).
- `update_win_condition()` drives round-end logic (checked every tick).
- Map IDs are defined as `#define MAP_XXX "XXX"` in `code/__defines/maps.dm`.
- The metadata `.dm` file must be `#include`d in `civ13.dme` **after** any defines it references.
- Win conditions: call `world << "<font>..."` for announcements, set `game_over = TRUE` and `ticker.finished = TRUE` to end the round.

### Player spawning

<!-- 2026-10-17: lobby dispatch diagnosis -->
The private own-Host snapshot reports bounded own-client and current-lobby Join entry/phase
codes. Compiled verb visibility and a successful client menu action do not prove
server dispatch; require the entry counter or a real human spawn. The cache is
excluded from custom saves. Lobby phase disappears on mob replacement; the small
client entry cache survives that transfer. The client-owned Join command forwards
only its own invoking current lobby mob into the existing admission handler.

<!-- 2026-10-17: invisible lobby verb accessibility -->
Lobby mobs have invisibility 101. Native lobby verbs must explicitly use
`set invisibility = 0`: BYOND otherwise inherits source invisibility for command
accessibility, even when a native menu item is visible. Preserve mob invisibility
and player vision; verify actual connected-client invocation.

<!-- 2026-10-16: restored occupation capacity -->
Active saved-round restoration skips fresh setup/autobalance. Initialize job
position limits separately via `job_master.initialize_position_limits()` in
current and owned-legacy restores; do not rerun faction/squad/map setup or reset
current occupancy. The world-save round-state fixture extracts the actual
fresh-join availability/assignment gates; its `jobs` omission control must fail.

- Jobs define `spawn_location = "JoinLateXXX"` (a string key).
- Maps place `/obj/effect/landmark{name = "JoinLateXXX"}` objects in the DMM at spawn turfs.
- At load time, `/obj/effect/landmark/New()` stores the turf in `latejoin_turfs[name]` (global assoc list), then `qdel(self)`.
- `job_controller.relocate()` picks a random turf from `latejoin_turfs[spawn_location]` and sets `H.loc = spawnpoint`.
- A mob-level `job_spawn_location` var overrides the job-level value if set.
- Fallback if no landmark found: `locate(48,50,1)` (hardcoded).

### Map object placement (codebase-specific)

- Existing maps place objects directly in DMM tile definitions (not spawned in code).
- `/obj/effect/landmark` tiles get `qdel(self)` after registering - they're invisible after load.
- Object tiles stack: `(/obj/chair, /turf/floor, /area/room)` puts a chair on the floor.
- Console/machinery objects use `density = TRUE` and `anchored = TRUE` - they block movement.
- For maps with many objects, define tile keys systematically (e.g., "oa", "ob", "oc"...) to keep things manageable.

<!-- 2026-10-20: extraction instance collateral -->
The historical extraction instance fixture at b717ad2a6 shared registry state
across assertions. Its overlap/generation mutants caused downstream failures as well as
their named targets. Run 39140469088 preserves complete native results; keep its
failed verdict intact. Explaining collateral is not approval to weaken the
single-target oracle. See docs/extraction-instance-contract.md.

<!-- 2026-10-19: inactive Dagger compilation -->
`tests/dagger_map/compile_map.py` compiles the inactive DMM with production types
in a disposable root-local DME, plus a missing-type diagnostic control. CI's
`dagger_map_compile` opt-in retains exact-head logs. No game starts; successful
compilation is not controller, instancing, protection or gameplay acceptance.
