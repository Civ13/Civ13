# Transfer storage: SQLite per region plus a small coordinator

Status: implemented, off by default (2026-11-04). The store (#3642), agent,
coordinator and save/load hooks (#3645), trade post (#3655) and the two-region
pilot are merged; see [tools/transfer_storage](../transfer_storage/README.md).
Nothing is enabled on a live server. It answers acceptance questions 1 and 4 of
[TRANSFER-CONTRACT.md](TRANSFER-CONTRACT.md): which backend stores the minimal
transfer state, and how that state commits atomically with inventory.

Decision (Val, 2026-11-04): each region (one DreamDaemon world with its own
`map_saves/`) keeps its transfer state in its own SQLite file, and a small
coordinator process knows the regions of a group and relays messages between
them. The coordinator never holds custody of items.

## The problem this design has to solve

Inventory in Civ13 lives in the world save, not in a database. A world save
becomes durable only when `map_saves/save_complete.txt` is written at the end
of `/map_storage/proc/Save` (saving.dm). Saves take minutes on Gaia, and a crash
before that marker means the world reloads the previous save.

The contract requires transfer state and inventory to commit together. SQLite
and the world save are two stores, so they cannot share one transaction. The
design therefore makes the world save self-describing and lets SQLite follow it:

- Every in-memory world effect of a transfer (items removed into escrow, items
  credited on import, escrow returned) is first recorded in SQLite as
  **tentative**.
- The world save writes the list of tentative effects it contains into its
  round state (`round_state["transfer_effects"]`), together with the ledger
  sequence it was captured at.
- An effect becomes **confirmed** only when a committed save that lists it is
  reported back, either right after the save or, if that report is lost, on the
  next load.
- No evidence (envelope, receipt) for an effect leaves the region until the
  effect is confirmed. A peer can therefore never act on an effect that a crash
  could still undo.

## Storage layout

| Component | File | Holds |
| --- | --- | --- |
| Region agent (one per world) | `<region>/transfers.sqlite` | Channel fences, at most one active transfer per directional channel, escrow payloads, tentative effects, one outbox entry per channel |
| Coordinator (one per group) | `coordinator.sqlite` | Region directory (stable IDs, endpoints, key IDs, epochs), group policy digests |

SQLite runs with `journal_mode=WAL` and `synchronous=FULL`, and every state
change is one `BEGIN IMMEDIATE` transaction. The agent is the only writer of its
region file. Python's standard `sqlite3` module is enough, so the agent and
coordinator need no third-party packages and fit next to the existing
`scripts/nomads-lifecycle/` supervisor. DM talks to its local agent over
loopback with `rustg_http_request_async`; rust_g's SQL support is MySQL only,
so DM never opens the SQLite file itself.

### Region tables

- `meta`: schema version, region ID, group ID, `ledger_seq` (increments on each
  confirmed effect batch), `confirmed_generation`, `hold_reason`.
- `channel_fence(direction, peer, group, epoch, settled_seq)`: the contract's
  replay fence. One row per enrolled directional peer; never deleted while the
  peer is enrolled.
- `active_transfer(direction, peer, group, epoch, seq, transfer_id,
  manifest_digest, manifest, phase, decision, last_step, last_receipt_digest)`:
  primary key `(direction, peer, group)`, so a channel can have only one
  transfer in flight.
- `escrow_item(transfer_id, item_index, payload)`: the serialized items the
  source removed from its world. While a transfer is escrowed these rows are the
  only copy, so they are the custody record.
- `world_effect(transfer_id, kind, state, generation)`: `kind` is `remove`,
  `credit` or `return`; `state` is `tentative` or `confirmed`.
- `outbox(direction, peer, group, step, envelope)`: the latest unacknowledged
  step for each channel, released only when its effects are confirmed.

Settlement deletes the transfer's `active_transfer`, `escrow_item`,
`world_effect` and `outbox` rows and advances `channel_fence.settled_seq` in the
same transaction. There is no receipt table and no history, as the contract's
official no-archive rule requires.

## Lifecycle against world saves

| Contract step | Region | SQLite change | World effect |
| --- | --- | --- | --- |
| Escrow | Source | Insert active row (Requested), escrow payloads, tentative `remove` | Items leave the world in memory |
| (save commits) | Source | `remove` confirmed, phase Escrowed, outbox gets the Escrow envelope | none |
| Prepare | Destination | Active row Prepared, capacity reserved | none |
| Commit | Source | Phase CommitDecided | none |
| Import | Destination | Tentative `credit` | Items appear at the arrival point in memory |
| (save commits) | Destination | `credit` confirmed, phase Imported, outbox gets the Import receipt | none |
| Finalize | Source | Escrow payloads deleted, phase Committed, then settlement | none |
| Abort / Tombstone | Source / destination | AbortDecided / DestinationAborted | none |
| Return | Source | Tentative `return`, then confirmed on the next save, then settlement | Items come back in memory |

Steps without a world effect (Prepare, Commit, Abort, Tombstone, Finalize) are
durable as soon as their SQLite transaction commits.

World effects are refused while a save is capturing, so the set of tentative
effects cannot change between the start of capture and the completion marker.
The arrival point shows a "busy" state instead.

### Save and load hooks

1. Save capture: DM writes the IDs of the effects it has applied in memory
   (it keeps that list itself, because it performed them) and the last
   `ledger_seq` the agent acknowledged into `round_state`. The save needs no
   call to the agent, so an unreachable agent can never fail or mislabel a
   world save. DM only applies a world effect after the agent has recorded it
   as tentative, so every listed ID exists in SQLite.
2. After `save_complete.txt` is written, DM reports
   `(generation, effect IDs, ledger_seq)` to the agent. The agent confirms
   those effects, increments `ledger_seq`, stores `confirmed_generation` and
   releases the outbox.
3. On world load, DM reports the loaded round state's generation, effect list
   and ledger sequence. The agent reconciles:
   - A tentative effect that the loaded save lists is confirmed (the
     post-save report was lost).
   - A tentative effect that the loaded save does not list is voided: a
     voided `remove` deletes the active row and escrow payloads (the items are
     still in the reloaded world and the peer never saw an envelope, so the
     sequence number is reused); a voided `credit` puts the transfer back to
     CommitDecided so the import runs again; a voided `return` re-arms the
     return.
   - If the loaded ledger sequence is lower than the agent's, or the loaded
     save lacks an effect the agent already confirmed, an older backup was
     restored. The agent sets `hold_reason = rollback` and refuses all new
     transfer steps until an operator resolves it. Old backups must not rewind
     a settled fence or resurrect consumed escrow, so the agent never clears
     the fence on its own.

## Coordinator

The coordinator is deliberately small:

- It stores the group's region directory and policy digests and hands them to
  agents. It is the place where an operator enrolls regions.
- It relays outbox envelopes between agents and returns acknowledgements. A
  lost relay is retried from the sender's outbox; receivers deduplicate by the
  channel fence and the latest-step rule.
- It holds no escrow, no inventory and no transfer phase. Losing
  `coordinator.sqlite` pauses transfers until it is restored from the operator's
  enrollment records; it can never duplicate or destroy items.

For the first pilot, both regions and the coordinator run on one host and talk
over loopback, with the files owned by the server account. Crossing hosts needs
the authentication profile that the contract leaves open (question 6) and is
out of scope here.

## Failure cases this has to survive

The phase 1 tests inject a crash at every boundary below and check that the
total item count across both regions plus escrow stays constant and that no
item is ever playable in two places:

- Crash after the in-memory escrow, before the save: items are back in the
  source world; the escrow is voided.
- Crash after `save_complete.txt`, before the post-save report: the load report
  confirms the effect.
- Lost Escrow, Prepare, Commit or Import message: retried from the outbox; the
  receiver answers idempotently.
- Crash after Import in memory, before the destination save: the credit is
  voided and redone; the source still holds the commit decision.
- Restoring an older source or destination backup: the region holds.
- Coordinator down at any point: transfers wait; nothing is lost.

## Phases

1. **Store and state machine** (Python, offline): region agent, coordinator,
   schema migrations, the save/load reconcile above, and the fault-injection
   tests. No DM changes.
2. **DM bridge**: an arrival-point object, the save/load hooks in
   `persistence/`, item serialization for an allowlisted set of item kinds, all
   behind a config flag that defaults off.
3. **Two-region pilot**: two worlds on one host, scripted transfers with forced
   restarts, run as a native test.

Each phase is its own PR. Nothing is enabled on a live server without Val's
explicit go-ahead.
