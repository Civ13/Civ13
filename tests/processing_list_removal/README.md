# Copied processing-list removal

Run with BYOND 516.1681 in temporary storage:

```powershell
& '<verified-python>' tests/processing_list_removal/run.py --byond-bin '<516.1681-bin>'
& '<verified-python>' tests/processing_list_removal/run.py --byond-bin '<516.1681-bin>' --baseline
& '<verified-python>' tests/processing_list_removal/run.py --byond-bin '<516.1681-bin>' --negative-control
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
The unsafe control unconditionally cuts the front; it must fail the skipped-head
and already-removed-current assertions. Existing snapshot ownership tests cover
release on completion versus retention on budget yield.

The production macro cuts the front only when its value equals `current`,
otherwise retaining native value subtraction. It consumes the entry at the same
point in the existing forward loop, before the unchanged tick-budget check.
`Cut(1,2)` still shifts the remainder, so this is not a linear-time queue design.
No persistent cursor or stale prefix is introduced.

## Benchmark scope

The opt-in benchmark compares the production macro against historical subtraction
using identical process-field iteration and an increment-only body. Five paired
groups alternate execution order at 1,000, 5,000 and 10,000 datums, with 20 passes
per group. Copies are prepared outside the timed region. Timing uses native
`world.timeofday` deciseconds; it is wall time at engine clock resolution, not
CPU profiling. Sleeps between passes are excluded. Raw samples, source/probe
hashes, head and dirty patch are retained with `--evidence-dir`.

Batch, cursor, end-pop and reversed-copy pop are also measured, including reversal
cost for the latter. They are algorithm comparisons, not adopted production
implementations or claims of callback equivalence. Batching defers removal;
cursors change pending-list length/contents; end-pop reverses the current order;
reversed-copy pop changes the observable snapshot order. Those changes require
separate contracts beyond this narrow removal optimization.

CI selects the new semantics suite on the introducing PR, or when extensive
regressions are explicitly enabled. It does not run throughput measurements or
the broad existing game suites automatically.

Public design references, read at the requested immutable commits:

- [CM processing](https://github.com/cmss13-devs/cmss13/blob/85161b1096019c1daf4f756b0c0b216a80da683f/code/controllers/subsystem/processing/processing.dm): end-pop before processing.
- [Baystation processing](https://github.com/Baystation12/Baystation12/blob/ca90ce8b501c4e04f24c1510990fc6f86623d4f1/code/controllers/subsystems/processing/processing.dm): forward indices with a prefix cut on yield.

The Civ13 change is independently implemented against its own process contracts;
no reference subsystem or process API is imported.
