# Save/load operation admission

`run.py --byond-bin <516.1681-bin>` compiles the production persistence functions,
saver and loader with the existing offline stubs. The tiny probe exercises the
actual ticker wrappers, public lower-level entry points and shared operation
identity. Storage adapters expose preflight, backend, yielding and client callback
boundaries without game startup, clients or production files.

Checks cover all save/load overlap combinations, admission before the save wrapper
sleeps, direct entry, repeated backend entry, stale completion, preflight failure,
backend failure, cleanup exceptions, recovery holds and explicit restart ownership.
Run each `--negative-control admission|stale|recovery|player-ready` separately; each generated
mutation must fail its named assertion. `--prepare-only` hashes and stages sources
without compiling or launching BYOND. Evidence is retained in temporary storage.

These are isolated native admission regressions, not full-world recovery or
connected-client acceptance. Existing world-save round trips cover serialization.
The final callback invokes production player-restoration admission; a dedicated
control removes the completed-import phase and must detect blocked restoration.

Busy-transition regression uses the exact source-bound production idle helper for
all four transition predicates. Seeded registry/body/readiness must survive safe
rejection, with zero backend/ClearMap calls, no recovery hold and a successful
retry after the transition settles. Legacy imports preserve the no-state no-op.
Two additional controls move the preflight after mutation marking or restore
unconditional catch cleanup; both must fail the retained-registry assertion.
The durable timer suspension body remains an adapter here; its recheck and timer
ordering require source review, not a claim of full-world timer recovery.

For edits to this existing suite, dispatch CI at the exact candidate head with
world_save_operation_regressions=true. Verify that the named native step and all
six controls ran; a skipped pull-request step is not acceptance. Source-only
preparation does not establish native compilation/runtime or deployment.
