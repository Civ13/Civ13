# Memory ownership and GC verification

Production scheduler, deletion, pools, weak handles, dynamic callbacks, reagent
holders and completed process snapshots now have explicit retirement contracts.
No useful gear acquires an automatic lifetime through this change.

Run with a trusted BYOND 516.1681 bin directory and a verified Python executable:

```
<verified-python> tests/memory_ownership/run.py --byond-bin <bin>
<verified-python> tests/memory_ownership/run.py --byond-bin <bin> --negative-control pool-idle
<verified-python> tests/memory_ownership/run.py --byond-bin <bin> --case benchmark
<verified-python> tests/memory_ownership/run.py --byond-bin <bin> --case benchmark --baseline-scheduler
```

The default native fixture executes 14,045 assertions with normal startup disabled.
It covers callback order, delays, cancellation limits, 7,000 cancellation cycles,
5,001 simultaneous callbacks, overflow, reentry, exceptions and target-index
release. GC checks cover both deletion markers, hints, startup retirement,
timestamp identity protection and cleanup exactly once. Pool checks cover exact
100-per-type/1,000-total limits, explicit type opt-in, bounded idle eviction and
reuse removing idle ownership. Eleven generated-copy mutation controls must fail
at their intended assertions; compilation/runtime errors do not count as success.

Baselines pin immutable commit f556e39b93fc97f41020b2d8c5f2abed63fab497.
Separate weakref_ownership, callback_ownership, reagent_ownership and
process_snapshot_ownership and nanoui_ownership suites execute production procedures and require
specific historical failures. Their runners support --baseline and --evidence-dir.

Fresh --output folders retain commit, source diff, compiler/runtime logs and native
results. Optional Windows completion samples record private bytes and RSS.
Evidence from a dirty checkout is preliminary; repeat acceptance after committing.

## Ownership and performance

Helpers are retired before invoking arbitrary code and are cleared on every exit.
The reserve keeps at most 5,000 reusable helpers; cancellation indexes own only
pending targets. Reserve removal uses the end of the list. Three final indexed
150,000-cycle schedule/execute measurements at clean commit f6d769d3751275f63a4481db61290dde79e9cbb4 were 1.0875, 0.885938 and 1.00469 seconds;
the immutable baseline was 1.850, 2.01094 and 1.94531 seconds. Median elapsed time fell 48%.
These isolated measurements
do not establish production latency or sustained server memory use.

The cancellation inspection intentionally retains helper handles: 4,000 historical
helpers retained arguments, versus zero after the change. This proves reference
clearing while helpers remain reachable, not an observed production leak. Native
collection reclaimed unreachable invalid helpers on both versions. Completion
RSS/private samples are not multiweek or OOM evidence.

Pools admit reviewed legacy caller families explicitly, clean once, reset reusable
state, and expire idle objects after five minutes with at most 32 retirements per
GC run. Existing GC limits remain 300 candidates and 30 forced deletes per run.
GC diagnostics expose queue size, oldest age, high-water/enqueue/drain counts,
forced owners and pool size. Existing scheduler timing and per-type forced-delete
counts remain available without a new world-wide reference scan.

The head-cursor queue experiment (parallel ref/timestamp arrays, a current-timestamp
map and a head cursor) was rejected: it had no consistent speed benefit and
accumulated stale entries under reference reuse. Adaptive budgets remain
profile-gated; increasing deletion work without measured server tick pressure
would add risk. Its standalone benchmark runner was removed on 2026-10-28; the
recorded comparison follows.

Three-run medians on Windows, BYOND 516.1681, for 200 rounds of 300 enqueues plus
bounded drain, excluding initial backlog construction:

| Initial backlog | Ref reuse | Baseline ms | Candidate ms |
| --- | --- | ---: | ---: |
| 300 | Unique | 169.97 | 197.84 |
| 300 | Repeated | 110.90 | 94.06 |
| 10,000 | Unique | 1483.57 | 1426.52 |
| 10,000 | Repeated | 214.49 | 192.22 |
| 50,000 | Unique | 5505.43 | 5634.38 |
| 50,000 | Repeated | 1586.59 | 2065.52 |

With repeated refs and initial backlog 50,000, the baseline drained to zero slots
while the candidate ended with 59,900 allocated slots and only 300 current-map
entries. A future alternative needs deduplicated bounded pending storage before
integration. These are synthetic single-machine timings, not production
locate/del costs or full-server performance.

Removing the turf statement after native del(src) is source cleanup: its historical
fixture already passed, so it is not presented as a reproduced runtime repair.
NanoUI independently closed children detach from the master; closing a master still closes every sibling. The native baseline retained 500 children and the fixed version retained zero. Existing reopening behavior remains covered.

Full production compilation, native real-game callback/train checks, existing
lifecycle/persistence suites and exact-commit CI establish compatibility within
their tested scope. Screenshots are unnecessary when those checks resolve behavior;
this evidence does not establish graphical effects, production OOM remediation,
or multiweek full-server stability.

## Recommendation disposition

The earlier memory diagram identified eight areas. Lifecycle states and deletion
hints, callback release/indexing, turf finalizer cleanup, explicit bounded pools,
and bounded queue/helper/pool telemetry are implemented here. The opt-in lifetime recorder also aligns scalar registry sizes and enqueue/consumed-entry rates with bounded observed awake-interval p95/max and an external OS sampler. It is off by default, retains at most 120 scalar rows and intervals, and neither scans the world nor samples entity references. See [the telemetry suite](../memory_telemetry/README.md) for its native controls and isolated full-game trace. Ownership review
also repairs weak handles, dynamic callbacks, reagent backlinks, completed process
snapshots, independently closed NanoUI children and stale pooled-effect routines.
Native fixtures compare historical behavior or intentionally broken controls.

The queue-cursor candidate was measured and rejected; adaptive deletion budgets
remain unchanged because the fixture provides no production tick-pressure case
for increasing them. Existing registry, decal, seasonal debris and corpse/bones
lifetime changes are retained and covered by their own suites. Player assets are
not newly opted into expiry. OS memory samples and native timings accompany the
isolated benchmark; no production soak, tick-p95 improvement or OOM claim follows.
## Bounded collector mixed workloads

`--case collector` constructs 30 native hard-delete targets and 340 ordinary
queued atoms, releases the ordinary owners, and verifies native collection.
Queue ages are accelerated in the fixture; production still waits 30 seconds.
Across twenty completed mixed cycles, one pass consumes 300 entries (30 forced deletes and 270 already-collected
records), leaving 70. Restoring the original early hard-budget stop with
`--negative-control gc-soft-budget` consumes 30 and leaves 340. This is ten
times as many consumed records in this bounded workload, not a CPU or RSS claim.
`--negative-control gc-hard-budget` verifies that the 31st live target must wait.
Timeout, identity reuse, strong-owner release and subsequent-pass checks remain.
Both the 300-candidate and 30-forced-deletion caps are unchanged. No head cursor,
adaptive budget, earlier target lookup or different item lifetime is introduced.
