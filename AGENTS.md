# Civ13 - Agent guide

<!-- 2026-10-28: explicit furniture joinery alternatives -->
Namespaced joinery recipes share furniture_joinery.json with Atlas/Help. Preserve
all existing recipes. Peg stock is paid only after retained equipment, secondary
stock, output occupancy, research and persistence epoch pass post-wait checks;
do not reselect a replacement tool or search nested storage. Use the primitive
woodworking shaping predicate for dowels. Its material knives wear 0.25 only on
success; assembly tools are reused. New routes are global only. See the dated
furniture audit and checked-in original-row fixtures. --compile-only explicitly
does not run crafting assertions; native/client and reachability remain separate.
Tools may be equipped or loose at the actor's feet through a bounded scan.
Preset stack subtypes retain actual-material checks. Award joinery XP only after
successful debits; preserve legacy recipe XP ordering.

<!-- 2026-10-28: gathered manual woodworking -->
Manual woodworking in primitive_woodworking.dm keeps pieces and crude planks
distinct from finished planks. Whittling admits sharpened flint or an actual knife
whose working material is harder than the wood; flattening admits sharpened flint
or sharp verified non-wood working material and charges no tool wear. Wooden
handles on metal blades do not make those blades wooden. Hammer/wedge splitting
is axe-free; the existing plank-to-handle recipes remain unchanged. Ownership is
runtime-only and the admitted persistence-operation constructor invalidates waits.
The offline source projections and hosted wiring do not establish native gameplay
or savefile acceptance. Keep the sawmill owner's one-finished-plank-per-log contract
separate; no spawn kit, map cache, peg joinery or respawn resource grant is added.

<!-- 2026-10-28: public lighting/exclusion reconciliation -->
The exclusion runner requires immutable event base/head SHAs and verifies the
checked-out head, event metadata in Actions and committed fixture inputs. Never
fall back to a fixed master checkpoint, moving ref or base/head self-comparison.
Preserve the complete event-base source, adding only missing exact fullbright
exclusions and area_change_owner; already integrated lighting policy stays intact.
Keep immutable historical bounded-save tests and lighting omission/parent controls,
plus actual CLI preparation tests for evolved pre/post-lighting event bases and
one-sided regressions. Source-only checks do not authorize native work.
The selected exclusion Linux entry point is explicitly 516.1688 and verifies the
existing pinned archive/members at admission and execution boundaries. Preserve
the historical 516.1681 gate, shared resource/cleanup limits and causal controls.

<!-- 2026-10-19: disabled lighting composition V2 -->
Keep LIGHTING_COMPOSITION_V2 at 0 until new native pixel and lifecycle acceptance.
V2 separates weather from tile RGB and explicitly represents visible fullbright
coverage. Historical render receipts bind only tests/light_plane_composition/rejected;
never relabel their failed weather/fullbright counterexamples as V2 evidence.
Headless mode/coverage checks and synthetic pixel-oracle tests cannot prove rendering.

<!-- 2026-10-22: area change lighting dispatch -->
`ChangeArea` owns turf membership, existing area notifications and the final
`T.change_area` hook. A temporary per-request identity rejects stale dispatch
after yielding callbacks, reentry (including away/back), or turf replacement;
the final destination is checked too. Exclude that identity from custom saves.
Same-area calls return before ownership changes; a missing old area still
initializes lighting. Valid hooks reconcile actual overlay state to destination
policy, since the old area's lighting may never have been applied; read current
area after the build startup wait and invalidate coefficients on real changes.
`tests/light_plane_composition` extracts both real
procedures and checks helper dispatch with counted overlay adapters, separate
from native corner graphs and client rendering. Keep V2 disabled.

<!-- 2026-10-27: inactive ecology activity heatmap -->
The data-only ecology_activity_heatmap datum has no singleton, process or player
hooks. Samples/queries bind caller-captured epochs before touching clock/coverage;
missing, stale or incomplete inputs never authorize spawning. At most 256 input
rows and 4096 stored cells; caller supplies anonymous active occupancy and time.
should_save is FALSE and all runtime fields explicitly exclude custom persistence.
Source contracts are bounded offline CI only, not DM/native behavior proof.
DME inclusion permits exact-revision compile coverage; activation, warm-up and
activity/visibility adapters remain separate work. No animal mutation is added.

<!-- 2026-10-27: disabled Backrooms expedition foundation -->
`docs/backrooms-expedition` separates powered colonization from finite escape.
`gateway_core.dm` contains uninstantiated finite-charge/lifecycle/identity datums,
not a teleporter or world-save adapter. Template hashes never replace mutable
instance identity. `tests/backrooms_gateway` projects pure source guards offline
and prepares native savefile/lifecycle assertions without launching. Native runs
require the bounded plan review; compilation does not prove movement or rescue.
Use the console `dm.exe`, not the GUI `dreammaker.exe`, for Windows compilation.


<!-- 2026-10-24: persistence construction weathering -->
Seasonal construction is an exact-design opt-in in code/processes/seasonal_construction.dm,
gated by map.persistence, with 16/32/64-season fibre/earth/timber defaults. Paired
roof/floor slabs are exempt because generic wood roofs can underlie modern floors.
Save hooks accrue unpaid debt without destruction; roofs explicitly save debt,
and after_load rebases excluded runtime clocks/indexes. Terminal qdel waits for
empty contents. tests/seasonal_construction is offline; prepare.py only prepares
an uncompiled native packet. Keep native/graphical acceptance and balancing pending.


<!-- 2026-10-26: diagonal human movement candidate -->
The human adapter uses sixteen native 2px pulses per admitted input, bitmask
diagonals, and the legacy ordinal cooldown multiplier. Default activation waits
for an eligible input and calls the safe setter; an explicit aligned opt-out
clears pending initialization. Owned restored offsets may resume; arbitrary
legacy offsets are not adopted. Native glide/client FPS ownership is runtime-only
and restored on opt-out, restricted input, logout, body handoff and death.
tests/human_subtile/run-diagonal.py targets 516.1688 with exact-Git staging and
a separate executable allowlist; historical helpers remain frozen. Preserve the
Windows startup-socket rejection rather than weakening its no-socket policy.
Headless displacement/compile checks never prove DreamSeeker visual smoothness.
<!-- 2026-10-28: pulling and menus keep smooth movement -->
Pulling and open menus (any using_object except a stationary gun) keep the
adapter eligible: a restricting state mid-step refuses all input until alignment.
Headless fixtures have no client, so living/Move stops pulling there; pull-follow
during smooth steps needs connected-client confirmation.


<!-- 2026-10-25: shared hub community links -->
`code/world.dm` owns the shared Nomads/TDM hub renderer. Reuse DISCORDURL and
WEBSITEURL; keep literal metadata escaped and configured links HTTP(S)-only.
The `hub_status` CI baseline suite tests source-derived HTML offline, not native
DM execution or public hub rendering. Installing new procedures requires a
rebuilt world and separately authorized restart; source approval does not activate it.

<!-- 2026-10-24: precipitation-driven generated snow -->
Ground snow uses weather_snow units on exact ordinary dirt/grass, actual snowfall,
exposure and get_temp (stick <=0C, melt >2C). Existing winter/snow/ice stays unmarked.
No seasonal snow-ground replacement/thaw; retain water/ice/calendar/weather logic.
One bounded swap-remove worker owns sampling. Save only units, never image/index;
legacy same-type load resets units before decode. docs/snowfall-ground.md lists
gameplay predicates, exclusions and source/native acceptance limits.

<!-- 2026-10-24: authoritative zones and spawn registries -->
Durable schema 2/topology 2 captures native area IDs in per-level zone_capture
records at turf-frame admission. IDs use lineage counters, not new RNG calls.
Validate candidate files with yields; do not restore a full-world no-yield JSON
comparison. Area registration is operation-staged, retirement precedes publication,
and load/recovery readers require admission. No rollback exists after ClearMap.
Schema 1 keeps its legacy reader; tests/zone_persistence is offline/preparation
evidence only. Local IDs are not shard/custody IDs or logical geographic layers.

<!-- 2026-10-24: target BYOND version and historical fixture boundary -->
tools/byond/version.json pins target 516.1688 and observed official HTTPS archive
bytes; it is embedded directly into source launcher 1.0.8 and consumed by the
default compiler bootstrap/receipts and WSL setup. This does not establish native
compatibility or publish the launcher. Compiler minimum/savefile major remain
516.1681/516. Frozen 1681 fixture helpers, CID offsets and historical evidence stay
unchanged. Manual component/train workflows explicitly select the legacy 1681
bootstrap; other strict 1681 runtime harnesses must fail on a mismatched engine,
not be relabeled. See docs/byond-5161688.md before selecting native coverage.
Active hosted compilation explicitly selects the user-approved Civ13/Civ13
repository-release asset pinned in the Linux manifest. Only its exact public URL
may redirect once to its reviewed release-assets.githubusercontent.com path;
no credentials, signed-query receipts, source fallback or broad redirect rule.
Official/community choices retain NoRedirect. Only the versioned archive and
acquisition metadata are cached by OS/version/hash; each hit verifies every byte
before fresh extraction and actual compilation. Preserve original cache-origin
provenance, fail closed on corrupt caches, and require exact-source receipts.
BYOND cache prereleases are excluded from launcher publication by both the
workflow and release planner; this archive route does not change the stable feed.

<!-- 2026-10-24: shared season duration -->
Shared season_loop timers use validated SEASON_DURATION_MINUTES (default60) with
an optional map.season_duration_minutes override. Pending durable remainders are
unchanged; map overrides are author policy, excluded from historical imports.
Mountain and Ice Age retain initial30-minute shared timers and their explicit
recurrence. Independent calendars and literal startup delays stay separate.
tests/season_duration is source-only; native timer/reload acceptance stays pending.

<!-- 2026-10-24: per-map random weather policy -->
weather_timing/weather_transitions are optional author fields for existing random
weather. Null keeps old rolls, season pools and process timings; configured rows
intersect seasonal/map eligibility, and empty choices hold current weather.
Invalid policy stops random helpers before mutations. Direct event calls retain
their behavior. Fields are excluded from imports; no saved cursor or event callback.
tests/weather_policy is offline projection/parity evidence, not native acceptance.

<!-- 2026-10-24: configured base season flow -->
season_cycle is author policy for the serialized base worker. Whole-cycle validation
rejects Spring/Summer->Winter before mutation; default edges retain legacy payloads.
Six supported nondefault edges preserve unmarked ground and reconcile snow structures/wet-dry state
inside the existing epoch/lock, before the unchanged subtype completion hook.
No synthetic seasons, extra decay charges, new phase timers or saved cursor.
tests/season_flow projects source/queue/ecology paths; native acceptance stays held.

<!-- 2026-10-18: inactive reserved lighting -->
Reserved lighting omission requires the default-FALSE area clearance gate as well
as reserved turf markers. No map opts in. `tests/reserved_lighting/clearance.py`
checks declared frozen full-frame geometry only, not map inventory completeness
or runtime immutability. The separate Linux CI lane compares native state and
causal controls; it does not prove client appearance or net RAM savings. Preserve
frozen Windows helper bytes and require a fresh grant for that held runner.

<!-- 2026-10-20: passive production hang triage -->
`scripts/hang-watchdog` observes Linux process identity and status-file metadata
with monotonic deadlines. Its dedicated output is bounded and sanitized; it never
starts/stops/restarts a game, saves/imports, elevates, or attaches a debugger.
`tests/hang_watchdog` uses offline proc fixtures only. Keep the ordinary desktop
test installation on approved master; PR worktrees are not runtime installations.
Manual debugger/tracer examples require separate approval and confirmed detach;
an i386 syscall 0 is restart_syscall, not the host's 64-bit read syscall.
<!-- 2026-10-20: reviewed video upload boundary -->
<!-- 2026-10-20: deferred control-read capability -->
Deferred upload controls use a dedicated Variables/Environments/Metadata-read App,
installed only for Civ13/Civ13, through eight named variable GETs. Its ephemeral
token never substitutes for queue/actions GITHUB_TOKEN. Pinned create-github-app-token
v3.3.0 lacks permission-variables; omit all permission inputs only while that
installation retains exactly the three approved read permissions. Keep post-job
revocation and feature OFF until separately approved storage/activation. Create
and read back master-only youtube-controls before placing its key; a missing
workflow environment otherwise auto-creates without branch protections.
`docs/youtube-upload.md` defines the manual/default-off public YouTube uploader contract after explicit owner approval.
Only trusted default-branch code receives environment credentials; PR media stays
data, with decoder inspection in a secret-free job. Per-clip human approval binds
media/metadata/destination; durable reservations block ambiguous retries. Never
delete uncertain one-off receipts or create OAuth grants from source-PR approval.
The user-run `tools/youtube/authorize.py` checks only project
`calcium-circuit-384407`, uses manual Google PKCE consent and a separate stdin
secret-placement confirmation. Setup requires explicitly disabled repository
activation variables; uncertain secret writes require owner reconciliation even
when immediate metadata reads show absence. Tests use fake services/local loopback.
The owner selected sole required reviewer `valzargaming` (User ID `7202504`),
with self-review allowed and administrator bypass disabled. Keep explicit manual
environment approval; setup approval does not activate uploads or merge this PR. The exact PR3031 historical pilot has a pinned owner-approved material digest; original CI is never relabeled as its packager. Public uploads retain notifications off and cannot change old videos. Keep historical import parsing credential-free.

<!-- 2026-10-19: protected sleep buckle ownership -->
<!-- 2026-10-23: save movement and physical sleep guards -->
Cross-z movement admission reads persistence_active_operation.kind == "save";
load reconstruction and same-z serialization hooks must remain nonblocking.
Resolve physical turfs through containers, and allow qdel's gc_destroyed mark
to detach atoms before gcDestroyed is assigned. Raw loc/z assignment bypasses
Move/forceMove; explicit transport paths use persistence_set_loc/set_z.
tests/save_movement is offline source-flow evidence, not native acceptance or
proof that all remaining raw location writers are covered. Protected sleep's
physical predicate includes (1,1,1) and the existing admin sleep area; stale
return coordinates inside that area must keep protection and refuse waking.

Protected sleep relocates the body between z-levels, so release only its matching
reciprocal buckle before entry or wake. Keep return coordinates captured before
unbuckling, reject mismatched occupants, and leave sleep protection active on a
failed wake. Both delayed verbs retain the initiating client/body and recheck the
persistence gate at transfer time. Per-level saves still reject cross-z object
fields; never suppress that guard to hide a stale spatial relationship.
`map_storage.last_save_reference_failure` is a bounded admin VV snapshot for
cross-level and duplicate-entry failures, including direct Save_World calls.
Keep only scalar identities/coordinates and at most eight schema-field frames;
never pin live objects, retain values or print lookup refs in public reports.
Preserve it through cleanup, clear it only at accepted save admission, and verify
lookup type/location because native refs can be recycled after deletion.

<!-- 2026-10-20: bronze Help retrieval -->
Keep reviewed bronze production and availability evidence in one retrieval record;
separate ranking let iron-ingot excerpts displace bronze research gates. The route
uses copper/tin ore in fired blacksmith pots/jugs, then mold pouring and anvil work.
Ovens fire clay molds; kilns alloy the loaded ores. Preserve map and actual node
checks, and never infer a player's completed research from era metadata alone.

<!-- 2026-10-18: private Help conversation boundary -->
Help history belongs to an authenticated client session, never a saved mob.
`conversation_probe.dm` is included by the existing isolated Help fixture;
conversation generation and action-token negative controls check stale replies
and copied links. The role-free worker contract derives only user/assistant
turns, bounded by UTF-8 history and complete ASCII-JSON request bytes. Spool
cleanup is not encryption or guaranteed crash-time erasure. Server and worker
updates require separately coordinated restarts; offline checks do not prove them.
<!-- 2026-10-19: consumed crafting handles -->
Consumed wood handles are selected from hands and real equipment slots, including
shoulder/back, then retained through do_after. Revalidate the exact item and source
before debit; consume only after successful stack.use and clear its actual slot.
Do not recurse through storage or recreate handles on cancellation. Existing
get_equipped_items omits shoulder; use the slot getter with equipment priority.
<!-- 2026-10-21: digging tool and research admission -->
Trench digging uses Field Defenses, matching the trench shovel unlock; ordinary
non-harm dirt collection remains ungated. Rock mining accepts pickaxes only at
both click dispatch and shared action admission. The utensil base includes wood
knives; retain spoons for loose dirt/sand/snow collection, not rock mining.
`tests/test_digging_tools.py` checks source-derived gates offline; it does not
establish connected-client collision or native gameplay acceptance.

<!-- 2026-10-19: collision mining ownership -->
Dense mineable underground rock uses one shared click/bump mining action. Its
explicit optional do_after context owns actor and turf reservations before any
spawn; never queue mining from deferred living.Bump work or switch the player's
active hand. The custom saver must exclude both reservation pointers.

<!-- 2026-10-18: native help spool format -->
Native DM can interpolate world.realtime in scientific notation, and text2file
adds LF/CRLF to ready markers. The help bridge validates bounded opaque IDs and
removes exactly one native line ending at admission and completion. Run
tests/player_help/run-spool-controls.py for the three old-defect controls;
all model transports in these spool checks are injected and offline.

<!-- 2026-10-18: native Help line endings -->
BYOND 516.1681 rejects the DM string escape `\r`; use `ascii2text(13)` for
carriage-return normalization. `\n` is supported. JSON-decoded CRLF test data
must still exercise the actual native renderer, not only a Python equivalent.

<!-- 2026-10-18: isolated fixture ports -->
`world.OpenPort(0)` opens an available port; `OpenPort("none")` closes it.
The Help fixture disables compile-time visibility, rejects clients and overrides
OpenPort to prevent reopening. These controls do not replace external socket monitoring.

<!-- 2026-10-18: restored input clocks and action locks -->
The custom saver includes changed tmp fields. Mob next_click/next_move and
may_do_after/may_do_mob are process-local deadlines/locks: exclude them on export
and legacy import through persistence_runtime_var. Do not reset them on every
Login or click, which would bypass live cooldowns/actions. The world-save
runner's --input-runtime adapter checks disk-backed migration and the production
early click gate; connected-client interaction remains separate evidence.

<!-- 2026-10-21: direct BYOND status discovery -->
Public native menus probe only the configured Civ13.com and ValZarGaming hostnames
on ports 1714 and 1715. These are candidates, never an online assertion or a mode
mapping. No HTTPS server directory, backend deployment, port ranges or arbitrary
public --server-port override is involved. Resolve the entire A-answer set and
reject any nonpublic member before opening sockets. Try literals sequentially
within one three-second total deadline per candidate, with fair remaining slices.
Each menu refresh checks only its provider's two candidates concurrently. Valid
integer players=0 is online; optional metadata is unknown when absent and rejects
the response when malformed. Before joining, validate fresh DNS against the exact
respondent. A <=60-second UTC/monotonic process-local response proof can avoid a
duplicate Topic request during cooldown; never reconstruct it from disk cache.
Reject changed or missing selected map/mode/round identity on new status queries;
bounded response reuse cannot observe a round change during that short window. Bind verified
status, literal and configured port together, validate freshness at dispatch,
and launch only the verified BYOND client. Never add a permanent IP pin or reuse
this query for OpenDream. Source merge does not activate the launcher feed;
exact-head packaging/CI, independent review and a genuine public join gate release.
See tools/opendream-client/native/SERVER-DISCOVERY.md.
Public Topic writes use the fixed per-account status-requests lock/state,
independent of --root. Reserve before writing, retain failed reservations and
correlate validated IP aliases plus configured port. Spacing defers locally;
never sleep inside the three-second IO budget or silently retry after a write.
The 137-second reservation covers 130 seconds plus IO/clock margins; new instances
reuse system-wide monotonic anchors and cached result/age without adding another
startup wait. Legacy 1.0.5 wall-only history retains the 133-second migration guard
for its matching endpoint until its next reservation. A lower uptime waits only
through the new boot's first 133 seconds. Schema 2 caches bounded validated
metadata, never launch tokens; late results are tied to reservation IDs. Older
1.0.5 instances fail closed on schema 2. Clock/state/link failures pause locally. J explicitly rechecks a deferred selection; B cancels with no
background callback. Joining needs fresh safe DNS and an original-age recent proof
or one eligible new status response. Never extend status age or DNS token life;
recheck original monotonic and UTC60-second expiry at dispatch. Persisted cache
is display-only after process restart. See SERVER-DISCOVERY.md for join controls.
Wall time cannot prove game-time advancement or clear a server ban. Do not probe
the known banned Desktop source until owner-coordinated normal eligibility.

<!-- 2026-10-24: offline launcher social contracts -->
tools/opendream-client/native/Social is inert; production Main stays unwired.
tests/SocialContracts runs injected adapters/clocks/discovery/dispatch only,
separate from updater replacement tests. Reuse NativeStart and existing proofs;
dispatch is not connected gameplay or shard-travel evidence. See its README.
Keep player presence/native callbacks separate from DiscordPHP backend APIs.
SDK access/linking/distribution and application selection remain future gates.
Before an isolated .NET CLI home's first use, set
DOTNET_GENERATE_ASPNET_CERTIFICATE=false to avoid automatic development-cert setup.

## Language & toolchain
Never use an em dash; use "-" instead.
- **DM** (DreamMaker) - BYOND's proprietary language. Sources have `.dm` extension.
- **Entry point**: `civ13.dme` - the DM Environment file.
- **Build**: `dm civ13.dme` (Windows) or `DreamMaker civ13.dme` (Linux). Outputs `civ13.dmb` + `civ13.rsc`.
- **Lint**: `./dreamchecker.exe` (SpacemanDMM static analyzer). Config in `SpacemanDMM.toml` (sets `dreamchecker = true` for the langserver).
- **Target BYOND version**: 516.1688 from `tools/byond/version.json`; minimum compiler remains 516.1681. No `.vscode/tasks.json` is tracked at this base.
- **CI** (`.github/workflows/test.yml`): the default Ubuntu compiler bootstrap targets the manifest version, runs `DreamMaker -max_errors 0 civ13.dme`, and requires the exact version banner plus zero errors/warnings. Exact-head hosted 516.1688 acceptance is pending. The separate evidence-checker and MCP protocol workflows do not establish gameplay or rendering.

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

<!-- 2026-10-11: forced season decay control -->
`seasons(looping, force, advance_decay)` preserves debris age for forced calls
when the third argument is omitted. Natural calls count transitions. Forward
all three arguments in season overrides and honor `looping = FALSE` to avoid
starting extra recurring cycles from the admin command.

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

### Process scheduler integration

<!-- 2026-10-22: wolf cave timer ownership -->
Wolf caves own one guarded self-processing five-second chain; /full delegates
startup to the parent. Destroy stops the chain and ticking is excluded on custom
save export/import. Removing world-scanning duplicate calls reduces eligible
wanderer/flavor rolls; it is a scheduling correction with changed RNG frequency.
tests/wolf_cave_ownership has offline contracts and prepared native controls;
preparation does not compile/launch BYOND or establish native acceptance.
The dedicated cave executor has an offline-only CLI; real backend invocation
requires separate review. Native -close exits after world shutdown, not network
isolation; socket samples cannot prove continuous absence. See its EXECUTOR.md.
The resource-free cave fixture must declare Civ13's inherited movable anchored
field. Three held Windows attempts stopped at the strict one-member Job guard;
the third identified an owned conhost and logged the former missing declaration.
They establish no cave runtime result; preserve their original frozen packets.
Offline cave executor tests supply a canonical interpreter fixture path because
Ubuntu python3 is a symlink; native packet path/hash/link checks stay unchanged.
The proposed cave backend uses DETACHED_PROCESS instead of CREATE_NO_WINDOW to
avoid startup console attachment. Its conhost hypothesis is native-unverified;
all extra Job members still reject. See tests/wolf_cave_ownership/CONSOLE_STARTUP.md.

- Codebase uses legacy `/process/` system, not subsystems.
- Create a `/process/subtype` in `code/processes/`, set `name`, `schedule_interval`, `fires_at_gamestates`.
- Register the process var in `code/processes/__processes.dm`.
- `fire()` is called each tick; do your per-tick work there.
- Global singletons should be accessed via `global.xxx` or a `var/xxx` on a global datum.

<!-- 2026-10-22: research snapshot resume -->
Research consumes its retained current_list before each budget check, including
deleted benches. tests/research_scheduler checks source-derived offline traces
and the audited tail-loss control; native iteration/GC acceptance is still pending.
Subclass post-loop aggregation must account for final-entry EARLY normalization.

<!-- 2026-10-22: ping pass aggregation -->
Ping retains per-pass sum/count across budget returns and publishes before the
final-entry budget check. Every skipped client still consumes its snapshot entry.
tests/ping_scheduler is offline source-derived evidence; native clients remain untested.

<!-- 2026-10-22: cleanables phase ownership -->
Cleanables installs pending location work before the final count budget check.
Its retained content snapshot and survivor are released on completion/cancellation.
tests/cleanables_scheduler is offline source-derived evidence; native list/GC
handoff and iteration remain separate acceptance.

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

<!-- 2026-10-22: representative observer failure retention -->
Representative sampler and observer waits must recheck their existing monotonic
targets after early wakes. `tests/save_latency/representative` covers this offline.
Phase log/diagnostic retention runs after owned cleanup on failures too; secondary
retention errors preserve the original exception and never establish acceptance.

<!-- 2026-10-24: bounded-save roof compatibility -->
Roof preflight must use the shared versioned content decoder for typed formats
2 and 3. A format-2-only plan skips chunked roof contents before area validation.
Offline source checks do not establish native format-3 roof recovery.

<!-- 2026-10-24: complete conditional offline projections -->
The save_movement adapter selects the explicitly declared collector-disabled
branch; it is not a general DM preprocessor. Proc-local column-zero #ifdef lines
must not truncate ownership/return tails. Unknown symbols/directives and malformed
conditional scope fail even in inactive branches. Preserve both-branch/sentinel
and historical-defect controls. These are offline models, not collector or native
gameplay acceptance; do not change production code to make an adapter pass.

<!-- 2026-10-23: footwear water composition -->
Mud stains use brown blood_color/blood_DNA and the worn shoeblood overlay;
clothing dirtyness only supplies examine text. Water filters must group the
footwear image with its nested stain (KEEP_TOGETHER only while masked), and
new update_inv_shoes images need the current mask before publication. Keep
durable stain data intact. tests/footwear_water_mask checks source contracts
and prepares a tiny production-proc fixture; compilation/source checks do not
establish native client clipping, stance, movement or lighting acceptance.
The pinned native image getter returned lowercase #RRGGBB text for the tested
blood/mud inputs. The fixture comparator first requires text of exactly seven
characters matching #RRGGBB, then ignores hexadecimal case. Never coerce nulls,
named colors or matrices. Keep wrong-channel/missing-stain controls and preserve
the earlier failed raw-text comparison receipts; diagnostics are not pixels.

<!-- 2026-10-23: persistence minimum date -->
Persistence activation, configured startup and completed metadata restoration use
apply_persistence_age_floor(). age is the displayed date/epoch; ordinal_age is a
separate research tier, and prototype research can advance it independently.
The 1943 floor preserves later dates and research data; unknown epoch labels are
not converted. tests/persistence_year checks source-derived offline traces;
run-durable-world.py --persistence-year separately exercises the real helper,
admin toggle, extracted configured activation and 24 v1/v2 ticker disk imports
in an isolated 8x8x2 world. Its three controls must reach their named assertions.

<!-- 2026-10-20: extraction instance collateral -->
The historical extraction instance fixture at b717ad2a6 shared registry state
across assertions. Its overlap/generation mutants caused downstream failures as well as
their named targets. Run 39140469088 preserves complete native results; keep its
failed verdict intact. Explaining collateral is not approval to weaken the
single-target oracle. See docs/extraction-instance-contract.md.

<!-- 2026-10-17: maintainer rules -->
- Art: reuse and transform existing art assets where possible. Never use image
  generation tools (Stable Diffusion and similar). New art made from scratch must
  use appropriate graphic tools such as vector-based graphics.
- DreamDaemon must always run as trusted (`-trusted`), with maintainer approval.
  All repository runners launch `-trusted`; never add `-safe`. Fixtures must still
  disable outbound hooks/shell effects through their startup adapters.

<!-- 2026-10-13: native catch variable scope -->
BYOND 516.1681 treats catch variable declarations as proc-scoped. Use distinct
names for separate catch blocks in one proc or compilation fails with duplicate definition.

<!-- 2026-10-19: combined sub-tile mining acceptance -->
`tests/human_subtile/run.py --suite mining` stages the full merged game and
exercises native collision dispatch, mining snapshots and physical offset drift.
Its mining-position control must fail the same-anchor drift oracle, not merely
some assertion. Headless authority is adapted: only a separately attached real
client can establish client.moving ownership through the optional client entry.
Keep the production adapter disabled until that separate acceptance is met.

<!-- 2026-10-19: opt-in physical human movement -->
The experimental human adapter keeps the living Move third gameplay flag and
uses one-use context at movable's native offset seam. Runtime ownership fields
need explicit custom-save exclusion. Owned capsule presence is detected before
loader assignments; no-capsule legacy humans retain their old offset policy.
The minimal world-save stub rejects owned capsules instead of faking restoration.
Use tests/human_subtile/run.py --prepare-only for offline exact-Git staging;
native integration and connected-client timing are separate acceptance gates.
DM reserves proc name run, and an if-local variable cannot be read afterward;
offline text contracts do not replace the pinned native compiler.

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

<!-- 2026-10-24: area topology and persistence review -->
Area references are anchor coordinates plus type, not independently recreated
area objects. Reconstruct only proven saved roof topology before field decoding;
retain/recheck exact base/destination identities, including empty instances, and
scope entry IDs by z. Never fabricate unrelated areas or weaken mismatch checks.
World-preserving preflight is separate from input-file byte immutability: absent
native savefile fields need presence checks and copy-only tests. Honor refused
movement before landing effects or ownership/success changes. Offline source
adapters must reject unhandled preprocessor directives, not silently truncate
procedures. Cross-z guards do not make a yielding save atomic. See
`docs/zone-persistence-audit.md` for #3290, known gaps and the regression matrix.
Future atmospheric rooms/networks need logical identities separate from area
types/objects, versioned topology and authoritative gas/thermal stores. Rebuild
derived caches and admit workers only after full restore/conservation checks;
see `docs/atmosphere-persistence-readiness.md`. This plan does not activate atmos.

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
  needs a relative log path inside the isolated working directory.

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

<!-- 2026-10-23: timber seedling ownership -->
Timber seedlings reuse crop soil/water/stage helpers through processing_objects;
their growth override registers without sleeping. Save growth_time_left but exclude
last_growth_tick, and anchor it in after_load without resetting durable progress.
Maturation rechecks open outdoor ploughed space, climate and season before creating
the existing live_tree. See docs/tree-planting.md and tests/tree_planting; offline
source execution and fixture preparation are not native or client acceptance.
The tree native runner now uses the unchanged native_fixture Session and keeps
fresh-process reader/writer probes. Windows startup-listener rejections remain
failures; do not route around the no-socket guard. See the native-validation doc.

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

<!-- 2026-10-23: private variable observability -->
Before asking an operator to manipulate native BYOND variables, inspect the
implemented structured paths in `docs/variable-observability.md`. Run
`scripts/nomads-lifecycle/agent_debug.py discover` offline first. For an already
authorized installed runtime, `agent_debug.py recovery --root <private-root>
--revision <installed-40-hex>` returns `data.variable_identity`; use its exact
session/round with `variable_observability.py --root <private-root> --revision
<installed-40-hex> --session <observed-32-hex> --round-id <observed-round>`.
Use a verified full Python executable. Each runtime command makes one existing
authenticated loopback status read with a 15-second/32-KiB limit and no retry.
The schema-1 status field is `debug.variables`; reader evidence is
`data.failure`, with active/last save/load ownership alongside it. There is no
generic runtime variable MCP tool or arbitrary ref lookup.
Check `data.failure_error`: stale, mismatched, partial or malformed retained
failure evidence is withheld without hiding independently valid current/last
operation ownership. `ok:true` is not acceptance of a rejected retained capture.
Null scalar throw fields mean unknown and remain distinct from numeric zero;
the reader does not invent a never-thrown default.

Collection/exposure and automatic local output remain default-off until a
separately authorized exact-build deployment/restart and local opt-in using
`config/variable-observability.txt` containing `enabled`, existing lifecycle
credentials/revision, and a separately provisioned operator-private runtime
`data/desktop-supervisor/variable-observability/` directory. Do not
activate them from source/PR approval or claim this tooling is already live.
The automatic path is runtime-relative
`data/desktop-supervisor/variable-observability/last-failure.json`; publication
must fail harmlessly if that fixed directory is missing or unwritable, with no
legacy-path fallback or automatic ACL/directory creation. Explicit old-file
reads remain supported. The reader's `--input <file>`
mode is offline and requires independently obtained expected revision/session/
round. Keep raw captures private. Unknown fields are stripped, but refs/types/
coordinates remain operational data requiring review before public sharing.

For an `original_target` save rejection, inspect source type/field/entry,
source/target physical turf z, fixed throw links, throwing flag, thrown-list
prefix membership, destruction flags and operation ID/stage together. A
truncated registry miss is unknown. `rejected_by_persistence_guard` describes
the rejection, while saturated runtime skip-decision counts observe the existing
`persistence_runtime_var` policy; neither authorizes nulling links or proves live
cleanup. The separate persistence fix owns that policy. Preserve guard failures.

Default reads expire after 60 UTC seconds and must match build, boot,
round and, for status failures, current/last operation plus tick bounds and a
realtime reversal check.
UTC uses the finer `world.timeofday` input with explicit UTC formatting and a
midnight rollover rejection. Epoch `world.realtime` is coarse metadata; only
reversal is checked there, while UTC and ticks enforce bounded age. Never relax
future-time rejection to hide epoch floating-point rounding.
Re-reading retained evidence does not refresh it. Explicit `--historical` is
allowed only with offline `--input` and
labels evidence `historical_only`; it cannot refresh or query live identities.
Native refs and pooled objects can be reused;
`capture_only`/`generation: unavailable` must never be treated as
durable or current identity, even when type/location match. Depth is eight,
owner frames eight, registry prefixes 256, output 32 KiB; missing, partial and
stale data are explicit unknown/error states. No eval, generic proc invocation,
mutation, credentials, relaxed protections or listener is introduced.
Offline synthetic reader/source checks and native-packet preparation are covered.
The `df639b1` tiny native attempt emitted 22 successful checks but failed overall
reader/ownership acceptance and logged a startup loopback bind; preserve that
failed verdict. The source UTC correction is not native-verified. Topic and full
save/load/gameplay acceptance remain unverified. Compilation CI is separate
evidence bound to its tested head. Observation
does not authorize save/load, restart, cleanup or other live mutation.

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

<!-- 2026-10-19: bounded launcher transport retries -->
Launcher retry tests use injected HTTP handlers, never BYOND/accounts. Retry only
classified resets/timeouts with finite attempts and an overall body-read budget;
certificate/auth failures, untrusted redirects and bad hashes remain fail-closed.
Delete only a failed attempt's newly created staged file, never a pre-existing
path. Preserve TLS validation and redact errors. Proxy IsBypassed(false) alone
does not prove traffic used a proxy. Source changes do not activate a release.

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

<!-- 2026-10-17: yeast bread -->
Dough bakes into a sliceable loaf only after yeast (5 `enzyme` units) is kneaded
in and its 5-minute rise deadline passes; otherwise ovens produce flatbread.
`rise_ready_at` is runtime-only and restarted by `after_load()`; `check_risen()`
is lazy so a lost wait cannot strand dough. Oven `process()` ejects products onto
its turf, so fixtures must inspect the turf, not oven contents. `map_storage.Load_Entry`
does not call `after_load()`; isolated fixtures must call it like the world loader.
`tests/yeast_bread/run.py` covers this with five generated-source controls.

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
<!-- 2026-10-24: bounded offline CI baseline and exact-source receipts -->
CI always runs selector-policy, stubbed bootstrap and serializer-source tests.
scripts/ci_baseline.py registers exact reviewed offline files and bounded impact
paths for research/ping scheduling, persistence-year projections and synthetic
evidence validation. Affected production, existing-test and helper edits select
those files; unknown impact or missing comparisons explicitly selects the whole
small offline registry. Do not add broad Python discovery or native launchers to
this registry without inspecting imports, subprocesses, dependencies and cost.
Other existing regressions retain manual opt-in and introduced-test admission;
ordinary edits do not expand native/costly admission. Register those suite guards
through ci-selection.yml. Preserve all separate execution/resource holds.

CI required aggregate requires successful selected jobs and exact head/base,
run/attempt and selection-bound offline/compile receipts. Missing, failed,
unexpectedly skipped or empty required execution fails. Documentation-only
compilation is an explicit skip, never compiler acceptance. Inspect ci-* artifacts
and docs/ci-selection.md; a job-level green alone does not describe what ran.
<!-- 2026-10-24: event coverage and check identity -->
Supported edited PRs evaluate the base/head diff for compilation but keep native
admission off. Edited/other-base PRs, feature pushes and manual runs use the
informational build/aggregate names even when a real compile passes. Only ordinary
opened/synchronize/reopened PR scopes and master pushes retain gating names.
Selector failures or missing outputs retain failed gating names. Inspect receipt
action and compile/native/gating reasons; an informational success cannot certify
omitted native coverage. Preserve existing native opt-ins and toolchain ownership.
Hosted DreamMaker results must identify the actually executed manifest version;
Python projections, compiled core_boot variants and native runtime/gameplay
acceptance are separate evidence. Historical 516.1681 runs do not verify 1688.
<!-- 2026-10-28: re-run of failed jobs -->
CI receipt consumers download ci-selection/baseline/compile by the producing
job's `attempt` output: a re-run of failed jobs reuses earlier jobs whose
artifacts keep their original attempt. Receipts record `job_attempt`; keep the
attempt ordering checks in scripts/ci_baseline.py when changing these jobs.
Cloud-only workers must keep unavailable local native checks as not_run. After
owner review and authorized push, obtain hosted validation for the current head
and inspect its outcomes/artifacts; never substitute local tool absence or an
older green run. This policy does not authorize installing native tools, running
held probes, deployment, publication, branch-protection changes or merging.

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
<!-- 2026-10-23: atlas catalog variants -->
<!-- 2026-10-27: direct atlas resource search -->
Atlas search has separate bounded Resource and Recipe results. Resource matching
uses catalog names and canonical IDs, with case/whitespace/underscore normalization;
IDs and labels stay unchanged. Recipe filters do not hide resource matches; direct
resource navigation reuses atlas_resource/resource(id) and clears recipe filters.
Empty input browses recipes. tests/crafting_atlas/resource-search.test.mjs checks
the production template offline; resource_search.dm is a hosted renderer fixture,
not connected-client or live-server acceptance. Do not add guessed reagent aliases.

`scripts/atlas/variants.py` groups only identical explicit 13-field material rows
with equal extracted semantics. Catalog identity/source IDs stay as variants;
never group by name, canonical ingredients or outputs alone. Counts and legacy
pages use groups; search/system filters must match the same variant and selected
details must use its source. `tests/crafting_atlas/variants.dm` executes selected
source, old-ID, filter and legacy page contracts through the existing bounded
Atlas runner. Verify exact-head hosted renderer/assets results before acceptance.

`scripts/atlas/catalog_metadata.py` keeps unlock research tiers/minimum gates
separate from catalog field 12's maximum allowed era. Parse research constructors
with balanced arguments; the enclosing registration call adds another closing
parenthesis. Processor tiers describe station construction, not use restrictions.
`tests/crafting_atlas/run.py --compile-only` never starts DreamDaemon; runtime
navigation and omission controls require the normal isolated runner or CI.

<!-- 2026-10-11: bounded animal harvesting -->
- `code/modules/1713/animal_harvest.dm` centralizes corpse claims and bounded species products. The custom saver enumerates `tmp` fields, so in-progress harvesting/axe locks explicitly opt out via `persistence_runtime_var`.
- `tests/animal_harvest/run.py --byond-bin <516.1681-bin>` executes production yields, cancellation/concurrency, binding conservation and object save/load in temporary offline storage. `preview.py` renders existing DMI states for PR sprite review; it is not a gameplay capture or full-server memory test.

<!-- 2026-10-23: leather tanning accounting -->
Leather processing in `stacks/sheets/leather.dm` uses one eventual leather sheet
per stack unit, with distinct raw/prepared/wet/dry material identities. Never add
unpropagated per-object yield fields: splitting and merging must conserve yield.
Tanning uses explicit paid vessel interactions, since reagent touch callbacks can
see the whole holder volume. The rack preserves actual contents and excludes its
runtime epoch/busy flag from saves. `tests/animal_harvest/test_tanning_sources.py`
is offline evidence; `tanning_probe.dm` requires separate native acceptance.

Rack insertion must transfer held inventory directly with `transfer_held_item_to`,
not stage stacks through a turf. Human `drop_from_inventory` definitions must
forward the parent's result with `return ..()`; keep both organ guards and the
implicit arguments. The parent can still report TRUE after refused/redirected
movement, so destination-sensitive callers must check actual location too.
The #3286 discarded-return control now uses an explicit legacy wrapper adapter
alongside a production-human success assertion. Offline checks and the remaining
native acceptance proposal are in `tests/flax_processing/test_drop_return.py`
and `tests/flax_processing/drop-return-acceptance.md`.
The selected Linux flax runner follows the current manifest and verifies archive
members before each launch; old/mismatched banners fail offline runner contracts.
Its historical 1681 CI rejection is preserved. Existing tanning-fixture edits do
not select the harvest suite; its frozen version gate needs separate admission.
Use the production human subtype in transfer tests, not just a `/mob/living` stub.
Production `stack/Crossed` merges floor pieces
into the arriving stack; clear hand/HUD ownership only after destination admission,
check actual location, and restore the hand on rejection/redirect. Keep nodrop and
persistence movement checks. [Rack transfer regressions](tests/animal_harvest/rack_transfer_probe.dm) cover
human inventory, floor-merge controls, bags, and explicit movement-failure adapters;
those adapters do not establish the exact trigger of an unobserved live failure.
Raw, prepared, wet and dry hides are `processing_only` materials: softness is not
a crafting permission. Clear cached recipes before that guard and mirror it in
Atlas export. [Hide recipe regressions](tests/animal_harvest/hide_recipe_probe.dm) use the actual global catalog plus explicit
research admission; it rejects intermediate utensils while retaining leather/pelt
recipes. [Atlas contracts](tests/test_tanning_atlas.py) check the exported processing-only boundary.

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
<!-- 2026-10-17: chemical registration -->
`initialize_chemical_reagents()` keys reagents by `id` and skips nameless types:
a subtype without its own `id` silently replaces its parent (cafe latte once
made `"coffee"` resolve to Cafe Latte). Give every concrete reagent an `id` and
abstract parents `name = null`. A proc on a misspelled path creates a phantom
registered type. Never redeclare `/datum/chemical_reaction/` with defaults: its
`required_reagents` were inherited by `kevlar` and `wizard_boy_recipe`. Reactions
only queue in `handle_reactions()`; fixtures call `process_reactions()`.
`tests/chemical_registration/run.py` audits all of this natively.

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

<!-- 2026-10-19: inactive Dagger compilation -->
`tests/dagger_map/compile_map.py` compiles the inactive DMM with production types
in a disposable root-local DME, plus a missing-type diagnostic control. CI's
`dagger_map_compile` opt-in retains exact-head logs. No game starts; successful
compilation is not controller, instancing, protection or gameplay acceptance.

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
<!-- 2026-10-17: native fixture gotchas found unblocking #3197/#3199/#3082 -->
Native BYOND 516.1681 `OpenPort("none")` returns 0 even when it closes the port;
assert the resulting `port == 0` and a refused reopen, not the return value.
`new /atom` without a loc raises `bad loc`; use `/atom/movable` for atom-hook
coverage. `underlays`/`overlays` hold appearances, not `/image` datums, so
`for (var/image/I in D.underlays)` never matches; iterate untyped and read
`U:icon_state`. Headless HUD fixtures need `makeDatumRefLists()` (fills
`HUDdatums`) and an explicit `defaultHUD` (only `check_HUD()` sets it, for a
client). A runner's "failed outside its intended assertion" can mean an earlier,
equally valid assertion caught the mutation; `*_assert` procs report their own
throw line, not the caller's. GitHub job logs are readable via the GitHub MCP
`get_job_logs` when direct log downloads return 403.

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

<!-- 2026-10-18: building renderer gravity -->
Building-sky entry must exempt /atom/movable/lighting_overlay explicitly; it is
not an /obj/effect. Runtime level allocation and turf replacement can otherwise
drop a black renderer onto lit ground. The building lighting probes separate
replacement callbacks, explicit entry, and an adapted allocation interleave.
They verify native lighting state, not connected-client rendering.

<!-- 2026-10-12: lighting reinitialization -->
<!-- 2026-10-17: restored-round lighting -->
Turf luminosity is always 0; native tile visibility comes from lighting overlay
`luminosity` (an overlay at 0 leaves its tile black). Invisible overlays still
light their tile: `invisibility` 100 only stops shading being drawn. Pregame
overlays are hidden (100) until daylight is applied, and corner activation does
not queue overlay updates; only light sources and daylight do. Fresh rounds
apply daylight through the roundstart hook, but restored rounds skip
`ticker.setup()`, so `restore_round_state()` calls `apply_restored_lighting()`
for every restored round, including legacy saves without durable metadata.
`tests/core_boot/run.py --lighting-restart --map maps/nomads/nomads_europe.dmm`
checks a real save, fresh-process import and sampled overlay luminosity; its
`restored-lighting` control removes that application. Default Nomads cannot be
saved (cross-level ladders), so use a single-level persistence map.

Lighting startup must reconcile existing inactive shared corners after adding overlays, as well as activating fresh corners. Native largest-startup fixtures exercise a later overlay pass after standalone corner creation; use bounded overlay-master visits without retaining a corner registry.

<!-- 2026-10-12: native population readiness -->
Mob processing retains unfinished copied population snapshots across budget returns. A fixed schedule interval does not guarantee newly constructed humans received Life. The full seasonal constructor fixture waits at most 30 real seconds for natural first service while checking actor identity/location/death; its service control excludes one retained actor from both live membership and the pending snapshot. Never invoke Life directly to satisfy scheduler evidence.

<!-- 2026-10-12: animal health and combat dispatch -->
<!-- 2026-10-23: domestic defensive retaliation -->
Adult domestic sheep/goats/pigs/cattle, horses and camels explicitly opt into
zero-damage immediate retaliation. `Weaken(2)` counts Life updates, not ds;
ten-second runtime deadlines on both participants prevent herd stun chains.
Keep juvenile and larger-attacker escape gates, husbandry dispatch and custom
save exclusions. tests/animal_combat has offline source checks and a prepared
native fixture; native/client acceptance remains separate.

Simple-animal starting health and maxHealth must match unless an explicit policy
is documented: Life clamps health and updatehealth recomputes it from maxHealth.
Do not call parent attackby after an explicit item attack; that repeats damage,
logs and material wear. tests/animal_combat/run.py checks compiled inherited
health defaults, native Life, single sharp/blunt attacks and wear across behavior
branches, noncombat dispatch, healing/death and generated negative controls.

<!-- 2026-10-19: injected Windows adapter CI -->
The bounded-build test suite runs without Windows DLLs. Inject ctypes error
state too: get_last_error does not exist on Linux. CI explicitly recognizes the
two added bounded-build tests; passing them is not native containment evidence.
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

<!-- 2026-10-15: native seed port contract -->
`world.OpenPort(0)` opens any available port; `world.OpenPort("none")` closes it.
Do not infer offline isolation from `-close`: verify the critical phase has port0
and an actual zero-listener OS census. The Gaia seed observer rejects reopening
and denies all seed clients; `tests/world_save/playable_reconnect/test_port.py`
checks its native516.1681 port contract separately from full recovery acceptance.
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
<!-- 2026-10-18: lazy floor decal tracking -->
Native nullable tracking lists do not auto-materialize on `|=`: omitting the
initializer raises a type-mismatch exception. `tests/floor_decal_tracking` covers
the writer, seasonal reader and native entry compatibility. Ordinary turf saves
exclude this derived field through their existing saved-variable allowlist.

<!-- 2026-10-19: bounded admitted saver draft -->
World-save traversal retains operation admission, durable state/player ownership,
and active before_save_context transfer frames. Invalidated active parents fail
closed with backup recovery; do not restore the old detached-parent exporter.
Level format 3 adds bounded content chunks; keep version-2 and legacy readers,
including durable reachability and ownership decoding. Round-state versioning is
independent. Old readers reject version 3, so downgrade needs retained old files.
The sleep(0)-below-80% policy increases effective duty cycle and is experimental.
Dispatch save_latency_regressions for native dense/backup/heartbeat/refusal and
current persistence checks; preparation alone is not acceptance or deployment.
<!-- 2026-10-19: bot helper contention -->
Bot control uses nonblocking flock and returns busy (75) without systemctl or
cooldown writes under contention. The draft unit remains disabled pending
independent game supervision and native bot-restart/game-survival acceptance.
<!-- 2026-10-19: serializer profile admission -->
Test-only save profiling starts after save_world_contents accepts its operation
token. Never wrap the public Save_World entry on current sources: busy/reentrant
requests must not restart another serializer's clock. Source tests are offline;
manual world_save_profile_regressions is separate native evidence.

<!-- 2026-10-19: exclusion dispatch source contract -->
Runtime-exclusion hooks can have early mining ownership guards before their
terminal list-membership return. Preserve those guards when replacing only the
list with switch dispatch; source fixtures must pin current inherited helpers
and include all mining fields. Offline source parity is not native evidence.

<!-- 2026-10-19: Linux exclusion parity lane -->
Exclusion dispatch run-ci.py consumes source-only packets for bounded Linux CI
parity and three controls, retaining receipts. It is separate from run.py's held
Windows grant runner; neither an offline pass nor workflow addition proves native
parity, and this lane makes no benchmark or listener-sampling claim.

<!-- 2026-10-19: native bind versus host address -->
Linux BYOND world.address can report the host interface even with -ip 127.0.0.1.
Isolated exclusion CI verifies the engine's startup bind diagnostic plus closed
port/refused reopen state; do not use world.address as the socket-bind oracle.

<!-- 2026-10-19: independent typed wait contexts -->
`do_after` keeps mining_context in its ninth argument; opt-in gameplay_context
is tenth and forwarded by name. Reject simultaneous contexts before either
claim. Preserve mining progress/owner cleanup and ordinary null callback order.
The gather disabled-source hashes project reviewed master; refresh them only
after verifying all four full-file projections. Idle-metabolism extraction must
project the disabled helper before finding its conditional proc declaration.
