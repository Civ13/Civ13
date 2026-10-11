# Civ13 - Agent guide

## Language & toolchain
NEVER use "—": always use "-" instead.
- **DM** (DreamMaker) - BYOND's proprietary language. Sources have `.dm` extension.
- **Entry point**: `civ13.dme` - the DM Environment file.
- **Build**: `dm civ13.dme` (Windows) or `DreamMaker civ13.dme` (Linux). Outputs `civ13.dmb` + `civ13.rsc`.
- **Lint**: `./dreamchecker.exe` (SpacemanDMM static analyzer). Config in `SpacemanDMM.toml` (sets `dreamchecker = true` for the langserver).
- **Required BYOND version**: 516.1681 (enforced in CI and `.vscode/tasks.json`).
- **CI** (`.github/workflows/test.yml`): installs BYOND 516.1681 on Ubuntu, runs `DreamMaker -max_errors 0 civ13.dme`, fails on any errors or warnings. A separate evidence-checker job runs synthetic Python tests without executing the game. The MCP protocol workflow separately tests local tooling on Windows and Linux; it does not run gameplay.

## Code structure

| Path | Purpose |
|---|---|
| `code/` | Core game code: atoms, mobs, objects, turfs, helpers, defines |
| `code/__defines/` | Global constants, macros, flags |
| `code/modules/1713/` | Bulk of Civ13-specific content (apparel, jobs, weapons, vehicles, sieges, etc.) |
| `code/modules/admin/` | Admin tools and verbs |
| `maps/` | Map (`.dmm`) files organized by era (e.g. `maps/5000bc/`, `maps/1913/`, `maps/nomads/`) |
| `config/` | Server configuration (`config.txt`, `admin_ranks.txt`, `host.txt`) |
| `scripts/` | Linux deployment scripts (`launch.py`, `updateserver.py`) |
| `UI/` | HTML/CSS interface files |
| `icons/` | Game sprites (`.dmi` files) |
| `sound/` | Audio assets |
| `SQL/` | Database integration (Discord bot OOC bridge via file polling) |

## VSCode integration (`.vscode/tasks.json`)

Available tasks:
- **`dm civ13.dme`** - build the project (default build task)
- **`DreamChecker`** - run static analysis
- **`OpenDream Build`** - compile with DMCompiler (`--version=516.1681`)
- **`Build and Check`** - sequential: build then lint

## OpenDream

An experimental open-source BYOND reimplementation. `.vscode/launch.json` has an "OpenDream: Build & Run" configuration using `DMCompiler.exe` and `Robust.Server.exe`. The JSON output is `civ13.json`.

## Maps

- Maps use lowercase names with `_` for spaces.
- WIP maps go in `maps/WIP/`.
- No second z-levels unless same size as main level.
- Map backups should use Git, not saved copies in the repo.

### DMM format rules

- All tile keys within a map **must be the same length** (all 2-char or all 1-char). Mixing breaks BYOND's parser.
- Every grid row must have exactly `world.maxx` tile keys. Different row widths cause load failures.
- Grid rows in the file are ordered top-to-bottom (Y=maxy first, Y=1 last).
- `(1,1,1)` is the bottom-left tile of the map.
- Tile definitions can layer multiple atoms: `(/obj/foo, /turf/floor/bar, /area/baz)`. Objects are listed before the turf, turf before area. The first element is rendered on top.
- Vars on objects use `{var = value}` syntax within tile defs: `(/obj/foo{tube_id = 3}, ...)`. Multiple vars separated by `;`.
- Object placement: to put an object on a floor tile, define a new tile key that includes the object + the floor turf + the area, then use that key in the grid at the desired position.

### Map metadata

- Each map has a `/obj/map_metadata` subtype that handles game mode logic.
- The metadata object is placed in the DMM at a consistent position (conventionally `(1,1,1)`) on any turf.
- `New()` on the base `/obj/map_metadata` sets `map = src`, clears icon, copies faction lists, and starts background timers.
- Subtypes override `New()` to call `..()` then do map-specific init (spawning datums, registering turfs, etc.).
- `update_win_condition()` drives round-end logic (checked every tick).
- Map IDs are defined as `#define MAP_XXX "XXX"` in `code/__defines/maps.dm`.
- The metadata `.dm` file must be `#include`d in `civ13.dme` **after** any defines it references.
- Win conditions: call `world << "<font>..."` for announcements, set `game_over = TRUE` and `ticker.finished = TRUE` to end the round.

<!-- 2026-10-11: forced season decay control -->
`seasons(looping, force, advance_decay)` preserves debris age for forced calls
when the third argument is omitted. Natural calls count transitions. Forward
all three arguments in season overrides and honor `looping = FALSE` to avoid
starting extra recurring cycles from the admin command.

### Player spawning

- Jobs define `spawn_location = "JoinLateXXX"` (a string key).
- Maps place `/obj/effect/landmark{name = "JoinLateXXX"}` objects in the DMM at spawn turfs.
- At load time, `/obj/effect/landmark/New()` stores the turf in `latejoin_turfs[name]` (global assoc list), then `qdel(self)`.
- `job_controller.relocate()` picks a random turf from `latejoin_turfs[spawn_location]` and sets `H.loc = spawnpoint`.
- A mob-level `job_spawn_location` var overrides the job-level value if set.
- Fallback if no landmark found: `locate(48,50,1)` (hardcoded).

### Process scheduler integration

- Codebase uses legacy `/process/` system, not subsystems.
- Create a `/process/subtype` in `code/processes/`, set `name`, `schedule_interval`, `fires_at_gamestates`.
- Register the process var in `code/processes/__processes.dm`.
- `fire()` is called each tick; do your per-tick work there.
- Global singletons should be accessed via `global.xxx` or a `var/xxx` on a global datum.

### Map object placement (codebase-specific)

- Existing maps place objects directly in DMM tile definitions (not spawned in code).
- `/obj/effect/landmark` tiles get `qdel(self)` after registering - they're invisible after load.
- Object tiles stack: `(/obj/chair, /turf/floor, /area/room)` puts a chair on the floor.
- Console/machinery objects use `density = TRUE` and `anchored = TRUE` - they block movement.
- For maps with many objects, define tile keys systematically (e.g., "oa", "ob", "oc"...) to keep things manageable.

## DMI (sprite sheet) file format

DMI files are valid PNGs with an embedded `zTXt` metadata chunk. The chunk keyword is `Description` and its value is zlib-compressed text (after a null-terminator byte following the keyword). Decompressing it yields a plain-text JSON-like DM literal describing every sprite state.

### Extracting metadata (Python)

```python
import struct, zlib, json, re

def read_dmi(path):
    with open(path, "rb") as f:
        sig = f.read(8)
        chunks = {}
        while True:
            raw = f.read(8)
            if len(raw) < 8:
                break
            length, ctype = struct.unpack(">I4s", raw)
            ctype = ctype.decode("ascii", errors="replace")
            data = f.read(length)
            crc = f.read(4)  # skip CRC
            if ctype == "zTXt":
                # keyword is null-terminated, rest is zlib data
                nul = data.index(0)
                keyword = data[:nul].decode("ascii")
                compressed = data[nul+2:]  # skip keyword + null + compression type byte
                text = zlib.decompress(compressed).decode("utf-8")
                chunks[keyword] = text
    return chunks.get("Description", "")
```

The returned text is DM source like:

```
// BEGIN DMI
state_name = "icon_state"
    dir = SOUTH
    icon = 'icons/obj/items.dmi'
    frames = 1
    delay = 1
    loop = 0
// END DMI
```

### What's in it

- **state** - `icon_state` name referenced in code (`icon_state = "foo"`)
- **dir** - direction(s): SOUTH=1, NORTH=2, WEST=4, EAST=8, or combinations
- **frames** - number of animation frames
- **delay** - comma-separated frame delays (in ticks, 1 tick = 0.1s default)
- **loop** - animation loop count (0 = infinite)
- **movement** - whether the state is for movement animations
- **hotspot** / **crop** - optional pixel-level metadata

### Quick one-liner (no libraries needed)

```bash
python -c "
import struct,zlib,sys
data=open(sys.argv[1],'rb').read()
i=data.find(b'Description\x00\x00')
if i<0: sys.exit(1)
j=data.find(b'IEND')
chunk=data[i+len('Description\x00\x00'):j-4]
print(zlib.decompress(chunk).decode())
" myfile.dmi
```

This lets agents introspect sprite sheets without opening them in a GUI - useful for verifying icon_state names, checking animation frame counts, or auditing unused states.

## Server deployment

- Linux-only for production (scripts use `sudo`, apt, systemd-style paths).
- `scripts/launch.py` - pulls from git, rebuilds, copies config, runs `DreamDaemon`.
- `scripts/paths.txt` defines server paths and ports.
- Config in `config/config.txt` controls gamemodes, ports, hub visibility, logging, etc.
- Discord integration via Civilizationbot (file-based IPC through `SQL/discord2*.txt` files).

## Conventions

- `#define DEBUG` is set in `civ13.dme` (enables custom error handler).
- `_compile_options.dm` controls TESTING, UNIT_TESTS, REFERENCE_TRACKING, etc. - uncomment as needed.
- `.gitignore` excludes compiled outputs (`*.dmb`, `*.rsc`), log files, `data/`, `SQL/`, `dreamchecker.exe`, `civ13.json`, `TODO.md`.

<!-- 2026-10-11: repeatable game verification -->
## Game verification evidence

- Follow `docs/game-verification.md` for exact-commit build, isolated-fixture,
  graphical, season-memory, and save-round-trip evidence. Reuse probes present in
  the selected checkout; investigation-branch probes may not be on master yet.
- Game PRs need actual screenshots and reproduction steps, plus video when
  movement/timing requires it. Keep unavailable acceptance explicit. Current
  captures are internal testing material; no AI-generated art or mock evidence.
- Use `scripts/check-game-evidence.py` to validate existing bundles. Its success
  proves metadata/file consistency, not gameplay acceptance or OOM remediation.
  Tests live in `tests/test_game_evidence.py` and do not launch BYOND.
- Use temporary saves and external-effect adapters. Testing does not authorize
  production restarts, live season transitions/imports, or publishing captures.

## Agent self-maintenance

<!-- 2026-10-11: world-save verification -->
- Persistence regressions are in `tests/world_save`; the focused fixture uses
  the actual saver/loader with isolated adapters, and `run-game.ps1` exercises
  real constructors in temporary storage. New saves use version-2 typed values
  and sharded entries; retain legacy flat-entry reading. Never restore `loc`,
  `pixloc`, or client session fields as ordinary variables. Linux DreamDaemon
  `-safe` requires a relative log path inside the isolated working directory.

This file is read by every agent at session start. If you discover something
useful about the codebase that future agents should know, **update this file**.
Good candidates for additions:

- Gotchas that caused you to waste time (type mismatches, missing procs, naming
  conventions that differ from what you'd expect).
- Workarounds you had to apply and why (e.g. "lerp is reserved, use mix_value").
- Runtime truths: things that compile fine but break at runtime (empty lists
  passed to pick(), world-scan performance, list modification during iteration).
- File locations for subsystems you explored (process schedulers, global singletons,
  landmark systems, etc.).
- Anything you learned from CI failures or compiler warnings that isn't obvious.

When adding, keep it concise and put it under the most relevant existing section.
If nothing fits, create a new section. Prefix your additions with the date and
a brief tag so others can tell when and why it was added (e.g. `<!-- 2026-06-10: subcom audit -->`).

<!-- 2026-10-11: crafting validation -->
## Crafting checks

tests/crafting/README.md documents scripts/check-recipes.py, a compiled
BYOND recipe-schema/registration and isolated crafting-fixture check. Use the
current research-tree and map-mode gates when testing material registration;
zero legacy thresholds alone do not unlock node-gated or mode-only recipes.
<!-- 2026-10-11: observer reference bookkeeping -->
- Observer cleanup count lists retain their datum keys. Counts must reflect actual callbacks: duplicate global registrations do not increment them, and unregistering all callbacks subtracts their full count.
- `scripts/test-observer-memory.ps1 -ByondBin <BYOND-bin-directory>` runs complete production observer registration/cleanup code in an isolated fixture with temporary outputs and no game startup.
<!-- 2026-10-11: water registry replacement -->
- `water_turf_list` must track only current water turfs; turf replacement invokes `Del()` and retargets saved turf references. Water New/Del maintain registry indexes with constant-time swap removal.
- `scripts/test-water-memory.ps1 -ByondBin <BYOND-bin-directory>` checks subtype replacement, dry conversion and interleaved registry removals across 20 cycles without starting game systems.
<!-- 2026-10-11: season memory regression -->
- BYOND turf replacement calls `Del()` and preserves sleeping procs. Registry cleanup in `Destroy()` alone does not handle replacement; grass registration is maintained by grass `New()`/`Del()`.
- Dirt recovery uses an identity token so old sleeping recovery chains stop after turf replacement. Obsolete waits release their token when they wake (up to 20 minutes), without deleting live entities.
- `scripts/test-season-memory.ps1 -ByondBin <BYOND-bin-directory>` executes production turf lifecycle bodies in an isolated world, with accelerated recovery waits and temporary output. It checks repeated replacement, bounded grass registration, one recovery chain per dirt turf, and planted-soil behavior. Synthetic process memory is not full-game memory evidence.
<!-- 2026-10-11: evidence harness review -->
Native BYOND world.Export returns the remote Topic value, and its caller address includes a port (127.0.0.1:port). Reject empty/non-JSON replies and authenticate the tested commit before reporting evidence success. PowerShell native Git failures need explicit LASTEXITCODE checks; ErrorActionPreference alone is insufficient. The isolated evidence launcher must verify daemon readiness and clean its unique temporary DME/DMB/RSC outputs.
## Local MCP tooling

<!-- 2026-10-11: finite fracking verification -->
- `tests/hydraulic_fracturing/probe.dm` checks finite terrain conversion, batch
  costs, replacement cancellation and native contained-input disk saves through
  the resource-extraction launcher. Same-type `ChangeTurf()` can return the
  existing turf; use actual native replacement when testing replacement identity.
<!-- 2026-10-11: bounded mining yield comparison -->
- The resource extraction launcher's `tests/mining_yields/probe.dm` option adapts
  only RNG calls in the production mining body. It checks branch/era endpoints
  and finite conversion; fossils yield one (two in special caves), so do not
  claim every destructive resource exceeds two-unit renewable mineral batches.

<!-- 2026-10-11: petroleum save lifecycle -->
- Oil wells preserve barrels in native saved contents and rebuild runtime links after load. Constructors must not claim floor barrels: empty contents restoration can delete those links, while moving a contained barrel to its turf during save can omit it from the turf iteration. `tests/petroleum_lifecycle/probe.dm` checks disk-backed entry/turf round trips and bounded callbacks through the resource extraction launcher.
<!-- 2026-10-11: irrigation propagation -->
Irrigation propagates through cardinally connected channels with temporary local
lists. Ordinary floors and filled-in channels are not water sources; salt reaches
already-wet channels. Source removal does not drain existing channel water.
`tests/irrigation/run.ps1 -ByondBin <516.1681-bin>` checks production procedures,
including the pre-fix baseline; it does not prove map or construction acceptance.

<!-- 2026-10-11: isolated legacy garbage queue -->
When normal startup is disabled, atom `qdel` removes the atom from its location
and queues it in `delayed_garbage`; it does not set the newer `gc_destroyed` flag
checked by `QDELETED`. Fixture disposal assertions must reflect that actual
queue and must not claim that production garbage collection has drained it.

<!-- 2026-10-11: component work tools -->
`scripts/check-component-tools.py` compiles production head/handle assembly and
material stats with isolated startup, then checks rejection, bounded properties,
wear/provenance and current-format native entry save/load. Use BYOND 516.1681.
The legacy `QDELETED` macro reads `gc_destroyed`, while legacy qdel uses
`gcDestroyed`/null locations; ingredient accessibility must also be validated.

<!-- 2026-10-11: chemistry verification -->
Chemical recipe IDs do not register reagents: each product needs a matching
`/datum/reagent` ID or mixing can consume inputs without producing the result.
`tests/chemistry/run.py` compiles production sources with normal world startup
disabled and runs bounded reactions in temporary storage. CI also runs its
wrong-feedstock negative control; this does not replace gameplay verification.
Linux DreamDaemon safe mode rejects an absolute `-log` path. Use a relative
log filename with the runtime working directory set to temporary storage.

<!-- 2026-10-11: chemistry recipe acceptance -->
`tests/chemistry/run.py --probe biochemistry` checks production acquisition,
construction, controlled reactions, heated polymers, gelatin separation and
engine fuel in temporary storage. See docs/chemistry-recipes.md for game yields,
finite supplies and labels. Its isolated error handler and explicit completion
flags are necessary: normal game error infrastructure is unavailable when
global/controller startup is disabled. Parenthesize each `in` expression when
combining membership checks with `&&` in DM.
<!-- 2026-10-11: gasoline precursor regression -->
`tests/chemistry/run.py --probe fuel` verifies precursor registration and real
beaker gasoline mixing; its negative control removes octane registration in a
generated copy. Fuel ratios and engine behavior are separate contracts.

<!-- 2026-10-11: Civ13 MCP integration -->
`tools/mcp/README.md` documents the bounded stdio server and Codex configuration.
Run `npm ci --prefix tools/mcp` then `npm test --prefix tools/mcp` for isolated
protocol/path/cancellation tests. Set `CIV13_DM_COMPILER` to a trusted absolute
DreamMaker path to additionally check its banner and a fixed temporary fixture.
Source discovery is lexical; include diagnostics do not replace compilation.
Both compiler tools create temporary storage/processes. No live game, Topic or
production administration tools are exposed. Never configure this server from a
worktree that will be archived while the MCP entry still points to it.


<!-- 2026-10-11: wire power verification -->
`tests/power/README.md` documents isolated cable accounting regressions and an
opt-in full-game capture adapter. `scripts/test-power.ps1` requires an explicit
BYOND bin path; CI also compiles the excluded gameplay adapter. Powerflow and
currentflow are instantaneous capacity and reserved demand, not stored energy.

<!-- 2026-10-11: GitHub comment review -->
Tools under tools/comment-review provide an authenticated-gh local collector and a disabled-by-default Codex event workflow. Preserve ignored data/comment-review cursors/receipts across worktree cleanup; inspect current API data before acknowledging or posting. The local collector does not install a scheduler or consume API credentials. See tools/comment-review/README.md for event trust boundaries and activation settings.
<!-- 2026-10-11: dormant trigger approval boundary -->
Dormant comment-review listeners must be workflow_dispatch-only: GitHub can request approval before evaluating job guards. Keep automatic subscriptions in tools/comment-review/active-events.example.json until a separately reviewed activation.

## Train verification

<!-- 2026-10-11: firearm configuration verification -->
Gun configuration is centralized in `code/modules/1713/gunsmithing/gun_configuration.dm`.
Keep runtime action owners and work reservations out of native item saves; saved
optics can be nested inside one rail adapter. `tests/gun_configuration/run.ps1`
checks production handling, interruptions, maintenance, crafting gates and nested
save migration; `-NegativeControl` must catch omitted completion ownership checks.

<!-- 2026-10-11: bounded winter survival -->
`tests/weather/run.py` runs inherited production thermal procs and real human
constructors in isolated storage, with a pinned baseline and cold-loss negative
control. Its accelerated iterations are nominal one-second Life calls, not
elapsed gameplay. `cold_wetness` is a durable bounded 0-1 scalar, without timers
or retained references. Ordinary uniforms have a 240 K cold rating; overlapping
layers help but insulation caps at 90%, and hypothermia still harms covered mobs.

<!-- 2026-10-11: automobile construction -->
`tests/car_workshop/run.ps1 -ByondBin <516.1681-bin>` exercises paid AOTD
assembly, interruptions, cable reservations, driving, turning and temporary
world-save round trips with production sources and isolated startup/actor waits.
Nested vehicle controllers have no direct turf coordinates; use `get_turf()`
when comparing their positions. Workshop power connects by dragging a laid cable
onto the workshop; cable coils feed its material stock.

<!-- 2026-10-11: medicine regression isolation -->
`tests/survival/run.py` checks production disease courses, oral metabolism,
ingredient acquisition and timed fermentation/distillation in temporary storage.
Its fixture materializes the global-controller `vars` name list before union:
BYOND 516.1681 otherwise logs Bad ref during initialization on the historical
baseline too. Runtime errors/engine diagnostics invalidate evidence. Direct
`del()` of live test atoms triggers the production GC error; use `qdel()`.

<!-- 2026-10-11: trace resource extraction -->
`tests/resource_extraction/run.ps1` compiles production extraction types with
normal startup disabled and temporary storage. It checks bounded output, drill
power/callback lifecycle, construction costs, gathering guards and shortened
production action waits and serialized drill entries. It does not establish
graphical menus or full-world save round trips. Custom saves require explicit
exclusion of transient extraction locks. The fixture closes its port at startup and rejects reopening;
`-close` alone does not prevent a Windows DreamDaemon listening port.

<!-- 2026-10-11: train collision investigation -->
`code/modules/1713/trains.dm` connections point from leader to follower. Reject
coupling cycles and stop failed movement before recursively moving followers;
`Bumped` is deferred by the movable atom's bump callback. Run bounded isolated
regressions with `tests/train_collision/run.ps1 -ByondBin <516.1681-bin>` and real
game callback/locomotive-loop tests with `tests/train_collision/run-game.ps1`.
The full-game probe uses temporary state and outbound-hook controls. Its optional
visual mode needs separate capture authorization; it never proves production
crash behavior. Do not replace required gameplay captures with fixture output.

<!-- 2026-10-11: conveyor verification -->
`tests/conveyor/run.ps1` compares production tick snapshots with isolated storage;
retained entries are distinct from OS private memory. `run-game.ps1 -ExerciseCapture`
checks real forward/reverse/stop behavior. Its optional bounded `-Visual` mode
requires the coordinator's exclusive screen turn; see tests/conveyor/README.md.
<!-- 2026-10-11: shipped Discord changelog -->
The standalone publisher in tools/changelog requires reviewed manifests and live
confirmation or a trusted successful production deployment event. A merge/CI pass
is not shipment. Preserve the discord-changelog-receipts branch; pending receipts
block uncertain replay. See tools/changelog/README.md before activation.

<!-- 2026-10-11: hosted API reference -->
Source docs publish from master via api-pages.yml to https://civ13.github.io/Civ13/.
The generator validates emitted links and search anchors; search covers documented output only.

<!-- 2026-10-11: documentation-only CI selection -->
The always-running ci-selection.yml selects compilation conservatively and skips it for documentation-only changes. Extensive runtime suites require CI workflow_dispatch with extensive_regressions enabled; train tests are workflow_dispatch-only. Skips do not prove gameplay; see docs/ci-selection.md.

<!-- 2026-10-11: plant lifecycle -->
Dead/static crops stop growth at entry and pending-wait wake; water death keeps its specific description, and age expiration marks the crop dead before stopping. `tests/plant_lifecycle/run.ps1 -ByondBin <516.1681-bin>` executes production growth/water/soil procs with accelerated waits; baseline callback counts are not whole-game performance evidence.

<!-- 2026-10-11: bounded abandoned debris -->
`code/processes/abandoned_items.dm` owns the opt-in waste registry and 256-candidate
sweep every 30 seconds. Warning/removal use 12/24 elapsed server hours, independent
of seasons. Do not opt useful item parents into decay without gameplay review.
Custom persistence serializes tmp vars: override `persistence_runtime_var` for
runtime fields and preserve both export/import exclusions. Native storage and
inventory transitions reset exposure; Destroy/Del release registry slots.
`tests/abandoned_items/run.py` compiles production sources with normal startup
and maps disabled, checks nested native save restoration and repeated disposal,
and samples RSS separately from retained object counts. It does not prove OOM fixes.
<!-- 2026-10-11: crop diagnostics -->
Plant examine delegates to read-only farming_diagnostics(skill). Preserve skill thresholds and sampled nutrition semantics; diagnostics do not sample soil or run growth. tests/plant_diagnostics/run.ps1 extracts the production helper in temporary storage.

<!-- 2026-10-11: outdoor crop bootstrap -->
Nomads Europe foraged seeds use biome filtering like its climate-restricted growth. Rain caps crop storage at max_water; natural irrigation sources remain unlimited. tests/outdoor_crops/run.ps1 tests production seed catalogs/dispatch and fresh/salt/range behavior; it does not establish map-level bootstrap reachability.

<!-- 2026-10-11: compiled sprite audit -->
- `tests/sprites/run.py --byond-bin <516.1681-bin> --output <temporary-json>` inventories compiled inherited item/structure/machinery defaults without constructing them or starting game systems. Its required-types manifest checks real DMI directions, frames and nonempty pixels; `--negative-control` restores a wrong optic icon resource in a generated source copy.
- Missing initial states do not prove missing graphics: constructors, overlays, material recoloring and map overrides can supply them. Add new obtainable types to `tests/sprites/required-types.json` when static defaults are appropriate, or document and test their dynamic rendering. See `docs/sprite-audit.md` and its unresolved-candidate inventory.
<!-- 2026-10-11: timed decal lifecycle -->
Cleanable expiry uses code/processes/decal_decay.dm (256 candidates/second), not per-decal sleeping timers or direct Destroy. Preserve existing decay_timer lifetimes; decay_deadline/index are explicitly excluded from native save export/import. tests/decal_decay/run.py compares actual native lifecycle with --baseline historical cleanable source, without normal game startup. Baseline early-qdel retention and missing expiry GC bookkeeping are isolated evidence, not full-game OOM proof.

<!-- 2026-10-11: abandoned debris season clocks -->
Abandoned rubbish/spent casings use 2/4 actual season changes on cycling maps,
or 6/12 running-server hours on static maps. Season routines record scalar
transitions; startup climate assignments do not. Fixed wet-season labels use
the hourly fallback. Keep new seasonal maps and transition hooks in sync with
`tests/abandoned_items/run.py`; custom cycles may ignore `config.seasons_on`.

<!-- 2026-10-11: food fertility save regression -->
- Turfs use a persistence allowlist rather than all changed vars. Dirt adds `soil_nutrition` through its parent-calling `get_saved_vars()` override; do not serialize its live soil recovery token.
- `tests/food_progression/run.py --soil-negative-control` proves omission is detected. The full-game world-save probe checks crop/soil and nested seed stock; its frozen crop does not establish post-load growth or season transitions.

<!-- 2026-10-11: trench save progress -->
- Trench types reconstruct depth/flooring and neighbor edges, but construction
  progress requires explicit turf save fields: trench_filling and dirt/sand
  trench_stage. Do not persist cooldowns, overlays or recovery registries.
- tests/trench_save/run.py runs production whole-world disk round trips with
  isolated startup and independent filling/digging omission controls.

<!-- 2026-10-11: bounded environment sweeps -->
- `tests/environment_sweeps/run.py` runs production daylight/weather sweep bodies and lighting color calculations with isolated startup, pinned baseline comparisons and yield/reentry controls. See `docs/environment-sweeps.md`; it does not prove client rendering or production latency. BYOND spawn copies local scalar variables: fixture completion flags shared across spawned callbacks must use a shared list/datum.
