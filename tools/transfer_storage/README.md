# Transfer storage (phase 1)

`region.py` is the per-region SQLite store from
[TRANSFER-STORAGE-SQLITE.md](../server-management/TRANSFER-STORAGE-SQLITE.md).
It uses only the Python standard library. Nothing in the game calls it yet, and
it opens no network port.

- `RegionStore.enroll(peer, direction)`: the operator step that permits one
  direction with one peer.
- `begin_escrow`, `begin_import`, `begin_return`: record a tentative world
  effect. DM may change the world only after the call returns, and lists the
  returned effect ID in its next world save.
- `report_save` (after `save_complete.txt`) and `reconcile_load` (at world
  load): confirm the effects a committed save lists and void the rest. Loading
  a save older than the store's ledger puts the region on hold.
- `outbox()` and `receive(envelope)`: the messages between regions. A step's
  envelope enters the outbox only after its effects are confirmed.
  Retransmissions and stale steps change nothing.

Not here yet: the coordinator process, an HTTP endpoint for DM, envelope
signing, and the DM bridge (phase 2).

## Tests

```
python3 -I -B tests/transfer_storage/run.py
```

`tests/transfer_storage/sim.py` models two DM worlds around the store: an
in-memory item set, the last committed save, and crashes that reload that save.
The tests cover the failure cases listed in the design. `RandomFaults` adds 150
seeded runs of random transfers, saves, lost save reports, crashes, aborts, and
dropped or duplicated messages. After every step it checks that no item is live
in two worlds. At the end it checks that every item survives exactly once and
no transfer is stuck.
