# Native season transition fixture

`run.py` extracts actual base season procedures, lifecycle/ownership guards, the
Asia flood hook and production area helper. Inert adapters isolate climate areas,
native turf replacement, trees, sinks and snow structures. Generated source uses
deterministic probability decisions and accelerated delayed effects. No production
startup, saves, hooks or listening ports are enabled; the fixture closes the initial
port with `OpenPort("none")` and rejects attempts to reopen it.

The comparator accepts either positional evidence paths or `--baseline` and
`--candidate` paths, as used by CI.

Use a verified full Python interpreter path (never bare `python` on Windows).
Preparation launches neither compiler nor daemon:

```
<PYTHON> tests/season_transition/run.py --prepare-only <fresh-directory>
```

After native launches are authorized, run equal-workload parity pairs, separate
adversarial request scenarios, and both required negative controls:

```
<PYTHON> tests/season_transition/run.py --byond-bin <516.1681-bin> --mode baseline --output <fresh-baseline.json>
<PYTHON> tests/season_transition/run.py --byond-bin <516.1681-bin> --mode candidate --output <fresh-candidate.json>
<PYTHON> tests/season_transition/compare.py <baseline.json> <candidate.json> --max-gap-ds 10
<PYTHON> tests/season_transition/run.py --byond-bin <516.1681-bin> --requests --output <fresh-requests.json>
<PYTHON> tests/season_transition/run.py --byond-bin <516.1681-bin> --negative-control yield --output <fresh-yield.json>
<PYTHON> tests/season_transition/run.py --byond-bin <516.1681-bin> --negative-control clock --output <fresh-clock.json>
<PYTHON> tests/season_transition/run.py --byond-bin <516.1681-bin> --mode baseline --size largest --output <fresh-largest-baseline.json>
<PYTHON> tests/season_transition/run.py --byond-bin <516.1681-bin> --mode candidate --size largest --output <fresh-largest-candidate.json>
<PYTHON> tests/season_transition/compare.py <largest-baseline.json> <largest-candidate.json> --max-gap-ds 10
```

Largest geometry is 660 x 550 x 1 (363,000 turfs), with 20,000 inert objects and
80 inert mobs. Four sequential natural seasons compare against immutable baseline
`e3c8d02f31f1a23c1320eaec949fb4af56e964f3`. The executable comparator rejects
final ordered per-season terrain hashes, RNG threshold order/count, weather/tree/
announcement traces or clocks that differ. Small fixtures additionally compare every
ordered terrain replacement (coordinates and old/new type), icon update and probability
decision (threshold, result and current candidate identity). Small baseline/candidate
sources share candidate tracking for full trace fidelity. Largest parity sources
omit tracking because their operation trace is disabled; request scenarios retain it
for replacement checks. Largest fixtures disable this trace
to keep its memory/CPU cost out of the performance comparison. It also checks the explicit synthetic one-second heartbeat ceiling. Cheap transitions
may finish without a positive pause; ordinary parity uses actual tick usage and reports
its observed positive/zero pauses and completion times.
That ceiling is a fixture acceptance bound, not a production server SLO.

Parity pairs use generated phase waits of `30 + original / 10` deciseconds,
with identical scaling on both sizes and modes. Separate request runs use divisor 100 to shorten dormant waits and do not establish
ordered phase parity. Negative controls retain divisor 10. Recurring timers use a distinct 210-decisecond adapter. Each result
records these adapters and the 900-second daemon deadline. The comparator keeps
strict callback order checks; it must reject an acceleration-induced mismatch.

Every parity snapshot waits for its owner's pending delayed callbacks, queued phases
and active worker to drain under a bounded deadline, including nested baseline spawns.
Telemetry reports immediate-work and all-phase native completion ticks, wall-clock heartbeat gaps with midnight
wrap, actual peak helper snapshot slots, child process CPU, and OS peak working set
(Windows) or sampled RSS/high-water (Linux). CPU/wall/memory ratios compare only equal unforced four-cycle workloads. OS metrics
cover the whole child and include the candidate-only post-parity witness/drain (up to
two ticks); this small overhead is explicitly labeled. Request runs are excluded
from benchmark comparisons. Parity sources omit request checkpoint and after-pause replacement callbacks.
Largest parity sources also omit per-candidate tracking assignments; small sources
retain shared baseline/candidate tracking for strict RNG candidate identity traces. Shared
operation/RNG logging, timer/pending instrumentation and helper allocation sampling
remain; ratios describe these instrumented comparable paths. Missing CPU/memory
samples fail comparison. Heartbeat
readiness and a pre-cycle tick establish the timestamp before each measured window. Additional request scenarios run separately via
`--requests`. Generated source and build/runtime logs accompany results; manifests
identify original/generated sources, HEAD and tracked patch. Metrics describe this
synthetic fixture and cannot establish full-server performance or memory improvements.

Adversarial requests cover preservation of concurrent natural requests, latest
pending forced decay flags, config-disabled/default/explicit admin decay flags,
looping FALSE, exact original 18000 timer delay and accelerated timer recurrence,
map replacement and Destroy cancellation. Actual Nomads and Continental constructors
share the guarded bootstrap timer, including additional looping requests. Forced requests trigger deterministically
at production discovery, mutation and delayed-callback checkpoints. A turf replaced
after its real mutation pause must retain its unrelated subtype. The actual extracted
Asia hook checks both wet/dry flood transitions at z=1 with enabled and disabled
natural seasons, preserving disabled-mode season and decay clocks. After parity snapshots/counts, every candidate mode runs a dedicated scheduler
budget scenario: a labeled adapter forces 20% tick usage, holds the worker lock, and
schedules a next-tick service witness before calling the actual production pause.
Normal/clock runs must advance time and service that witness while locked. The yield
control changes the generated positive wait to zero and must specifically fail both
progress and timed service. Request scenarios additionally force the budget branch at existing 4096-discovery/
256-mutation batch checkpoints for their duration, making concurrent callers and
after-pause replacement deterministic without adding per-candidate full-tick waits. The clock control removes committed decay advancement and
must be detected specifically. Neither compiler/runtime failures nor unrelated
assertion failures count as successful negative-control evidence.

Request runs also compare ordered native references from category-specific turf and
object discovery against the generic atom scan for every production target type.
They include nested objects, retired/deleted objects, native turf replacement,
generic fallback types and cancellation after partial discovery.

Current verification is Python AST, baseline/current source extraction and generated
checkpoint/control transformation checks only. Native compilation, runtime parity,
negative-control detection, adversarial scenarios, telemetry and the accepted gap
bound have not been executed locally. This harness uses inert weather/tree/crop
side-effect adapters and does not establish client movement, graphical rendering,
map-wide gameplay acceptance, live server behavior or production deployment.

## Full-source largest-map constructor benchmark

`full_game.py` generates a complete production DME with the actual
`maps/nomads/nomads_persistence_beta.dmm` (660x550x1). It retains native terrain
New/Del/ChangeTurf, icon/registry callbacks and ordinary pregame scheduler setup.
It constructs 20,000 retained real `/obj/item` instances (plus one handled test
item) and 80 production human subtypes on 180 bounded plating staging cells,
which inherit constructors and Life. Only their disconnected-client sleeping
check is adapted. Twenty initial native movement and hand pickup/drop cycles plus twenty concurrent
cycles during each of four transitions, final
item/human identities and locations, per-human Life calls/gaps, grass/water
registry indices/current-turf membership, and four actual seasonal transitions
must pass. Each synchronized finite movement callback must complete and record
at least one successful operation with the season worker busy before and after
the native actions. Every human must advance Life in each transition. Dead
humans fail the initial and every subsequent population check; production cold
damage is not masked by invulnerability.
These are headless humans, not connected players.

```
<PYTHON> tests/season_transition/full_game.py --prepare-only
<PYTHON> tests/season_transition/full_game.py --prepare-only --negative-control
<PYTHON> tests/season_transition/full_game.py --byond-bin <516.1681-bin> --output <fresh-evidence-directory>
<PYTHON> tests/season_transition/full_game.py --byond-bin <516.1681-bin> --negative-control --output <fresh-control-directory>
```

Preparation performs source transformations and hashes without starting BYOND.
Native execution compiles with zero errors/warnings and uses fresh temporary
storage, public tracked configuration, disabled webhook/ToRban/persistence-save
adapters, a closed port which cannot reopen, and no clients. The pregame lobby
is held: roundstart nature/map generation, food bootstrap and full round behavior
are outside this benchmark. Unexpected reboots and runtime/engine diagnostics
invalidate evidence. The launcher scans at most 64 KiB per poll from the startup
log and a fixed runtime-error marker (which also covers redirected world logs),
retaining only a 1 KiB overlap. Native diagnostics terminate the owned child
without waiting for the startup deadline. Deliberate population-control FAIL
markers are evaluated separately and are not treated as runtime diagnostics.
BYOND engine account/hub activity before DM startup is not
OS-level network isolation.

The pinned safe-mode Beta run rejected its production `world.loop_checks = FALSE`
assignment before setup. The generated `code/world.dm` omits only that exact
Beta conditional assignment and retains native long-loop protection. Replacing
the generated adapter comment with the original block must reproduce the entire
original source byte-for-byte after newline normalization. Original/generated
world sources are retained, and the result must report `native_loop_checks = 1`.
This is an explicit execution-context difference from production Beta. Engine
long-loop aborts still invalidate the run; the harness does not suppress them or
prove behavior with production loop protection disabled.

Only seasonal delayed-start waits are accelerated to `30 + delay / 100`
deciseconds; original numeric delays are recorded. This synthetic schedule
preserves relative delay lengths and allows concurrent service time. Because
main terrain work keeps its real duration and phases arm at different points,
callback firing order can differ from ordinary seasonal timing. This benchmark
establishes constructor and concurrent service coverage, not production delayed
phase order. Terrain constructors, callbacks, worker pauses and
human Life are unchanged. A generated pending-callback count includes nested
callbacks and queued phases; each cycle waits for complete quiescence. Source
restoration checks constrain the generated worker changes to this timing
instrumentation. Setup readiness is marked at the actual end of
`setup_everything()`, rather than inferred from scheduler creation.

Evidence separates setup/startup, population construction, immediate seasonal
work, all delayed phases and recovery. Own-child CPU/RSS or Windows working-set
samples are taken every 0.1 seconds and native heartbeat gaps are retained;
phase boundary uncertainty includes a poll plus file/write/scheduling delay.
Each phase reports its maximum sampled current RSS separately from the process
lifetime working-set/VmHWM high-water mark. The latter may belong to an earlier
phase and must not be interpreted as that phase's allocation peak.
Generated/original sources, full include hashes including the DMM, exact HEAD,
tracked patch, compiler/runtime logs and result receipts are retained. CPU,
completion time and retained registry entries do not establish long-term OOM
remediation or a gameplay latency SLO.

Limits are 300 seconds for native setup, 900 seconds for the entire daemon,
2 GiB process lifetime memory high-water cap and 12,000 heartbeat rows. Compilation has a separate
300-second limit. A timeout preserves observations and fails; these bounds are
not measured completion promises. The negative control removes one entry from
the generated item ownership list and must fail specifically on population
conservation; compilation/runtime failures do not count as control detection.

Current verification: source-only preparation of positive/negative variants.
Native compilation, runtime invariants and performance have not been executed
locally. Cloud execution requires independent code review and exact-head CI.
