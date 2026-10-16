# Persistence exclusion dispatch

Candidate: replace the atom, turf and mob runtime-exclusion temporary name lists
with exact switch cases. Unmatched keys still call the parent once; matched keys
return without calling it. No cache, partial parsing, saved-variable selection,
saver/loader, or persistent fields change. Baseline is pinned to
`41e2d02fe1f9130e0987aee0efd2eba0ca7b3bf1`.

The runner fails closed on source drift. It imports production hooks, representative
movable/item/human inherited hooks, full get_saved_vars bodies and the dirt override.
Minimal type declarations replace constructors and startup. Native key comparisons
include all excluded strings, case variants, unknown/empty strings, null, numbers,
paths, lists and datums. Separately instrumented root hooks compare parent calls and
mutation side effects. Full selection checks compare ordered keys, associations,
sampled values, per-instance allowlist changes and returned-list isolation.

Run with a verified interpreter and BYOND 516.1681:

```powershell
& '<python>' tests/exclusion_dispatch/run.py --byond-bin '<bin>' --output '<fresh.json>'
& '<python>' tests/exclusion_dispatch/run.py --byond-bin '<bin>' --negative-control omit --output '<fresh-omit.json>'
& '<python>' tests/exclusion_dispatch/run.py --byond-bin '<bin>' --negative-control parent --output '<fresh-parent.json>'
& '<python>' tests/exclusion_dispatch/run.py --byond-bin '<bin>' --negative-control eager --output '<fresh-eager.json>'
```

Controls only mutate generated source: omit appearance, suppress parent fallback,
or call the parent eagerly. They must be detected. Temporary compiled output is
removed; source/probe hashes, exact head, dirty patch and full logs are retained.
This is a 4x4x1 isolated world without normal game startup. It closes its port and
rejects reopening, but Windows may briefly listen during native startup.

Optional `--benchmark --calls 10000` compares complete uninstrumented selection
calls for item, mob and human, 200 warmups per variant, five alternating pairs per
type. Each sample has the same complete call count. Native elapsed deciseconds
exclude inter-sample sleeps. If resolution is inadequate, report that limitation;
do not infer equality or improvement. Larger 20000/40000 workloads require a fresh
explicit resource plan/lease. No native run has yet been authorized or performed.
No verified opcode, production CPU, server latency, disk-save or client claim.
