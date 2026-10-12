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
decision (threshold, result and current candidate). Largest fixtures disable this trace
to keep its memory/CPU cost out of the performance comparison. It also checks positive explicit pauses,
multiple elapsed ticks, and the explicit synthetic one-second heartbeat ceiling.
That ceiling is a fixture acceptance bound, not a production server SLO.

Every parity snapshot waits for its owner's pending delayed callbacks, queued phases
and active worker to drain under a bounded deadline, including nested baseline spawns.
Telemetry reports immediate-work and all-phase native completion ticks, wall-clock heartbeat gaps with midnight
wrap, actual peak helper snapshot slots, child process CPU, and OS peak working set
(Windows) or sampled RSS/high-water (Linux). CPU/wall/memory ratios compare only
identical four-cycle workloads. Missing CPU/memory samples fail comparison. Heartbeat
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
natural seasons, preserving disabled-mode season and decay clocks. Positive pause calls are
observed in generated source; the yield control changes their delay to zero and must
be detected specifically. The clock control removes committed decay advancement and
must be detected specifically. Neither compiler/runtime failures nor unrelated
assertion failures count as successful negative-control evidence.

Current verification is Python AST, baseline/current source extraction and generated
checkpoint/control transformation checks only. Native compilation, runtime parity,
negative-control detection, adversarial scenarios, telemetry and the accepted gap
bound have not been executed locally. This harness uses inert weather/tree/crop
side-effect adapters and does not establish client movement, graphical rendering,
map-wide gameplay acceptance, live server behavior or production deployment.
