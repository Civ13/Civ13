# Inactive immutable capture experiment

This experiment is not included by `civ13.dme` or the active saver. Its empty
default exact-type projection manifest admits no production types. The fixture
uses explicit fields for synthetic inputs and a small idle world. Capture invokes
no source projection or save callbacks and returns only detached JSON text.

The standalone `Inactive immutable capture experiment` workflow uses isolated
BYOND 516.1681 and temporary storage. New executable tests select `tests/world_save`
through the existing `ci-selection.yml` policy on this introducing PR. Subsequent
edits stay opt-in through that workflow's **Run workflow** action. The stacked
`nomads-round-metadata` base preserves the accepted source parent and keeps this
experiment separate from the four-flag PR; retarget after that dependency merges.

Four cases run independently: positive, callback, admission and hook. Every case
requires clean pinned compilation and no engine diagnostics. Each negative control
must reach its exact named failure; an arbitrary error, timeout or compile failure
fails the case. All attempted cases retain compiler/runtime logs, generated inputs,
source hashes, cleanup records and results in the exact-head artifact for seven days.
The workflow checks checkout identity and records Git blob identities. No production
save, Gaia process, OpenDream runtime or client is launched.

For a separately authorized isolated local test, use a verified full Python path:

```text
<python-path> tests/world_save/run-immutable-capture.py --byond-bin <516.1681-bin>
<python-path> tests/world_save/run-immutable-capture.py --byond-bin <516.1681-bin> --negative-control callback
<python-path> tests/world_save/run-immutable-capture.py --byond-bin <516.1681-bin> --negative-control admission
<python-path> tests/world_save/run-immutable-capture.py --byond-bin <516.1681-bin> --negative-control hook
```

Source review accepted the frozen four-file v2 experiment. Compilation and runtime
results must be read from the corresponding exact-head run; source acceptance is
not an execution result. Trusted manifests still need complete durable/paid-field
and inherited runtime-exclusion audits. The callback control checks getter
reintroduction, not independent runtime-exclusion callback reintroduction. No
decoder, restored cohort, representative pause or peak-memory measurement, durable
publication, five-minute crash recovery or zero-loss clean shutdown is established.
Logical bounds cannot preempt one native operation. The prior-file sentinel tests
only this prepublication experiment's lack of writes to that file.
