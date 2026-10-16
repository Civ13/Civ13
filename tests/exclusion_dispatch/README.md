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

Native execution currently fails closed before launching any process while the
corrected frozen packet awaits core review. No override flag bypasses that gate.
`--source-only --output <fresh.json>` validates source extraction and transformations
without requiring a BYOND installation. CI uses only this mode while native is held.
The prepared Windows monitor samples each owned process every 25 ms, checks 40 CPU
seconds/512 MiB peak working set, per-process wall and 90-second aggregate wall,
checks diagnostics including BUG during execution and after exit, and retains PID,
creation FILETIME, owned IPv4/IPv6 listener observations, final resource status,
exit code, captured output and cleanup
receipts even on failure. A failed final query fails closed. The monitor itself
has not yet been exercised against native BYOND; no monitoring acceptance is claimed.

The revised authorized boundary permits a temporary listener bound only to
127.0.0.1. Frozen runtime argv includes separate `-ip`, `127.0.0.1` values.
The bundled 516.1681 reference documents this address-binding option. The monitor
rejects every observed owned listener with another address or an IPv6 family;
the fixture also closes the port and rejects reopening. Sampling cannot prove
no transient listener between observations; the fixed argv supplies the binding
constraint. Source-only outputs retain generated inputs and hashes including
runner/monitor text. Native mode must match a separately reviewed input receipt.
