# Fresh world from the launcher

## Phase 1: stopped, unlinked regions only

The launcher's **One region > Fresh world…** archives a selected region's map
save and starts the same installed build on a fresh map. It is deliberately
not a full account wipe, update, force-stop, or connected-group reset.

1. Use **Save and stop** first. Running, sleeping/cold, and staging regions
   are refused. Build and sign in to BYOND before starting this operation.
2. Choose one region and read the scope warning. Type its exact ID. There is
   no all-regions button, unattended HTTP action, or default confirmation.
3. The host acquires its normal exclusive action lock, rechecks the conditions
   in the worker, and records an atomic reset journal before moving anything.
4. It renames `map_saves`, `map_backups`, and `map_rollback` into a unique
   `data/shard-host/fresh-world-archives/<operation>` directory. No retention
   pruning or permanent deletion occurs. All three generations move together
   so an old backup cannot silently resurrect the old world.
5. Only after all moves succeed does the host start the installed build. It
   does not pull, compile, or rotate staged builds. Completion means the port
   opened, **not** a native gameplay acceptance test.

The selected world loses its buildings, dynamic factions, local constructed
transit objects, saved bodies and inventory. Account preferences/admin notes
(`data/player_saves`), SQL access lists/bans, settings, round history, reputation
and raid cooldown files remain. Preserving account records is **not** retaining
characters' in-world bodies, possessions, or bases.

The operation refuses any group with configured transfer agents, any retained
transfer-agent configuration/database, and separate extraction/vehicle/safehouse
storage. It does not claim to remove transits in a peer's world. Old standalone
host profiles should first be managed as a single-region group; the legacy
standalone action row deliberately has no reset control in this phase.

Equivalent CLI (explicit confirmation, local operator only):

```
python scripts/shard-group/shard_group.py --config GROUP.json fresh-world --region REGION --confirm-region REGION
```


## Phase 2: the whole linked group

A connected region group (regions with transfer ports, such as Gaia and its
regions) cannot use the single-region reset, because travellers in flight and
account homes live in the transfer stores. The group fresh world resets the
whole group at once:

```
python scripts/shard-group/shard_group.py --config GROUP.json group-fresh-world --confirm-group GROUP
```

1. Use **Save and stop** on every region first. Any running, sleeping,
   staging or busy region refuses the whole reset, and nothing changes.
2. The command takes every region's action lock and writes
   `<root>/fresh-world-group.json`. While that file exists the supervisor does
   not start transfer agents or the coordinator. It then stops the agents and
   the coordinator, and refuses (removing the journal, moving nothing) if any
   of them keeps running.
3. Each region gets its own `fresh-world-pending.json`, so its host refuses
   start, wake and the watchdog during the moves.
4. It renames into `<root>/fresh-world-archives/<operation>/`: each region's
   `map_saves`, `map_backups`, `map_rollback` and `transfers.sqlite` (with its
   `-wal`/`-shm` files) under the region id, and the group's
   `coordinator.sqlite`. Nothing is deleted. Each region gets an empty
   `map_saves`.
5. Only after every move succeeds are the pending files and the group journal
   removed. Every region is then asked to start. The supervisor starts new
   agents and a new coordinator, which create empty stores and enrol every
   region.

All characters (their saved bodies), buildings, factions, travellers in flight
and account home worlds are reset. Accounts in `data/player_saves`, bans and
settings remain. Separate extraction/vehicle/safehouse storage is still
refused. If it is interrupted, both journals stay in place; recover by hand as
for one region, for every region in the manifest plus the coordinator store,
then remove the group journal.

### Interrupted operations and restoration

`fresh-world-pending.json` is a process-interruption interlock. Atomic journal replacement is not a
power-loss durability guarantee; a power failure requires inspecting the
archive and active paths before restarting the host service. While it exists, the region
refuses normal host requests, wake and direct startup, and the watchdog does
not recover/thaw it. Never clear this marker just to make a start succeed.
The manifest lists all intended paths; an interruption between rename and
journal update means its `moved` list may lag the actual filesystem.

Recovery is manual with the host service stopped and all world processes
confirmed stopped. Inspect both the archive and original paths for **every**
manifest entry. Restore archived paths to their original locations only after
preserving any newly generated world separately; never overwrite or mix save,
backup, and rollback generations. Validate the restored save before restarting.
Only when the paths have been reconciled may the pending marker be archived
out of its interlock location. Keep the original archive/manifest and incident
record. A start failure after archival leaves the complete archive intact and
allows a later ordinary start of the fresh world, or manual restoration.

Archive paths containing symlinks, Windows junctions/reparse points, or linked
parents are refused. The host does not delete/rewrite shared transfer stores.
Restoring a linked group's world is **not** supported by this recovery procedure.

## Phase 2 plan: coordinated connected-world reset

User intent: remove player-created transits and relevant transfers removed
with the world, while retaining character records. A local database deletion
cannot safely implement that policy.

### Why this is a separate protocol

- Rail offices and freight are local saved objects, but player-train interiors
  and berths live in a RAILYARD peer. Berths retain `party`, `home_region` and
  destination. Party IDs have no world generation: a same-name new faction
  can otherwise reconnect to old assets.
- Transfer `active`, `escrow`, `effect`, `journal`, and `outbox` rows span peers.
  Their IDs contain region/epoch/sequence, not a world incarnation.
- `home` and `account_request` encode account custody. Keep them separate from
  world-object cleanup; never silently drop them alongside a transfer database.
- RAID's `fresh` reconciliation adopts the current ledger but still replays
  journaled arrivals. It is not a persistent-world reset mechanism.

### Dependency-ordered implementation

1. **Inventory and identity.** Add durable world-incarnation IDs to world saves,
   transfer payloads and player transit ownership. Define a read-only preview
   listing selected worlds, peer-owned assets, transfer IDs and affected account
   custody. Refuse ambiguous legacy associations; region names alone are not
   enough. Include rail, orbital transit and any extraction/safehouse domains.
2. **Quiesce and snapshot.** Acquire a group reset lock respected by launchers,
   watchdogs, agents and coordinator. Prevent new departures/claims. Settle or
   explicitly classify in-flight transfers, stop relevant writers, and archive
   consistent world saves plus SQLite backup snapshots. Failure leaves a durable
   group hold, not an auto-restart. No live service/security changes under this PR.
3. **Classify effects.** Inventory/assets removed by reset get durable cancellation
   tombstones on both peers. Transfers wholly outside the reset remain intact.
   Preserve identity/history/account records. Do not infer an account's destination
   from a missing body: explicitly define and preview rehoming/evacuation for
   characters occupying removed transits and transfers in flight.
4. **Fence and clean.** Introduce a reset epoch/incarnation fence rejecting old
   envelopes and replays. Remove peer-world transit assets through a validated DM
   operation keyed to the old incarnation, not SQL-only heuristics. Retain
   tombstones long enough to reject delayed retries. Commit counterpart effects
   and custody outcomes idempotently.
5. **Commit and boot.** Publish new incarnation only after every participant
   acknowledges. Verify world-ready, expected account homes, no orphan train
   berths, no old arrival replay, and fresh save/ledger agreement. Release hold
   only then. Interrupted transactions resume or restore as a whole group.

### Required evidence before enabling linked resets

Offline state-machine tests must cover mixed unaffected/affected transfers,
all escrow/import/return phases, delayed/reordered envelopes, failed participants,
crash after each commit boundary, and same-name faction recreation. Native
multi-region acceptance must verify occupied trains, sleeping/offline characters,
character inventory policy, travel after reset, and save/reload. Whole-group
restore must be tested against matching ledger snapshots. No native reset tests
or live reset are performed by this first-phase change.
