# Canonical-only owner contract (source proposal)

This proposal does not activate a server. The owner is a single persistent
process, not a PID-adoption or remote-control interface. Bot spool access stays
disabled and its writer check is unchanged.

## Bootstrap

The `canonical_owner.py --config <reviewed-config>` entry point is default-off.
It requires `canonical_owner_enabled`, `canonical_update_enabled` and
`canonical_initial_start_enabled` to be true, `canonical_bot_enabled` to be
false, and exact `canonical_owner_revision`, `canonical_owner_dmb_sha256`,
`canonical_owner_rsc_sha256`, map and `canonical_initial_generation` pins.
The owner holds the existing supervisor lock for its entire lifetime.
It rejects any existing owner state, halt latch, update journal, maintenance
receipt or bot spool record; an operator must reconcile these before a new owner
is considered. It never removes or reinterprets them. Under the lock it checks
the existing native quiet gate, validates the named existing save and binary
pins, snapshots that save, archives the old binaries and starts only the fixed
canonical program. The shared readiness path binds listener, child creation
identity and boot session before polling the existing typed admin request.

## Ownership, requests and cancellation

The same supervisor instance and lock lease handle startup and every subsequent
typed maintenance request. Polling is serialized; it adds no control listener,
does not consume bot records and accepts no request-supplied commands or paths.
The existing request identity, session, expiry and receipt checks remain in
force. Previously accepted, completed, failed or ambiguous records cannot be
replayed. New owner startup refuses all surviving maintenance receipts rather
than assuming they are safe to clear.

The entry point handles Python-delivered SIGINT and SIGTERM cooperatively. A
cancellation observed at the pre-spawn check or before a typed
maintenance receipt refuses that admission; evidence already written remains
for review. A signal can arrive after a check and before the effect, so these are
not atomic cancellation boundaries. Once an effect is admitted, cancellation
does not interrupt it or imply it was cancelled. After the current operation
returns, or on an operational
failure, the owner stops
polling and retains its lock and child handle until that exact child is known to
have exited. It never initiates a save, shutdown or kill merely to exit. A
hard termination, session loss or machine failure can destroy the helper and
its OS handle; the persisted PID is not ownership and a later invocation must
refuse adoption and require operator reconciliation. No claim of persistence
across helper death is made. Signal delivery to other processes and host-specific
console behavior are not established by the offline tests.

## Recovery and evidence

Any unknown outcome, inaccessible listener, changed session, failed start or
interrupted transaction preserves state, generation, journal and artifacts.
An owned running child is left in place. No automatic retry, rollback, empty
world, forced termination or cleanup follows. A saved-stop journal is not a
first-start input: it requires a separately reviewed reconciliation path.
Verification uses synthetic data and injected process, clock and transport
effects; it does not establish Windows listener completeness or real save/load
correctness.
