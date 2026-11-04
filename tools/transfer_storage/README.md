# Transfer storage (phases 1 and 2)

`region.py` is the per-region SQLite store from
[TRANSFER-STORAGE-SQLITE.md](../server-management/TRANSFER-STORAGE-SQLITE.md).
It uses only the Python standard library and opens no network port itself.

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

`agent.py` serves one store over HTTP for DM (through `rustg_http_request_async`)
and the coordinator:

```
python3 tools/transfer_storage/agent.py --db transfers.sqlite --region gaia \
    --group pilot --port 47201 --token-file transfer-token.txt
```

It binds 127.0.0.1 only, refuses any other client address, requires the
token (at least 32 characters) in `X-Transfer-Token`, caps bodies at 1 MiB, and
handles one request at a time. Every route is a POST with a JSON body:
`/status`, `/outbox`, `/receive`, `/escrow`, `/import`, `/return`, `/abort`,
`/save` and `/load`. A refusal answers 409 with `ok: false` (and `held: true`
while the region is on hold).

`coordinator.py` keeps the region directory in its own SQLite file and moves
outbox envelopes between agents (`relay_once`). It holds no custody, and for
the pilot it only enrolls loopback agents.

## DM bridge (off by default)

`code/modules/persistence/transfer_bridge.dm` connects a world to its agent.
It stays off unless `config/transfer_agent.json` exists with a `port`
(1024-65535) and a `token_file` holding the same token the agent uses:

```
{"port": 47201, "token_file": "config/transfer-token.txt"}
```

When on, a world save writes `round_state["transfer"]` (generation, the effect
IDs applied in memory, and the last acknowledged ledger sequence) and reports
it to `/save` after `save_complete.txt`. A world load reports the loaded
capture to `/load`, retrying every minute until the agent answers. No effect
can be applied before that reconcile succeeds, while a save is running, or
while the region is on hold.

Not here yet: the arrival point that calls `begin_escrow`, `begin_import` and
`begin_return`, and envelope signing for agents on different hosts.

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
