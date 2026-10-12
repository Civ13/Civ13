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
150,000-cycle schedule/execute measurements were 0.900, 1.025 and 1.06094 seconds;
the immutable baseline was 2.000, 1.950 and 1.98125 seconds. Median elapsed time fell 48%.
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

The head-cursor queue experiment in tests/gc_queue_benchmark was rejected: it had
no consistent speed benefit and accumulated stale entries under reference reuse.
Adaptive budgets remain profile-gated; increasing deletion work without measured
server tick pressure would add risk. See that suite's recorded comparisons.

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
and bounded queue/helper/pool telemetry are implemented here. Ownership review
also repairs weak handles, dynamic callbacks, reagent backlinks, completed process
snapshots, independently closed NanoUI children and stale pooled-effect routines.
Native fixtures compare historical behavior or intentionally broken controls.

The queue-cursor candidate was measured and rejected; adaptive deletion budgets
remain unchanged because the fixture provides no production tick-pressure case
for increasing them. Existing registry, decal, seasonal debris and corpse/bones
lifetime changes are retained and covered by their own suites. Player assets are
not newly opted into expiry. OS memory samples and native timings accompany the
isolated benchmark; no production soak, tick-p95 improvement or OOM claim follows.