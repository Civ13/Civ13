# Final paid-child publication mutation control

The normal string-path fixture retains both the unchanged paid-child transfer
and late-movement cases in `transfers.dm`. This additional control removes only
the post-encode `drain_save_transfers(frame)` from a generated saver copy.
The production serializer and the fixture are unchanged.

Run the normal `run-string-path.py` command first, then repeat it with
`--publication-negative-control`, using the same pinned BYOND 516.1681 and
`--expected-saving-sha256`. Do not combine it with other adapters or controls.
Both commands require an allocated native execution window. `--prepare-only`
stages sources without compilation or execution.

Acceptance requires clean compilation, clean owned-process exits, no runtime
diagnostics, an unchanged positive PASS, and a mutation receipt with exactly
`FAIL: Chunk transfer publication did not detect late movement` and the matching
`failure-name.txt`. PASS, unrelated failures and diagnostic failures are rejected.
Source-input receipts retain both original and generated hashes. Run the offline
`test_publication_control.py` first; its success is not native runtime evidence.
This control makes no representative-world performance or deployment claim.

The proposed CI wiring adds that unchanged positive/control pair to the already
selected bounded-save step before its progress adapters. Both use the same
source hash and pinned toolchain, without extra adapters. Existing selection,
the 40-minute step limit and seven-day `save-latency-<SHA>` artifact stay intact.
Temporary source manifests, compiler/runtime logs, cleanup records and accepted
summary receipts remain under that artifact directory, including after failure.
Each command retains the runner's 120-second compiler and daemon timeouts, with
up to six seconds of owned-process termination cleanup per process. No new CPU,
memory or disk limit is introduced. Full-step timing is still unverified.
This is source preparation pending execution admission and exact-head CI; neither
the wiring nor its offline contract tests establish a native publication pass.
