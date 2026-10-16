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
