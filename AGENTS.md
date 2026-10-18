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

<!-- 2026-10-17: lobby dispatch diagnosis -->
The private own-Host snapshot reports bounded current-lobby Join entry/phase
codes. Compiled verb visibility and a successful client menu action do not prove
server dispatch; require the entry counter or a real human spawn. The cache is
excluded from custom saves and disappears when the lobby mob is replaced.

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

### Process scheduler integration

- Codebase uses legacy `/process/` system, not subsystems.
- Create a `/process/subtype` in `code/processes/`, set `name`, `schedule_interval`, `fires_at_gamestates`.
- Register the process var in `code/processes/__processes.dm`.
- `fire()` is called each tick; do your per-tick work there.
- Global singletons should be accessed via `global.xxx` or a `var/xxx` on a global datum.

<!-- 2026-10-12: copied processing-list removal -->
Native BYOND `-=` and `Remove(value)` remove the last matching occurrence,
including repeated nulls; a guarded front `Cut(1,2)` is not equivalent.
`tests/processing_list_removal/run.py` checks production object-loop order,
budget resumes, deletion/mutations and existing recursive-fire behavior, with
immutable baseline and unsafe-cut controls. Its opt-in benchmark records complete
visit counts; no faster equivalent removal was adopted. Start budget fixtures
after a normal tick and anchor `run_time_tick_usage` to `world.tick_usage`.

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

<!-- 2026-10-13: native catch variable scope -->
BYOND 516.1681 treats catch variable declarations as proc-scoped. Use distinct
names for separate catch blocks in one proc or compilation fails with duplicate definition.

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

<!-- 2026-10-15: durable invulnerable areas -->
Placed admin/sewer areas use native `INFINITY` for `artillery_integrity`.
Durable JSON uses the exact `positive_infinity` sentinel only for that field;
ordinary numbers remain finite and bounded. Preserve finite legacy values and
reject malformed/wrong-field sentinels before world mutation. Contract probes
and the full metadata fixture audit inherited area defaults and placed areas.

<!-- 2026-10-11: world-save verification -->
- Persistence regressions are in `tests/world_save`; the focused fixture uses
  the actual saver/loader with isolated adapters, and `run-game.ps1` exercises
  real constructors in temporary storage. New saves use version-2 typed values
  and sharded entries; retain legacy flat-entry reading. Never restore `loc`,
  `pixloc`, or client session fields as ordinary variables. Linux DreamDaemon
  `-safe` requires a relative log path inside the isolated working directory.

<!-- 2026-10-14: optional save fields and player reclaim -->
- Reading an absent native savefile field can create a null directory entry.
  Check `F.dir` membership before reading optional legacy fields; otherwise
  typed-value validation can reject a valid generation. The reclaim suite's
  `legacy` control checks this mutation before broader world preflight.
- `lastKnownCkey` is login history, not unique body ownership. Reclaim uses the
  explicit canonical owner, complete-load readiness and ordinary admission
  guards. Legacy migration requires a reviewed generation-bound unique body
  mapping and a fresh derived save; preserve all original generations.

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

<!-- 2026-10-15: Modern processor recipe validation -->
The recipe catalog fixture defaults to era 0. New era-gated machine families
must select their real supported era in tests/crafting/checks.dm; the reactor
fuel processor is Modern despite not inheriting civ_generator. Keep separate
locked-era/node tests so a fixture-era fix cannot bypass production gating.

<!-- 2026-10-11: staged component workbench -->
`scripts/check-component-tools.py` now checks staged bench cancellation,
concurrent assembly, ingredient removal, destruction and nested native saves.
Its consumption/runtime-save negative controls mutate generated source only.
Workbench waits retain their busy lock until returning; runtime actor/wait state
must never be serialized. Bench contents are actual paid items, not stock counters.

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
<!-- 2026-10-13: unsupported OpenDream shell work -->
OpenDream TTS returns before scheduling shell-backed audio jobs; native TTS
remains available. Python control uses mutually exclusive engine branches.
tests/opendream_shell runs both production branches with counted external-effect
adapters and omission controls, without launching OpenDream or real scripts.

## Local MCP tooling

<!-- 2026-10-17: bounded own-host agent diagnostics -->
`docs/agent-debug-tools.md` documents schema-1 recovery/vision/3x3 tile reads on
the existing loopback/token/R_HOST lifecycle transport. Pair/trace/bundle are
offline and allowlist public summaries; raw query files remain private. Trace
is bounded cached observations, not an engine event log or rendering evidence.
The DM collector/status extension requires a rebuilt world restart.

<!-- 2026-10-15: native graceful shutdown boundary -->
Native BYOND `del(world)` can return before process exit. Yield before declaring
shutdown failure, or transaction cleanup can erase the published recovery intent.
The lifecycle disk fixture checks the intent after exit; its `shutdown-return`
negative control reproduces the old immediate cleanup.

<!-- 2026-10-15: archived combat histories -->
Combat history writers use `append_attack_log`; ghosts share the body's list.
Keep the mob history declared as `var/list` for native list method resolution.
Retire rows in place only after the private archive write succeeds. Archive
failure deliberately retains history, with scalar retry/warning cooldowns.
`tests/attack_history` checks writer coverage and isolated production contracts;
its row counts do not establish live process RAM or crash durability.

<!-- 2026-10-15: hover name HUD -->
`code/_onclick/hud/hover_name.dm` uses a weak target reference on a disposable
human HUD screen object. Mouse events update it; the existing HUD process
revalidates stationary targets. Keep masked names behind `get_visible_name()`,
require a screen slot for inventory visibility, and forward runtime persistence
exclusions. `tests/hover_name/run.py` exercises native production decisions with
an injected client boundary, not real client mouse delivery or rendering.
<!-- 2026-10-15: lighting persistence ownership -->
Custom saves enumerate tmp lighting fields too. Exclude light/light_sources and
derived light_source/lighting_corner/lighting_overlay graphs on export and import;
their constructors require live owners/turfs. Rebuild sources after durable atom
fields and after_load. tests/world_save/run-durable-world.py --lighting checks
actual constructors and legacy graph recovery; full-map acceptance is separate.

<!-- 2026-10-15: isolated recovery observer setup -->
When normal global startup is disabled, fixtures that remove real mobs must
initialize `GLOB.all_observable_events = list()` before constructing the moved,
direction, name and stat observer events. Otherwise event construction can turn
the null registry into one datum, and the second event raises a type mismatch.
Missing direction observers also make real contained-item removal fail.

<!-- 2026-10-14: local CID source comparison -->
`tools/cid/get-cid.ps1` calls the reviewed Windows BYOND 516.1681 library's
fingerprint/CRC routines in 32-bit PowerShell. Private offsets require its exact
documented library hash. `run-local.ps1` compares with a real local client's
`computer_id`; its negative control tests equality only, with no spoof detection.
<!-- 2026-10-14: bounded runtime detail history -->
Error history keeps 1000 recent entries globally and 100 per file/line source,
including skip summaries. Retirement removes both memberships and clears entry
backreferences, captured usr locations and detail text before explicit plain-datum
deletion invalidates old holders. Source metadata and
world/Error cooldown dictionaries remain for the round; distinct synthetic
file/line identities are not bounded. `tests/error_history/run.py` checks real
logging, viewer bodies and retirement in an isolated native world, with an
immutable historical log_error control. `--prepare-only` runs no native tools.

<!-- 2026-10-14: native launcher packaging -->
`tools/opendream-client/native/Build.ps1` builds the single-file self-contained
Windows x64 launcher. Its offline console tests cover mock updates plus actual
EXE replacement after parent exit and BYOND prerequisite adapters, without accounts
or a game. Release publication builds the exact tag and verifies immutable asset
readback before advancing the separate native feed; prereleases do not activate it.
Preserve the existing client channel and distinguish package integrity/BYOND setup
from identity/gameplay acceptance. Never silently accept installer licenses.

<!-- 2026-10-13: dehydrator native save baseline -->
`tests/food_progression/rack_save.dm` exports the owning turf and rack graph.
The 769ae4911 baseline compiled cleanly but failed exporting runtime `slots`.
Load_Entry replaces constructor contents even for an empty saved record; rack
runtime pointers must be excluded and live internal storage rebound or rebuilt.
Source-only preparation does not establish native candidate or control acceptance.

<!-- 2026-10-12: NPC cover decision parity -->
`tests/npc_cover/run.py` compiles production cover scoring, LOS and line helpers
with native BYOND ranges in an isolated 32x32x2 world. It compares every score
and choice, including officer/clump boundaries and tie controls. Cover allies
are cached only within one synchronous decision after its second cover candidate;
keep candidate order and strict score comparison. The benchmark reports native
wall time, not server CPU or combat movement acceptance.

<!-- 2026-10-12: inherited runtime exclusion precedence -->
DM `in` binds below `||`; parenthesize membership before combining a runtime-field
list with `..()`. Otherwise a nonempty list short-circuits the parent exclusion.
The human corpse fixture checks inherited human/equipment exclusions and its
`--negative-control runtime-parent` restores the faulty human expression.

<!-- 2026-10-12: lighting batch ownership -->
Lighting overlays detach bounded 1000/2000-entry batches, null consumed slots
and retain unfinished batches across budget
returns. Scheduler replacement must transfer current_list/batch_index;
cancellation returns unfinished entries to the live queue. Tests in
tests/lighting_queues compare production color/luminosity and immutable baseline
queue workloads; trivial callback timings do not establish server latency.

<!-- 2026-10-12: native GC outcome triage -->
BYOND 516.1681 can clear a native `del(A)` argument when `Del()` aborts while
the target remains alive. Verify disappearance with the saved ref and retirement
identity, not a null local. `tests/gc_triage/run.py` checks production outcomes
and bounded opt-in owner-field inspection; outcome rows share deletion profiling's
128 named types plus overflow. `gc_forced_types` telemetry counts these bounded
forced-call buckets, not exact distinct types after saturation.

<!-- 2026-10-12: opt-in regression CI -->
Existing game and tooling regression suites are manual opt-in. PRs adding
executable integration tests select their registered suite only for that PR;
ordinary game edits and edits to existing tests do not auto-select regressions.
Keep compilation, workflow validation and publication checks separate. Register
new suite guards through ci-selection.yml; see docs/ci-selection.md.

<!-- 2026-10-12: official DM reference -->
`dm_reference_search` and `dm_reference_read` fetch only the official BYOND manual
over HTTPS, with bounded downloads, cancellation and a temporary in-memory cache.
Returned source hashes identify reference content, not compiler compatibility;
the live manual can describe features newer than pinned BYOND 516.1681.

<!-- 2026-10-11: automatic crafting atlas -->
`scripts/build-crafting-atlas.py --catalog-only --game-catalog UI/crafting-atlas.json`
refreshes the shared Notes-style game reference before direct local compilation.
Production build scripts do this automatically. The existing api-pages workflow
also emits `crafting/` with isolated BYOND 516.1681 inherited sprite exports.
Missing/transparent defaults use a labeled actual paper DMI source symbol;
constructor graphics and material recoloring remain dynamic. See
docs/crafting-atlas.md; acquisition annotations retain their historical audit SHA.

<!-- 2026-10-15: atlas unlock and processing contracts -->
`scripts/atlas/catalog_metadata.py` keeps unlock research tiers/minimum gates
separate from catalog field 12's maximum allowed era. Parse research constructors
with balanced arguments; the enclosing registration call adds another closing
parenthesis. Processor tiers describe station construction, not use restrictions.
`tests/crafting_atlas/run.py --compile-only` never starts DreamDaemon; runtime
navigation and omission controls require the normal isolated runner or CI.

<!-- 2026-10-11: bounded animal harvesting -->
- `code/modules/1713/animal_harvest.dm` centralizes corpse claims and bounded species products. The custom saver enumerates `tmp` fields, so in-progress harvesting/axe locks explicitly opt out via `persistence_runtime_var`.
- `tests/animal_harvest/run.py --byond-bin <516.1681-bin>` executes production yields, cancellation/concurrency, binding conservation and object save/load in temporary offline storage. `preview.py` renders existing DMI states for PR sprite review; it is not a gameplay capture or full-server memory test.

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
<!-- 2026-10-15: player-facing changelog review -->
Meaningful player-facing PRs must include exactly one reviewed `changelog: text`
line in their opening description before being marked ready or merged, outside
comments, quotes and fenced code. Use concise player-facing text compatible with
tools/changelog/README.md so the existing GitHub Action can announce it to Discord.
Use one announcement route per change; do not also add a manifest for that change.
This requirement does not authorize manual posts, publisher settings changes,
deployment or claims that the change is running on a server.

<!-- 2026-10-11: shipped Discord changelog -->
The standalone publisher in tools/changelog supports an explicit `Changelog: text`
line in a PR opening description on merge into master. Missing or blank means no
post. Use player-facing bullets only, without headings or deployment/update-status
wording. The older manifest route still requires live confirmation or a trusted
successful production deployment event. A merge/CI pass is not shipment.
Preserve the discord-changelog-receipts branch; pending receipts
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
<!-- 2026-10-13: queued season source verification -->
The abandoned-item source scanner checks both direct `seasons()` overrides and
the base queued `season_apply()` worker. Run `tests/abandoned_items/run.py
--check-season-wiring` for a source-only check; missing-hook controls are in
`tests/abandoned_items/test_season_wiring.py`. This does not launch BYOND.

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

<!-- 2026-10-11: human corpse decay -->
- `code/processes/human_corpse_decay.dm` owns bounded human/bones exposure. Only retirement-created remains expire; use idempotent `do_rotting()` instead of another corpse timer. Native drops retain actual nested gear; blocked roots abort retirement.
- Persistence restores saved DEAD humans without rejuvenation or death-hook replay. Durable exposure survives reload; runtime record pointers/epochs do not. Native mob qdel deletes immediately, so observe pre-retirement state through the inert `corpse_retired(body, turf)` hook.
- `tests/human_corpse_decay/run.py` runs production human/inventory/revival/save/GC paths in temporary storage with pinned516.1681 and nodrop/restart/no-op negative controls. Use a fresh savefile for each independent graph; reusing entry directories can mix stale fields.

<!-- 2026-10-11: memory ownership contract -->
GC synchronizes gcDestroyed/gc_destroyed after cleanup and guards recursive qdel
with the modern in-progress marker. Callproc retires helpers before invocation;
its target index must release empty buckets. Pools opt in reviewed families,
cap each type at 100 and total ownership at 1,000, and evict at most 32 idle
objects per GC run. Reuse must remove pool_idle ownership before resetting.
Tests under tests/memory_ownership and the focused *_ownership suites execute
production procedures with immutable pre-fix/mutation controls. The queue cursor
experiment was rejected for stale-entry growth; do not change GC budgets based
on synthetic throughput alone.

<!-- 2026-10-12: pooled activation and snapshot ownership -->
Effect and effect-system lifetime tokens distinguish sleeping work across reuse;
they are runtime-only persistence exclusions and are cleared during Destroy.
Source-bound spark tasks cancel on retirement. Scheduler task processing must
check whether pre_process/process retired the task before its next phase.
Completed process snapshots are released; budget-yielded snapshots are retained,
and a fresh snapshot is populated only when a new pass starts. NanoUI child close
must detach from its master, and master close iterates a copy of children.
tests/pool_effects constructs actual effects with isolated startup and observer
count lists initialized; missing those lists creates misleading fixture errors.
<!-- 2026-10-12: global controller virtual-list ownership -->
Materialize `exclude_these.vars` names into an ordinary list before appending global-controller exclusions. Native BYOND 516.1681 can log `Bad ref` during direct virtual-list union even when assertions pass. `tests/global_vars_ownership/run.py` checks production initialization and a historical diagnostic control; the full-game train launcher rejects engine diagnostics and closes/refuses headless ports. Survival/weather/environment fixtures use fixed production initialization unchanged and adapt only the historical union.

<!-- 2026-10-12: bounded memory telemetry -->
Opt-in memory_lifetime_recorder retains at most 120 numeric awake intervals and
120 scalar registry/counter rows, with no sampled entity references or world scan.
Observed interval p95/max includes scheduling and clock resolution, not tick CPU
time. GC queued_drained counts consumed queue entries, excluding direct deletes.
Headless humans enter SSD sleep: synchronous inventory fixtures must prepare and
assert an awake, live actor before real pickup/drop calls.

<!-- 2026-10-12: collector mixed workloads -->
GC may drain already-collected expired records after its forced-delete quota is
used; the next matching live target waits. Preserve 300 candidate checks, 30
forced deletes, 30-second expiry and ref timestamp guards. Run the collector
case and gc-soft-budget/gc-hard-budget controls in tests/memory_ownership/run.py.

<!-- 2026-10-12: scheduler chain and denial history -->
Scheduler start replaces its identity token; stale sleeping invocations retire at
wake, and stop invalidates the token. Process may_run uses one lazy history
expiry deadline; started cancels it before recording new run history. Native
lifecycle, immutable baseline and controls live in tests/process_loop_lifecycle.

<!-- 2026-10-12: comparative GC and loop benchmarks -->
`tests/gc_benchmark`, `tests/scheduler_benchmark`, and
`tests/game_loop_benchmark` compare production sources with immutable pre-PR3091
bodies using BYOND 516.1681 and temporary storage. Run performance comparisons
sequentially to avoid competing test workloads. `PROCESS_TICK_CHECK` returns the
early-return sentinel; it does not sleep. Isolated queue counts and Windows
private bytes are separate metrics, and process CPU accounting can have 15.625ms
quantization. Full-game movement/Life/inventory probes do not establish client
rendering, multiplayer latency or long-term OOM stability.

<!-- 2026-10-12: exhausted budget snapshots -->
A tick-budget return can happen after PROCESS_LIST_CHECK removes the last entry.
Normalize exhausted EARLY results through finished and both process entry points
so relayProcess removes completed work. Release exhausted snapshots so the next
scheduled run builds
fresh work; retain only nonempty unfinished snapshots. Assign null without cutting
aliased VERY_HIGH live lists. tests/process_loop_lifecycle covers the exact
last-entry boundary and an independent old-guard mutation control.

<!-- 2026-10-12: era-dependent research prototypes -->
Established factions retain their founding research baseline when another faction
advances the world era. Prototype recipes must remain obtainable afterward:
Digital Computing needs the cold-war camera subtype, not its modern camera parent.
The compiled crafting fixture checks two-faction era advancement and the paid
recipe; --camera-prototype-negative-control restores its obsolete era cap in
isolated runtime data and must detect exactly the lost recipe.

<!-- 2026-10-12: finite digging completion -->
Loose snow/dirt/sand stock must be checked after the action wait, because another actor may consume the last unit. Underground pickaxe actions use one wait/completion path. `tests/resource_extraction/digging_probe.dm` runs production handlers with competing completion and cancellation adapters; `-DiggingBaseline` rejects immutable pre-fix source without changing the checkout.

<!-- 2026-10-12: wall material appearance parity -->
set_material relies on update_material's final neighbor refresh. Do not remove
that inner refresh: it establishes existing open/damaged-wall overlay ordering.
tests/wall_appearance runs actual wall constructors and ordered appearance/count
comparisons, production save/load and smoothing/duplicate/overlay controls.
Measured native callback reductions are not whole-server latency evidence.
<!-- 2026-10-12: seasonal terrain snapshots -->
get_area_turfs accepts an optional third turf_type argument. Seasonal callers
use fresh filtered snapshots, preserving pass order and native replacement refs;
never cache them across transitions. Filtered predicates must be pure because
excluded types skip predicate calls. tests/season_terrain_filter compares ordered
native selections and bounded allocations at 660x550 synthetic geometry; inert
entities and isolated wall times are not full-game or connected-player evidence.

<!-- 2026-10-12: serialized seasonal terrain -->
Base seasons serialize discovery, terrain mutation and delayed phases with
season_busy/season_epoch; pending natural requests remain distinct. Delayed
callbacks retain scalar phase/epoch values and stop when metadata is replaced.
Discovery yields at 4096 candidates, mutation at 256, and both at 20% tick usage.
Batch checkpoints use sleep(0) while budget remains; exhausted budget waits for
the next tick. Cheap discovery checks budget/ownership every 64 entries, while
each mutation checks individually. One constructor or discovery block can
overshoot before the next checkpoint.
Season worker fields are explicitly excluded by persistence_runtime_var because
custom saves enumerate tmp fields. Asia flooding uses season_transition_complete
inside the same lock. Isolated tests do not establish full-server latency.

<!-- 2026-10-12: finite native probe completion -->
Native del(world) does not immediately stop the current procedure. Accumulate
probe failures before emitting one final result, and return explicitly after
world disposal so failure paths cannot continue into a passing receipt.

<!-- 2026-10-12: OpenDream local controls -->
`scripts/opendream/control.py` owns only its launched local server. OpenDream
restart/map votes enqueue fixed requests with a ready marker; do not use shell
or native PID discovery. Reused temporary resources can make OpenDream `fcopy`
copy stale bytes. Write the final spool file before its marker and verify actual
disk bytes independently of DM resource reads. `verify-dm-controls.py` exercises
production request/reboot/whitelist bodies in a disposable OpenDream world.

<!-- 2026-10-12: bounded lighting startup -->
Initial turf New delegates overlay construction to bounded startup sweeps.
Dynamic excluded-z/void sites still need the compatibility overlay pass.
Shared corners activate after both overlay passes; runtime build/clear/activity
requests wait through startup and return after a failed barrier. Preserve
ordinary prestartup direct calls. tests/lighting_startup checks production
bodies, shared identity, late replacement and failed waiters against a baseline;
its adapted rendering does not establish client lighting acceptance.

<!-- 2026-10-12: lighting reinitialization -->
Lighting startup must reconcile existing inactive shared corners after adding overlays, as well as activating fresh corners. Native largest-startup fixtures exercise a later overlay pass after standalone corner creation; use bounded overlay-master visits without retaining a corner registry.

<!-- 2026-10-12: native population readiness -->
Mob processing retains unfinished copied population snapshots across budget returns. A fixed schedule interval does not guarantee newly constructed humans received Life. The full seasonal constructor fixture waits at most 30 real seconds for natural first service while checking actor identity/location/death; its service control excludes one retained actor from both live membership and the pending snapshot. Never invoke Life directly to satisfy scheduler evidence.

<!-- 2026-10-12: animal health and combat dispatch -->
Simple-animal starting health and maxHealth must match unless an explicit policy
is documented: Life clamps health and updatehealth recomputes it from maxHealth.
Do not call parent attackby after an explicit item attack; that repeats damage,
logs and material wear. tests/animal_combat/run.py checks compiled inherited
health defaults, native Life, single sharp/blunt attacks and wear across behavior
branches, noncombat dispatch, healing/death and generated negative controls.

<!-- 2026-10-14: chemical smoke source retirement -->
Chemical smoke systems are single-use: their two reaction callers construct fresh
systems. The hidden reagent source must survive every queued spawn callback, then
retire through atom/reagent cleanup. `tests/chemical_smoke_ownership/run.py` checks
production copies, lifetime bounds and repeated holder/membership cleanup against
an immutable historical negative control in temporary offline storage.

<!-- 2026-10-15: native associative collections -->
`code/_macros.dm` redefines `islist(A)` as `istype(A, /list)`, excluding `/alist`
although native BYOND `islist` accepts it. Squad and leader defaults are alists
with numeric keys and null associations. Collection codecs must handle `/alist`
explicitly; isolated probes must import the production macro. Numeric alist
indexing addresses keys, so iterate keys instead of positional indexes.

<!-- 2026-10-15: paid wood residue and plant nitrary -->
Wood-fuel residue uses a saved scalar ledger shared by existing ovens, furnaces
and factories; unknown legacy fuel earns no ash. The existing compost bin's
optional nitrary mode stores paid feedstock and remaining active-server time,
excluding its runtime clock. Feedstock uses stack.use without a human argument:
Production religion otherwise discounts consumption and breaks conservation.
See docs/wood-ash-compost.md and tests/wood_ash_compost/run.py for isolated
production-path/native-save checks and generated-source mutation controls.

<!-- 2026-10-15: save and continuous-round guard ordering -->
Ticker save-in-progress gating precedes continuous persistence-round recovery.
Do not clear a saved finished flag or change round state while serialization is
yielding. tests/persistence_round/run.py --negative-control save removes that
guard and must fail the production ticker/save interaction assertion.
<!-- 2026-10-15: persistence runtime view helper -->
ClearMap must preserve the global dview_mob identity. Retiring this runtime mob
breaks FOR_DVIEW in post-import lighting processing after GC clears the global.
The lighting recovery fixture runs production lighting_sources.fire(), not only
light constructor/registration checks; lighting-view removes the preservation guard.
