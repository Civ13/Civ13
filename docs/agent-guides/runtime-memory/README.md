# Runtime memory: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

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

<!-- 2026-10-11: isolated legacy garbage queue -->
When normal startup is disabled, atom `qdel` removes the atom from its location
and queues it in `delayed_garbage`; it does not set the newer `gc_destroyed` flag
checked by `QDELETED`. Fixture disposal assertions must reflect that actual
queue and must not claim that production garbage collection has drained it.

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

<!-- 2026-10-14: chemical smoke source retirement -->
Chemical smoke systems are single-use: their two reaction callers construct fresh
systems. The hidden reagent source must survive every queued spawn callback, then
retire through atom/reagent cleanup. `tests/chemical_smoke_ownership/run.py` checks
production copies, lifetime bounds and repeated holder/membership cleanup against
an immutable historical negative control in temporary offline storage.

<!-- 2026-10-12: deferred organ icon readiness -->
External-organ constructor icon work must reject retired or partially hydrated owner/species links. Native save loading may yield between those links; hair style lookup previously dereferenced a missing organ species. tests/human_corpse_decay/run.py includes icon-readiness and icon-callback mutation controls and prints rejected native diagnostics.
