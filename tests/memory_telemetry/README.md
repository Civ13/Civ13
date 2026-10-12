# Bounded lifetime telemetry

`code/_helpers/memory_lifetime_telemetry.dm` provides `memory_lifetime_snapshot()` and `/datum/memory_lifetime_recorder`. There is no startup instance or automatic recording. Create a recorder through existing datum/proc inspection and call `start(sample_count)` explicitly. The count is clamped to 1-120. A second start while active is rejected. `stop()` cancels the pending invocation and preserves rows; inactive `reset()` clears them. `Destroy()` cancels the loop, clears both rings and delegates to its parent. Runtime fields are excluded from persistence through a parent-calling override.

The snapshot projects numbers from existing GC/helper/pool counters and grass, water, cleanable, abandoned-item and corpse-candidate registry lengths. It neither scans the world nor retains sampled entities. GC forced-delete type count is the number of distinct existing type keys; the existing GC `logging` map retains the per-type totals. Every stored row contains only string keys and numeric values.

Recording sleeps for at least one game tick, measures real awake `world.timeofday` deltas in deciseconds with midnight wrap, and samples counters once at least one observed second has elapsed. Numeric interval and scalar row rings each retain at most 120 entries. Only snapshot/request time sorts a bounded interval copy for nearest-rank p95 and max. These are **observed tick intervals**, including scheduling delays and BYOND clock resolution, not CPU time spent executing a whole-world tick. The recorder does not promise sub-decisecond accuracy. Queue drain rates use the dedicated `queued_drained` count incremented only when garbage.fire consumes an entry, excluding direct deletion paths. Counter rates use the measured window, clamp counter-reset deltas to zero, and return zero for zero-duration windows.

`export_rows()` returns chronological copies suitable for JSON and alignment with an external OS private/RSS sampler. Internal `rows` has physical ring order after wrap. The finite live loop stops after the requested number of one-second rows; explicit diagnostic calls to `record_snapshot()` also obey ring bounds. Stopped/destroyed sleeping invocations release their local token when they next wake. No process memory or OOM conclusion follows from registry counts.

Run the native isolated regression with a verified Python interpreter:

```
<python> tests/memory_telemetry/run.py --byond-bin <516.1681-bin> --evidence-dir <fresh-directory>
<python> tests/memory_telemetry/run.py --byond-bin <516.1681-bin> --evidence-dir <fresh-directory> --negative-control overflow
<python> tests/memory_telemetry/run.py --byond-bin <516.1681-bin> --evidence-dir <fresh-directory> --negative-control rate
<python> tests/memory_telemetry/run.py --byond-bin <516.1681-bin> --evidence-dir <fresh-directory> --negative-control retention
```

The fixture includes the complete production helper unchanged and minimal scalar/list process adapters. It checks projections, no entity values, ring caps/wrap/order, p95/max, midnight crossing, observed-duration rates, counter reset, zero-span rates, export isolation, default off, start/stop/reset/reentry, actual sleeping finite completion, stale invocation cancellation, Destroy and all persistence exclusions. Deterministic calls inject clock values into `record_tick`; the final loop uses the actual native clock and sleeps. Controls alter only generated copies and must produce exactly the documented assertion failures, with zero compiler warnings and zero runtime/engine diagnostics. Their successful exit means the intentional defect was detected, not that defective production passed.

Each evidence directory retains exact copied source/probe, their hashes, HEAD, dirty status/patch, compiler and daemon logs, and native results. Isolated evidence does not establish full-game or long-soak behavior. The separate `run-game.ps1`/`game_probe.dm` adapter exercises normal startup, bounded real effect churn and externally sampled process memory in temporary state; see its output provenance for the actual tested commit and limits.

Run the full-game adapter with `./tests/memory_telemetry/run-game.ps1 -ByondBin <516.1681-bin> -EvidenceDir <fresh-directory>`. Its marker and 250 ms external sampling align native scalar rows with owned-process private bytes/RSS using an explicitly coarse polling bracket, not a precise shared clock. It checks a bounded 25-second effect churn window; it does not prove long-soak or production tick latency.
