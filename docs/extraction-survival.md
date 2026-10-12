# Extraction survival implementation

This mode is under implementation and has not received playable acceptance.
Isolated native tests cover account storage, nested equipment restoration,
bounded NPC combat, extraction cancellation, private rooms and hub navigation.
Existing Factory mode stays available unchanged. Insurance, secure deposits,
stack transformations and map voting
remain pending. The required genuine concept video has not been recorded.

## Milestones and dependencies

1. Durable account snapshots, revision checks and interrupted-transfer barriers.
2. Bounded equipment graph, raid ownership transfers, death/restart forfeiture,
   duplicate-login exclusion and upgrade transactions.
3. Dedicated original raid map and jobs, private room pool, stash interactions,
   extraction cancellation and disconnect lifecycle.
4. Neutral scavengers that react to provocation, hostile contractor NPCs,
   bounded population, path searches, corpse and loot cleanup.
5. Integrated production tests, negative controls, save/restart tests, actual
   gameplay evidence where needed, sprite previews, CI and player wiki updates.

The starting source is master `60b8cf9937617d62c4cc01f82bf32401559b84f4`.
The gun configuration and harvesting changes were merged before implementation;
remote Civ13 had no open PRs at the dependency check.

## Storage contract

The native DM journal uses two snapshot slots per stable registered account.
Each transfer writes and reads back an intent, payload and commit record. The
newest complete revision is authoritative. A malformed or incomplete intent
locks the account for operator recovery, including after a restart. Automatic
rollback could reissue equipment that already left storage, so the retained
previous slot is a recovery backup, not an automatic replacement.

This is logical transaction atomicity with fail-closed recovery. BYOND does not
expose a portable atomic file rename or an operating-system fsync guarantee.
The implementation must not promise survival of arbitrary disk loss. Deployment
requires external backups, one authoritative server for the account directory,
and a documented recovery procedure that reconciles ownership before unlocking.

Profiles are versioned, limited to 2 MiB and 64 stash roots. There are six
committed files per account, plus temporary files during a write. Accounts have
no timers or live worlds while offline. Unsupported versions are rejected;
future schema changes need explicit migrations before release.

## Planned integration constraints

Use a fixed private room pool on the same-sized safe-house level. Allocate rooms
on demand and clear their live contents when released; no z-level per account.
Room access must check the bound account and active session on every interaction.
Gear must be debited durably before entering a raid, and credited durably before
raid items are retired. Interrupted raids forfeit issued gear. Normal full-world
saves must not duplicate account-owned transient entities.

Use existing conventional sprites and production combat procedures. Preserve
contained attachments, ammunition and components through an explicit bounded
equipment graph; never serialize the player or client session. Reject unsupported
equipment before consuming or transferring it. Bound NPC population, perception,
pathfinding and cleanup work. Do not add a recurring timer per account.

## Current verification

The opt-in `EXTRACTION_SURVIVAL_MAP` compile flag selects the original 96x96
industrial raid, 16 fixed private houses on level 2 and shared concourse on
level 3. All levels have the same dimensions. Fixed daylight is an explicit map
design choice. Visiting the concourse requires leaving equipment in private
storage; the return terminal resolves the current account's bound house.

Equipment graph schema 2 preserves unique identities and found-in-raid status
for each contained node. Successful extraction retains provenance; bringing
equipment into a subsequent raid clears it throughout the bounded graph.
Schema 1 graphs migrate with new identities and no invented provenance.
Unsupported stack types remain rejected. Duplicate identities within a graph
or across stash roots are rejected before account transfer.

See [the probe and video acceptance matrix](../tests/extraction/README.md).
The `restart` probe starts three separate native processes over disposable
storage. The `mode` probe exercises production transitions with injected client
identity/action waits. The provenance negative control intentionally drops the
tag in a generated source copy and must fail the native reload assertion.
These checks do not prove full-world startup, real-client identities or graphics.

## Shipments and conditional exits

Use a raid drop box with an item held in your inventory to send its complete
supported graph home. The account journal commits before the physical copy is
retired. The raid stays active; death and interrupted-raid recovery preserve
already committed shipments. Duplicate root or nested identities reject replay.
The stash capacity also bounds stored shipment history. Pending insurance must
consume the same ownership identity rather than returning a shipped copy.
Private secure storage crates remain separate pending work.

Deploy as PMC or Scav using your own equipment. The chosen raid role is committed
with the loadout debit. The district has all-role, PMC-only, Scav-only and manhole
exits. A manhole rejects backpacks anywhere in the actual contained inventory.
The secure room requires its matching key, account unlock during the current
raid, entering the room, closing the real door and locking it from inside.
An open/broken/unlocked door, another occupant or losing the key rejects exit.
Conditions are rechecked at each one-second action segment and immediately
before the durable extraction commit. Real-client door clicking remains part of
graphical acceptance; the isolated fixture invokes the production door switch.

A separate original Modern-city Nomads extraction version is authorized but
not implemented. It will share account APIs, preserve ordinary Nomads and short
raids, and use announced scheduled evacuation departures. Stranded players lose
unsent gear; committed shipments remain. Persistent bounded game currency will
not integrate live CivilizationBot currency. No scaffold constitutes acceptance.

## First-access loot

The original district has 18 persistent container journals. Untouched containers
have no generated contents or journal directory. Workshop, ammunition and armory
tables use integer basis-point appearance chances (75%, 80% and 35% per slot),
explicit common/rare/exceptional weighted outcomes, one to four slots and one or
two items per outcome. A validated plan commits before constructors run; full
equipment records commit before the list becomes visible. Partial construction
retries that plan rather than rolling again. Empty results persist too.

Claiming debits the container before exposing a physical item. A pending delivery
or incomplete acknowledgement locks reconciliation and does not automatically
replay, including during a later raid. Containers have no periodic restocking.
Each world instance obtains a durable fresh raid epoch; container records reuse
their two journal slots instead of accumulating per-round directories. Starting
a new world currently begins a new raid and forfeits issued player loadouts.
Reloading a container within the same raid preserves unclaimed/claimed results.
Resuming an active playable raid across process restart is not established.
Graphical container interaction and whole-world restart remain acceptance gaps.

`tests/extraction/run.py --byond-bin <516.1681-bin>` compiles the production
account journal and executes real native file operations in temporary storage.
It checks restart readback, isolation, stale revisions, bounded slot reuse,
interruption after intent and snapshot writes, corruption and unsupported
schema rejection. It does not start game systems or verify playable extraction.
