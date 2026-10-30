# Proposed isolated memory and tick benchmark

Status: **not run**. Source preparation and offline tests are not memory evidence.
This plan needs separate authorization for the isolated native run. It never uses
production save files, accounts, credentials, game listeners, or a live process.

## What must be measured

The 1 MiB reservation is bookkeeping, not a BYOND heap/RSS limit. Measure total
process memory including the native in-memory savefile, encoded envelopes, copied
lists/strings, path inventory, live source objects, roster, entry/list/durable
pins, allocator retention, and both old/new generation file handles. Capture
replay retains the full staged file until its last field has been written.

Collect externally on Linux every 20 ms: `/proc/<test-pid>/status` VmRSS/VmHWM and
`/proc/<test-pid>/smaps_rollup` private clean/dirty and PSS when available. Use
`/usr/bin/time -v` max RSS as an independent process high-water measurement.
Timestamp samples and fixture phase lines with a monotonic clock. For Windows,
use Process WorkingSet64/PeakWorkingSet64/PrivateMemorySize64 and record OS/BYOND
versions; do not compare different platforms as one regression result.

Fixture counters must report maximum live roster size, captured node/list/edge
counts, logical reserved bytes, encoded path count, saved-reference/list pins,
and snapshot replay progress. Record capture tick use, end-to-end save time,
heartbeat maximum gap, throughput, and success/refusal. Logical counters explain
RSS changes; they are not substitutes for RSS/private bytes.

## Concrete first run proposed for approval

- One disposable Linux CI job, pinned BYOND 516.1688, no network listener; isolated
  temporary directories for each case, maximum two concurrent test processes.
- Compare feature-disabled and enabled saver paths in the same source/fixture,
  compiler, world, object order, payload seed and resource limits. Label this
  **same-head feature-disabled baseline**, not an old-binary benchmark. Separately
  retain a current-master binary baseline if its fixture can be built unchanged.
- Initial workload matrix: 64, 512 and 2048 eligible animals; detached payloads of
  1 KiB, 16 KiB and 64 KiB per root; at most 128 MiB aggregate synthetic payload.
  Record actual preflight admission/fallback rather than assuming each size enters
  staging. Include one >8192-registry fallback case with tiny payloads.
- For each pair, run three successful saves followed by three injected failures
  and another successful save in the same process. Sample after construction,
  roster admission, capture, replay, validation, cleanup and an idle interval.
  Also run one fresh process per mode to distinguish allocator high-water retention
  from growing reachable pins. Retain all failures, including budget refusals.
- Failure points: tick change in capture, depth/work limit, root deletion during
  frontier-drain replay, and disk/copy failure. Before every attempt preserve an
  independent hash manifest of the previous completed generation; after refusal
  verify all prior backup bytes and restore them in a separate disposable process.
- Resource safety: 90 seconds per case, 20 minutes per job, terminate only the
  test-owned process if RSS exceeds 1 GiB or the timeout. Record the last sample
  and complete logs; a resource-limit termination is failure evidence, not a pass.

## Acceptance gates

No deployment conclusion until actual results establish:

1. No identity loss, duplicate ownership, mixed aliases, or prior-generation loss.
2. Peak memory reported for baseline and candidate, by workload and phase, including
   ratio/delta and admitted/fallback counts. A low logical reservation alone fails
   this evidence requirement.
3. Repeated failures release reachable roster/chunk/entry/list ownership; persistent
   allocator high-water retention must be distinguished from unbounded per-attempt
   growth. Investigate any monotonic post-cleanup increase rather than hiding it.
4. Capture/heartbeat latency and save throughput remain within an explicitly agreed
   operating budget. The current post-operation checks do not guarantee a hard
   maximum pause. Establish representative limits from baseline before choosing a
   production threshold; do not invent a pass threshold after seeing candidate data.

The current prepared correctness fixture emits CHUNK_PROFILE logical counters.
It is not yet the feature-disabled baseline, external memory sampler, or full
scaling/repeated-failure benchmark runner. The
parameters above describe the bounded run to authorize and implement; no native
or live benchmark has been executed.
