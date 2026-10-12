# Bounded GC triage regression

`run.py` reuses the isolated native production GC fixture and launcher under
`tests/memory_ownership`. Its `triage` case runs only these checks, with temporary
storage and a closed/refused port. Use pinned BYOND 516.1681 and a verified full
Python interpreter path on Windows.

The fixture tests ordinary queue retention/failure, requested and immediate
hard deletion, native disappearance, stale identity, direct finalization,
self-deleting cleanup, pool retirement, unchecked handoff and controlled Del
exceptions. It also saturates metadata and profiling limits and inspects one
owner field through cyclic/nested lists under fixed traversal limits.

Mutation controls change generated temporary source only. The slot/list cap,
timestamp and metadata controls must fail at their intended assertion. The
launcher rejects compiler warnings, runtime errors and engine diagnostics.

Counts, caps and physical deletion observations are not claims about production
CPU cost, RSS savings, OOM remediation or whole-game behavior. No screenshots
are needed for scalar diagnostics established by these controlled runtime cases.
