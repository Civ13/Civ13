# Copied processing-list removal

Run with BYOND 516.1681 in temporary storage:

```powershell
& '<verified-python>' tests/processing_list_removal/run.py --byond-bin '<516.1681-bin>'
& '<verified-python>' tests/processing_list_removal/run.py --byond-bin '<516.1681-bin>' --baseline
& '<verified-python>' tests/processing_list_removal/run.py --byond-bin '<516.1681-bin>' --negative-control
& '<verified-python>' tests/processing_list_removal/run.py --byond-bin '<516.1681-bin>' --guarded-control
& '<verified-python>' tests/processing_list_removal/run.py --byond-bin '<516.1681-bin>' --remove-candidate
& '<verified-python>' tests/processing_list_removal/run.py --byond-bin '<516.1681-bin>' --benchmark --evidence-dir '<fresh-directory>'
```

The fixture compiles the selected checkout's actual `PROCESS_LIST_CHECK`,
`PROCESS_USE_FASTEST_LIST`, `PROCESS_TICK_CHECK`, object `fire` and snapshot reset.
It substitutes an isolated registry, callbacks and diagnostic adapters, closes
the runtime port and refuses reopening. No game startup, external service or
production save is involved. The historical mode pins the same source paths to
`aa675de6dbade0f3740c516dc4b5945c5c9a43c7`.

Assertions cover forward order, budget continuation, duplicates, nulls, native
self/peer deletion, additions/removals in the live registry, PROCESS_KILL,
exceptions, recursive fire, skipped heads, already removed current entries,
associated keys and the VERY_HIGH alias exception. Recursive fire intentionally
preserves the existing callback behavior: reentering before the current callback
returns can execute that callback again. This change does not add a reentry lock.
The unsafe control cuts a nonempty front regardless of its value; it must fail
the skipped-head and already-removed-current assertions (17 expected failures).
The guarded front-cut control fails exactly two duplicate/null equivalence checks.
The explicit `Remove()` candidate must pass all 56 assertions, like the baseline.
Existing snapshot ownership tests cover
release on completion versus retention on budget yield.

No production change was adopted. Native `-=` and `Remove(current)` remove the
last matching occurrence; `Cut(1,2)` removes the first. For example, removing
`a` from `[a,b,a]` leaves `[a,b]` under subtraction, but `[b,a]` under a front
cut. Repeated null entries have the same distinction. A head equality guard
does not preserve that contract. `Cut(1,2)` also still shifts the remainder.

## Benchmark scope

The opt-in benchmark compares explicit `Remove()` against historical subtraction
using identical process-field iteration and an increment-only body. Five paired
groups alternate execution order at 1,000, 5,000 and 10,000 datums, with 20 passes
per group. Copies are prepared outside the timed region. Timing uses native
`world.timeofday` deciseconds; it is wall time at engine clock resolution, not
CPU profiling. Sleeps between passes are excluded. Raw samples, source/probe
hashes, head and dirty patch are retained with `--evidence-dir`.

The actual production macro, guarded head-cut, head-while, batch, cursor, end-pop
and reversed-copy pop are also measured, including reversal
cost for the latter. They are algorithm comparisons, not adopted production
implementations or claims of callback equivalence. Batching defers removal;
cursors change pending-list length/contents; end-pop reverses the current order;
reversed-copy pop changes the observable snapshot order. Those changes require
separate contracts beyond this narrow removal optimization.

CI selects the new semantics suite on the introducing PR, or when extensive
regressions are explicitly enabled. It does not run throughput measurements or
the broad existing game suites automatically. Counters require every benchmark
to visit all entries and leave an empty queue; an incomplete pass is never a
performance success. Sleep until a normal tick before testing tick budgets;
`world.tick_usage` during `world.New()` is not an admitted processing-run budget.

Public design references, read at the requested immutable commits:

- [CM processing](https://github.com/cmss13-devs/cmss13/blob/85161b1096019c1daf4f756b0c0b216a80da683f/code/controllers/subsystem/processing/processing.dm): end-pop before processing.
- [Baystation processing](https://github.com/Baystation12/Baystation12/blob/ca90ce8b501c4e04f24c1510990fc6f86623d4f1/code/controllers/subsystems/processing/processing.dm): forward indices with a prefix cut on yield.

The Civ13 change is independently implemented against its own process contracts;
no reference subsystem or process API is imported.

## Recorded result, 2026-10-12

Windows, native BYOND 516.1681, five alternating paired groups. Values are
median deciseconds for 20 complete passes; 10,000 entries means 200,000 visits
per group. The explicit `Remove()` candidate was in the experimental production
macro for this trial, with its source/dirty-patch hashes retained. It was then
rejected. The committed benchmark now selects `remove-call` explicitly so the
comparison remains reproducible while the production macro stays unchanged.
See `benchmark-results.json` for all paired samples and provenance hashes.

| Entries per pass | Native subtraction | Explicit Remove | Remove result |
| --- | ---: | ---: | --- |
| 1,000 | 0.28125 | 0.28125 | tied |
| 5,000 | 5.93750 | 6.21875 | 4.7% slower |
| 10,000 | 18.65620 | 19.12500 | 2.5% slower |

At 10,000 entries the single alternative samples were 12.9062 ds for guarded
front-cut, 13.2188 ds for head-while, 0.28125 ds for batch, 0.40625 ds for cursor,
0.21875 ds for end-pop and 0.50000 ds for reversed-copy pop. All visited 200,000
entries and left empty queues. These faster results do not establish callback
equivalence: the guarded cut is disproved by the duplicate/null control, while
the remaining designs alter pending-list contents, order or removal timing.

The tested equivalent removal method did not improve throughput. The faster
designs require a broader contract change, so the production loop is preserved.
No whole-game latency, memory, OOM or live-server performance claim is made.
