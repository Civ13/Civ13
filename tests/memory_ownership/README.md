# Memory ownership and GC verification

PR #3087 is work in progress. Production sources are unchanged. The standalone
`scheduler_candidate.dm` is test-only and is not included by `civ13.dme`.

Run with a trusted BYOND 516.1681 bin directory:

```
<verified-python> tests/memory_ownership/run.py --byond-bin <bin> --case callback --scheduler-candidate
<verified-python> tests/memory_ownership/run.py --byond-bin <bin> --case benchmark
<verified-python> tests/memory_ownership/run.py --byond-bin <bin> --case benchmark --scheduler-candidate
<verified-python> tests/memory_ownership/run.py --byond-bin <bin> --case memory
```

Omit `--scheduler-candidate` to execute the current production scheduler. The
runner compiles production GC/pool bodies with isolated adapters, temporary
storage, and no normal game startup. Fresh evidence folders contain the tested
commit, dirty diff, compiler/runtime logs, native result and optional OS memory
sample. Candidate selection is recorded in metadata. Memory samples are Windows
private bytes and RSS at fixture completion, not a sustained server profile.

## Current evidence

The candidate passed 14,010 callback assertions on native BYOND 516.1681,
including ordered due calls, future calls, limited cancellation, 7,000 cancellation
cycles, 5,001 concurrent callbacks, reentry and throwing callbacks. The production
baseline fails the zero-cancellation-limit assertion; earlier reproductions also
caught uncleared helper fields and mismatched deletion/pool contracts.

Three 150,000-cycle schedule/execute benchmarks measured baseline times of
2.000, 1.93047 and 2.06094 seconds; candidate times were 0.810938, 0.802344 and
0.928125 seconds. These bounded synthetic results do not establish game latency.

The cancellation inspection deliberately retains helpers to inspect their
fields. Its 4,000 versus zero uncleared helpers proves reference clearing when
helpers remain reachable, not an actual leak. The separate invalid-helper
experiment retained zero argument slots on both baseline and candidate: native
collection can reclaim an unreachable helper. One OS memory sample per variant
is insufficient to establish lower server memory usage.

The turf case passes on the baseline. Do not describe removal of the source line
after native `del(src)` as a reproduced runtime fix. Lifecycle and pool cases are
currently reproductions and fail until production fixes are implemented.

No production OOM remediation, multiweek stability, full-game callback safety,
exact-commit CI acceptance, or graphical acceptance is claimed.
