# Wolf cave timer ownership

The dedicated Windows executor is now implemented for source/offline review;
see [EXECUTOR.md](EXECUTOR.md). It has no native CLI entry point and has not been
invoked against real compiler/daemon processes. Existing preparation hashes and
native-unrun status below remain unchanged.

Related to #3267; pinned audited base:
`9db2b2f42a5fbbb0bdd49d50a2672da6111a7709`.

Each wolf cave now claims one self-processing `Tick()` chain synchronously before
spawning it. A duplicate start returns; each iteration refreshes that cave's
population, calls its existing `Ticker()`, then sleeps 50 deciseconds. A newly
constructed cave gets its own initial service and subsequent five-second cadence.
This is a per-cave cadence, not a shared wall-clock phase or a real-time deadline
when the server is overloaded. No cave owns a global scanner or another cave's
progress. `Destroy()` clears the claim; native deletion and both GC flags prevent
subsequent service. A replacement is a new owner. A retired sleeping invocation
can remain until its next wake, at most one nominal five-second wait.

`ticking` is excluded through the existing custom-save hook on export and import,
including legacy flags. Constructors rebuild runtime ownership. This does not
change the existing durable population/cooldown policy or attempt to reconstruct
other pre-existing sleeping cooldown callbacks during restore.

## Deliberate frequency correction

Previously C ordinary caves created C scanner chains, each visiting C caves:
C squared callbacks per nominal five-second cycle. If any `/full` cave existed,
its globally guarded extra chain made C+1 scanners, or C(C+1) callbacks. Thus
1/3/10 ordinary caves produced approximately 1/9/100 callbacks, and all-full
populations produced 2/12/110. The corrected totals are 1/3/10 in either case.
Construction-time phase differences and retirement can change historical counts.

This changes effective RNG consumption and gameplay frequency. Eligible wanderer
rolls (`prob(18)`) and description/flavor rolls now occur once per cave per cycle,
rather than once per scanner. With K independent eligible wanderer attempts and
no intervening blocker, the old chance of at least one success was
`1 - 0.82^K`; the corrected single-cycle chance is 18%. A successful wanderer still
uses the unchanged 18,000-decisecond cooldown. Reproduction admission itself is
not random: the unchanged procedure creates one cub when eligible, then gates
pregnancy for 27,000 deciseconds. Growth still waits 4,500 deciseconds and uses
the same 50% sex roll. Fewer callbacks can delay admission until the next owned
cycle and remove repeated stale population observations within a cycle. This is
a scheduler correctness fix, not behavior-identical optimization or a measured
production speedup.

`/full/New()` still assigns 5/5 and calls the parent's randomizing 1..3/1..3
constructor; that historical overwrite is deliberately unchanged. Only its extra
timer start is removed. Bear caves and all unrelated processors are out of scope.

## Offline checks

Run with a verified Python executable (use its full path on Windows):

```text
<python> -B -m unittest discover -s tests/wolf_cave_ownership -p test_*.py -v
<python> -B tests/wolf_cave_ownership/prepare.py --output <fresh-temporary-directory>
```

The source checks enforce ownership, recount ordering, five-second wait, retirement
and custom-save exclusions, and compare six unchanged gameplay procedure hashes
with the audited base. Generated-source negative controls independently restore a
world scan, remove the duplicate-start guard, remove the stop, omit the save hook,
and omit the recount. The historical source is loaded directly from the pinned
Git object. These checks do not compile or execute DM.

Preparation writes resource-free DME fixtures, exact input/output SHA-256 hashes,
and `compiler_executed=false` / `native_executed=false`. Its only subprocess calls
are bounded Git object/ref reads; it has no native launcher. It refuses to replace
an existing output directory. Commit/head and source hashes together identify a
dirty candidate; preparation alone is not exact-commit runtime acceptance.

## Native controls prepared for parent review; NOT RUN

The generated fixture extracts the actual cave constructors, Tick, Destroy,
persistence hook, Ticker, reproduction, climate and wolf emission procedures.
Adapters replace the parent environment, area lookup and wolf mobs;
there is no normal game startup, map import, serializer, AI, client or external
service. Only cadence (`sleep(50)` to `sleep(2)`), cub wait (4,500 to 6) and RNG
delivery are adapted. Test-only subtype cooldown holders are 6; production holder
defaults remain unchanged in the extracted parent declaration. `prob(18)` is
controlled, other probability branches return false; native `pick` stays native.
Ticker entries and population consistency are counted before the original body.

The fixed case checks 1/3/10 ordinary and full caves, repeated Tick starts,
removal of the first cave while asleep, survivor progress, same-location
replacement, late creation, removing all caves, direct Destroy, native deletion,
legacy saved-flag admission, population recount and a single wanderer/cooldown.
The save test checks the real cave hook through an import adapter, not a disk save
round trip. Six negative cases share the fixed oracle. Expected first failures:

| Case | Expected result once native execution is authorized |
| --- | --- |
| fixed | `PASS wolf cave ownership`, no FAIL/runtime diagnostics |
| world-scan | multiple initial callbacks for the three-cave batch |
| duplicate-start | `one chain` after repeated starts |
| missing-stop | `Destroy stops sleeper` |
| saved-flag | `timer excluded from custom save` |
| missing-recount | `population recount` after counters change |
| baseline | duplicate initial/recurring callbacks (full single cave already duplicates) |

All cases are **uncompiled and unexecuted**. Source-control rejection is separate
from native negative-control detection. Check native mutation collateral and
record actual first failures before claiming targeted causal evidence.

Proposed admission bounds for the parent to review against resource availability:

- BYOND **516.1681**, trusted daemon only after explicit parent approval.
- Sequential runs, one compiler/daemon at a time; seven cases, no full game/client.
- Synthetic **12 x 12 x 1** world (144 cells), at most 10 live batch caves plus
  one replacement and one late cave; at most one emitted inert wolf.
- Fixture watchdog 150 deciseconds. External wall cap proposed at 20 seconds per
  runtime case and a 256 MiB process/job memory cap. Compilation needs its own
  reviewed wall/memory limit and exact executable/version check.
- Native port closes with `OpenPort("none")`, reopen requests return false, and
  clients are rejected. Require an external zero-listener census; adapters alone
  do not prove no transient startup bind or network isolation.
- Use new temporary storage, sanitized bounded logs, an owned process/job with
  descendant cleanup and exit confirmation, and reviewed external-effect/network
  containment. Never attach to or stop an existing BYOND process.
- Require compiler zero errors/warnings; runtime exit, PASS receipt, no FAIL or
  engine diagnostics, closed listener observations, and no surviving owned process.
  Keep failed and negative receipts. Do not infer gameplay, latency or RAM savings.

There is intentionally no execution/launch command in this packet. Parent review
must select/approve the existing containment runner and actual resource caps
before compiling or launching these native controls. Full-game and connected-client
evidence remain separate, held acceptance work. OpenDream remains paused; $0 budget.
