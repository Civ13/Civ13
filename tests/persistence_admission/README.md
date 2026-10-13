# Admission adapter contract

This fixture compiles the production admission adapter with a minimal datum
base and an injected provider. It disables listening ports and runs in temporary
offline storage. It does not start Civ13, install a host provider or establish
asset custody, immutable membership, containment or faction admission.

Run with a verified interpreter and the pinned BYOND 516.1681 bin directory:

```text
<python> tests/persistence_admission/run.py --byond-bin <bin>
<python> tests/persistence_admission/run.py --byond-bin <bin> --negative-control binding
<python> tests/persistence_admission/run.py --byond-bin <bin> --negative-control recheck
```

The positive fixture checks exact eight-field scalar bindings, defensive copies,
action and identity matching, exact TRUE provider results, stale revisions,
revocation and rebinding during callbacks, and invalidation across a yield.
Deleting the capability during either callback must deny without an engine error;
deleting the guard or provider during either callback must also deny.

The binding control removes the exact-length guard and requires only the extra
binding assertion to fail. The recheck control omits the final identity/binding
recheck while retaining type and action checks; only the callback binding mutation
assertion may fail. Engine diagnostics, extra failures, timeout or nonzero exits
invalidate both positive and control results.

The runner prints its evidence directory and retains source hashes, compiler and
daemon logs, result, process cleanup records and a summary. CI retains the whole
step's temporary directory even on failure. The selected remote step also runs
the existing production `loadmap` wrapper with ordinary legacy/v2 disk round trips
to check the separate null-policy compatibility contract.

Source and runner review are pending; no execution result is claimed here.
