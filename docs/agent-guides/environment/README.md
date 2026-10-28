# Environment: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- 2026-10-27: inactive ecology activity heatmap -->
The data-only ecology_activity_heatmap datum has no singleton, process or player
hooks. Samples/queries bind caller-captured epochs before touching clock/coverage;
missing, stale or incomplete inputs never authorize spawning. At most 256 input
rows and 4096 stored cells; caller supplies anonymous active occupancy and time.
should_save is FALSE and all runtime fields explicitly exclude custom persistence.
Source contracts are bounded offline CI only, not DM/native behavior proof.
DME inclusion permits exact-revision compile coverage; activation, warm-up and
activity/visibility adapters remain separate work. No animal mutation is added.

<!-- 2026-10-24: precipitation-driven generated snow -->
Ground snow uses weather_snow units on exact ordinary dirt/grass, actual snowfall,
exposure and get_temp (stick <=0C, melt >2C). Existing winter/snow/ice stays unmarked.
No seasonal snow-ground replacement/thaw; retain water/ice/calendar/weather logic.
One bounded swap-remove worker owns sampling. Save only units, never image/index;
legacy same-type load resets units before decode. docs/snowfall-ground.md lists
gameplay predicates, exclusions and source/native acceptance limits.

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

<!-- 2026-10-11: forced season decay control -->
`seasons(looping, force, advance_decay)` preserves debris age for forced calls
when the third argument is omitted. Natural calls count transitions. Forward
all three arguments in season overrides and honor `looping = FALSE` to avoid
starting extra recurring cycles from the admin command.

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

<!-- 2026-10-11: water registry replacement -->
- `water_turf_list` must track only current water turfs; turf replacement invokes `Del()` and retargets saved turf references. Water New/Del maintain registry indexes with constant-time swap removal.
- `scripts/test-water-memory.ps1 -ByondBin <BYOND-bin-directory>` checks subtype replacement, dry conversion and interleaved registry removals across 20 cycles without starting game systems.
<!-- 2026-10-11: season memory regression -->
- BYOND turf replacement calls `Del()` and preserves sleeping procs. Registry cleanup in `Destroy()` alone does not handle replacement; grass registration is maintained by grass `New()`/`Del()`.
- Dirt recovery uses an identity token so old sleeping recovery chains stop after turf replacement. Obsolete waits release their token when they wake (up to 20 minutes), without deleting live entities.
- `scripts/test-season-memory.ps1 -ByondBin <BYOND-bin-directory>` executes production turf lifecycle bodies in an isolated world, with accelerated recovery waits and temporary output. It checks repeated replacement, bounded grass registration, one recovery chain per dirt turf, and planted-soil behavior. Synthetic process memory is not full-game memory evidence.
<!-- 2026-10-11: bounded winter survival -->
`tests/weather/run.py` runs inherited production thermal procs and real human
constructors in isolated storage, with a pinned baseline and cold-loss negative
control. Its accelerated iterations are nominal one-second Life calls, not
elapsed gameplay. `cold_wetness` is a durable bounded 0-1 scalar, without timers
or retained references. Ordinary uniforms have a 240 K cold rating; overlapping
layers help but insulation caps at 90%, and hypothermia still harms covered mobs.

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

<!-- 2026-10-11: bounded environment sweeps -->
- `tests/environment_sweeps/run.py` runs production daylight/weather sweep bodies and lighting color calculations with isolated startup, pinned baseline comparisons and yield/reentry controls. See `docs/environment-sweeps.md`; it does not prove client rendering or production latency. BYOND spawn copies local scalar variables: fixture completion flags shared across spawned callbacks must use a shared list/datum.

<!-- 2026-10-11: human corpse decay -->
- `code/processes/human_corpse_decay.dm` owns bounded human/bones exposure. Only retirement-created remains expire; use idempotent `do_rotting()` instead of another corpse timer. Native drops retain actual nested gear; blocked roots abort retirement.
- Persistence restores saved DEAD humans without rejuvenation or death-hook replay. Durable exposure survives reload; runtime record pointers/epochs do not. Native mob qdel deletes immediately, so observe pre-retirement state through the inert `corpse_retired(body, turf)` hook.
- `tests/human_corpse_decay/run.py` runs production human/inventory/revival/save/GC paths in temporary storage with pinned516.1681 and nodrop/restart/no-op negative controls. Use a fresh savefile for each independent graph; reusing entry directories can mix stale fields.

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

<!-- 2026-10-12: native population readiness -->
Mob processing retains unfinished copied population snapshots across budget returns. A fixed schedule interval does not guarantee newly constructed humans received Life. The full seasonal constructor fixture waits at most 30 real seconds for natural first service while checking actor identity/location/death; its service control excludes one retained actor from both live membership and the pending snapshot. Never invoke Life directly to satisfy scheduler evidence.
