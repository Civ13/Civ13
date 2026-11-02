# Isolated memory and tick benchmark

Status: native investigation has run, but **the direct-key optimization is not
accepted until its exact-head correctness and full matrix finish**. Earlier
reference-string-key runs preserved ownership but refused larger staged cohorts.
Run 41122493287 localized those refusals to native `"\ref[L]"` formation, not the
associative lookup. Run 41124431748 passed primitive direct-key registration
comparisons, including aliases, cycles, retained pins and native list handles.
Run 41129116593 additionally passed matrix-key primitive comparisons and
fresh-process list/matrix codec tests. Remaining 2048-root refusals were
attributed to native matrix reference-string formation. Neither primitive
result is final-head acceptance or deployment evidence.

## Current comparison: preflight-only optimization

Run 41132932200 on `51d99a2e` passed 24 correctness and 18 original legacy/candidate
comparisons. Those results remain a separate baseline, not this new experiment.
The candidate packet copies production serializer bytes unchanged. Its paired
baseline uses the same staged saver, optimized main list/matrix codec and all
headroom/safety guards; only the preflight seen-set keys revert to native
reference strings. Both sides now build the moving roster. This is explicitly
`comparison=preflight_only`, not the original legacy baseline.

Both variants use the same source head, fixture, compiler, construction order,
payloads and limits. Receipts pin the two exact preflight substitutions and
baseline-generator hash. Outside-capture roster start/end phase timestamps
measure admission wall time. Counters, phase logging and sampling still impose
some overhead; neither variant is an uninstrumented full-game measurement.
Direct preflight keys retain visited list/matrix handles for the bounded
preflight lifetime; the previous string-key preflight did not pin them. This
prevents recycled-handle false hits but is not a promise of zero memory cost.
Current optimization results remain unverified until its own native run finishes.

The full matrix is nine baseline/candidate pairs: 64/512/2048 animals ×
1/16/64 KiB payloads. Each process performs three successful saves, three injected
failures and one final success. Full prior-backup member hashes and capture-state
cleanup are checked. Record actual admission/fallback: the 64 KiB cohort has
fallen back to legacy saving and is not evidence for staged 64 KiB roots.
The optional four-case diagnostic subset is explicitly non-comparative and is
not used by the acceptance workflow.

## Measurement and limits

- Pinned BYOND 516.1688, disposable Linux directories, one owned process at a time.
- Loopback-only daemon, web client disabled, fixture closes/refuses ports. A
  transient loopback listener was observed; this is not a no-listener guarantee.
- RSS/HWM from `/proc/<pid>/status`, private/PSS from `smaps_rollup`, every 20 ms.
  Independent `time -v` high-water measurement is not currently implemented.
- 1 GiB sampled RSS ceiling plus stricter 1 GiB `RLIMIT_AS`; 90 seconds per compile
  or daemon case, 900 seconds for the whole matrix. A cap refusal is not a pass.
- A missing final sample is accepted only when a zero process exit is conclusively
  reaped and earlier RSS exists; the original race observation and raw row remain.
- The 1 MiB logical capture reservation is **not a BYOND heap limit**. Include
  native staging files, copied values, roster/identity pins and allocator retention
  in process-level comparisons. Counter maxima are not current live allocations.

Correctness additionally writes the real typed codec graph to disk, copies only
that file to a fresh reader process, and verifies aliases, distinct equal/empty
lists, self/mutual cycles, scalar values and empty native-list snapshots. It tests
both current and old-key packets. This is a typed-graph roundtrip, not a fresh
whole-world/player restore. The reference-first world fixture also checks a list
shared by a legacy owner and a chunked animal retains one list ID.

## Remaining acceptance limits

Report failed or truncated cases separately; lower RSS on an aborted case is not
an improvement. Repeated cleanup checks do not establish leak freedom. The
post-operation capture checks cannot preempt a slow native operation or guarantee
a hard maximum stall. Representative full-game latency/memory thresholds and a
fresh whole-world restore remain outside this synthetic result. No merge,
deployment or Gaia operation follows automatically from benchmark success.


## Post-exit capture-budget reporting

Each result now retains `capture_budget_observations` separately from its phase
counters. These observations parse the production exception's printed values
after the child exits; they do not change the measured capture, guard, case
schedule or pass/fail expression. Each observation identifies its configuration,
case folder and preceding validated attempt in the same log stream. Missing,
malformed or mismatched phase context leaves the attempt unknown. Duplicate log
streams remain separate labelled observations; their count is not a failure count.

`exception_metrics.usage_delta` is the failing chunk's reported breach value.
`reported_values` and `raw_exception` preserve the printed precision. The
`cumulative_counter_snapshot` is the latest emitted process-wide phase snapshot,
which can predate a later root's failure; it is not that chunk's final peak.
Incomplete, duplicate or nonfinite metric tokens remain visible as invalid
diagnostics and cannot make the original failed verdict pass.

The frozen synthetic log excerpt in `fixtures/capture-budget-e042.txt` comes
from run41443261135, heade0429b81e, candidate64roots/1024bytes/baseline0,
attempt7: exception usage10.022 versus last phase counter5.986. Its existing
native failure remains unresolved. Offline tests use injected process results;
they never compile or start BYOND, and do not establish a new native pass.


## Fixed capture-budget recurrence pilot

budget_pilot.py is a separate diagnostic entry point; ordinary benchmark.py,
its18-case selection and CI remain unchanged. Default operation only prepares.
Its8fresh-process order is B,C | C,B | C,B | B,C, with64roots/1024bytes each;
each process retains the same7-save schedule, guard and instrumentation.
There are at most2compiler and8daemon children, no replacements. Existing90s,
900s,1GiB and20ms limits remain fixed. An explicit newly approved UTC deadline
is additionally required for native mode, with5seconds reserved for reaping/reporting.

Only the targeted usage_delta>10 breach with no changed tick, work/absolute
usage/elapsed overrun, complete metrics and known attempt permits collection
of the remaining fixed repetitions. It stays a failed case. Resource/process,
identity/deadline, malformed or other guard failures stop launches and retain
not-run records. Diagnostic verdicts are completed_no_breach_observed,
completed_with_breaches or inconclusive_stopped. Acceptance always remains
not_established; no diagnostic result clears the original native failure.
No early success stopping, replacement runs or automatic retry is performed.

Native execution and publication are HELD for independent source review and a
fresh specific approval window. The old13:23UTC window does not authorize later
execution. There is no new hosted workflow/dispatch route in this change; the
exact reviewed source/manifest and supervised hosted invocation must be admitted
separately. Publishing this branch can still trigger ordinary30-minute nativeCI.
