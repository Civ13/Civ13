# Moving-root chunks: first-cohort verification

`python3 -m unittest discover -s tests/movement_save_chunks -v` runs an explicitly
labeled offline ownership algorithm projection plus production source-boundary
checks. It does not execute DM or establish native save/load success.

`python3 tests/movement_save_chunks/prepare.py` copies current production serializer
inputs and the isolated native fixture to a new temporary directory, recording
SHA-256 hashes in `receipt.json`. It never compiles or starts a daemon. Reprepare
after every source change; an earlier receipt does not describe current bytes.

Prepared scenarios: `walking`, `frontier`, `frontier-delete`, `delete`, `inventory`, `cross-z`, `yield`,
and `depth`. Positive cases assert exactly one saved animal parent and a completed
marker. Refusal cases assert no new marker, released capture state, and unchanged
prior completed backup marker. Full backup byte/roundtrip recovery, human inventory
coherence, native latency, and fixture compilation remain unverified.

The production cohort is empty direct-turf simple animals without physical
coupling. It is not a generic moving-item/container or player-inventory solution.
Failed capture aborts the candidate, rather than reusing partially reserved IDs.
Tick-change detection is defensive: it does not detect every same-tick sleep(0).
The permitted hooks are currently audited nonyielding; future hook expansion
requires a new audit. Logical limits do not preempt an individual native copy.

Eligibility uses a no-write closure preflight. Existing external-reference or
oversized animals and registries larger than 8192 retain legacy saving; no
serializer identities are allocated by preflight. A newly introduced unsupported
state after admission still rejects the candidate. New births use legacy
incremental traversal and are not guaranteed included by the fixed roster.

The proposed native runners bind loopback, disable the web client, and the fixture
closes/refuses ports. These source controls are not a measured no-listener claim.
The approved 1 GiB RSS sampling cap is supplemented by a stricter 1 GiB virtual
address-space limit on each test child; such early rejection is retained as a
failed/inconclusive run, not memory acceptance. Compilation shares the 90-second
case ceiling. The matrix contains nine baseline/candidate pairs (18 cases).
