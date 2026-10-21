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
