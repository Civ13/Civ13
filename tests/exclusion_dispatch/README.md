# Persistence exclusion dispatch

Candidate: replace the atom, turf and mob runtime-exclusion temporary name lists
with exact switch cases. Unmatched keys still call the parent once; matched keys
return without calling it. No cache, partial parsing, saved-variable selection,
saver/loader, or persistent fields change. Baseline is pinned to
`75890d883190355e430f9958fd102864ee88429a`.

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
explicit resource plan/lease. This successor has not been compiled or run natively.
No verified opcode, production CPU, server latency, disk-save or client claim.

Native execution currently fails closed before launching any process while the
corrected frozen packet awaits core review. An unconditional native hold precedes all lease handling; no flag or old receipt bypasses it.
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
All five invocations use the same issued/expires UTC and system-monotonic receipt
with at most 90 seconds between issued/deadline timestamps. Each process monitor
uses that exact shared monotonic deadline, including a check before Popen and
final accounting, so later commands cannot reset the budget. Frozen packets also
contain trusted executable paths, SHA-256 hashes, static file version resources
and exact compiler/daemon arguments. Both binaries are checked again immediately
before launch and must match the lease; compiler and daemon banners are required.
The probe retains pre-close address/port, close return value, closed port, reopen
rejection and final closed port, failing with a diagnostic if they differ.

## First native attempt

The authorized one-shot sequence at `e1b4521710e4e36308c5df676a57bd5a3b0a345c`
started 2026-10-16 22:03:07 UTC. Compilation passed with zero errors and warnings.
The monitor stopped the first parity run after detecting an engine diagnostic;
the sequence ended after 1.141 seconds. No completed parity result, controls or
timing samples were obtained. The owned compiler/daemon were reaped; no unexpected
listener was sampled, which is not positive loopback-bind evidence. The exact
diagnostic was lost because temporary cleanup preceded the old runner's log copy;
the cause remains unknown. No unchanged retry was made and the slot was released.

Failure-path retention now copies engine/network/result logs in finally before
temporary cleanup. Three fake-process tests check diagnostic retention, pre-spawn
deadline rejection and fast-exit final-query failure cleanup. They pass without
starting BYOND and do not replace native parity or timing. This remains a draft
candidate without a demonstrated performance benefit.

## Current-master conflict resolution

The baseline is master `75890d883190355e430f9958fd102864ee88429a`.
The three switch hooks retain its 3 atom, 8 turf and 22 mob exclusions, including
all nine process-local input/trace fields and the three mining ownership fields. The datum weak-reference exclusion,
restored-lighting calls and all other persistence code remain baseline-identical.
Both variants import the same baseline-checked current inherited helpers.
Parity keys include the nine new mob fields and `weak_reference`. Offline source
controls reject each omitted exclusion, altered parent dispatch, unrelated file
changes and malformed baseline hooks; these are source-contract checks, not DM
execution or native semantic parity.

The original head `97103c8543ca0eff39deeb6e63ff0f6c5a2a7dc2` is retained at
`archive/pr3197-97103c8`. Its evidence remains separate. The `world.address` bind
assertion is deliberately unchanged pending separate review; the prior engine
diagnostic cause remains unknown. All native execution remains held.

Current repository policy records `-trusted`, never `-safe`, in the proposed
native argv. This source-only update grants no trusted execution permission.
Fresh maintainer approval and exact-head review are required before separately
changing the unconditional hold; all old leases/grants are invalid for this head.
Source-only generation launches Git for pinned source reads, never a compiler or
daemon, and records `native_execution: false` and the held authorization state.

## Refreshed source packet (2026-10-19)

The pinned baseline and inherited-helper checks now use master
`75890d883190355e430f9958fd102864ee88429a`. The transformer preserves leading
mining guards verbatim and replaces only the terminal list-membership expression.
The whole-file equality guard still rejects unrelated changes. Offline tests
individually omit all three mining fields and verify their generated parity keys.

The fixture incorporates the two source fixes reported in PR comment
https://github.com/Civ13/Civ13/pull/3197#issuecomment-6240496944:
port closure is checked through the resulting closed state and refused reopen
(the native close return is not required to be 1), and `/atom/movable` replaces
nonconstructible bare `/atom`. The pre-close address assertion is unchanged.
These changes regenerate input hashes; previous packets and leases are invalid.
The report's old Linux run is historical evidence, not a run of this candidate.
The unconditional native hold remains in force, with no flag or receipt bypass.
Native parity, all controls, generated-source compilation and paired benchmarks
remain acceptance blockers for the refreshed candidate.
