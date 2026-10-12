# Extraction survival implementation

This mode is under implementation and has not received playable acceptance.
Vehicle extraction remains incomplete. An internal helper preflights a stopped,
unoccupied car and a clear floor footprint, then moves its existing parts and
nested controller, steering and wheels. It rejects loose or nested cargo and
preserves the actual tank, fuel and wall condition. A bounded explicit vehicle
codec now persists one car graph through the account journal. Three native
processes verify ordinary reload, condition/fuel preservation, durable removal
and stale revision rejection. Interrupted debits remain quarantined; explicit
offline loss settlement forfeits the uncertain garage with an audit receipt.
An omission control proves the test detects retention of that previous garage.
Account admission now restores an acknowledged car into its bounded private
bay. Stash and garage condition checkpoint in one account transaction; tank
parts are excluded from loose stash. A blocked bay exposes no partial account
restoration. Release saves before retiring top parts and contained controller,
steering and wheels. Moving, occupied or displaced cars block save/release.
Paid acquisition, raid ownership transitions, cargo/capacity and passenger
policy remain required before a vehicle extraction action is available.

Isolated native tests cover account storage, nested equipment restoration,
bounded NPC combat, extraction cancellation, private rooms and hub navigation.
Existing Factory mode stays available unchanged. Stack transformations and
playable acceptance remain pending. The required genuine concept video has
not been recorded.

The shared concourse terminal offers a server-wide vote for the next round:
Industrial District, Alleyway or Bank Robbery. Only these existing map files
are accepted. Voting records a choice; the map-switch process waits until the
finite raid has finished durable stash and insurance settlement. The terminal
also returns players to their private house. Starting a vote requires an empty
carried inventory and a conscious account owner in the concourse.

The launcher replaces an explicitly marked map-selection block with one
unconditional include. This avoids leaving a selected TDM map inside the
inactive extraction compile conditional. Offline tests exercise the rewrite;
the catalog check compiles all three actual environments with BYOND 516.1681.
The mode fixture records the switch request through an injected adapter and
does not deploy, restart production or establish graphical menu acceptance.

The private-house terminal offers raid groups of two to four players. The
leader invites each member, who must accept and ready their own loadout in
their house. Groups share a PMC or Scav faction and expire after five minutes.
Membership changes, withdrawal, condition changes or a new stash revision
invalidate readiness. The leader starts deployment only when every current
member is ready. Current group deployment is uninsured; paid insurance remains
available through individual deployment.

The group journal reuses exact forward settlement beneath `_settlement/groups/`.
It validates every home-to-raid projection against the same pure debit planner
used by individual raids, then commits all debits before moving any member.
Existing item atoms move together to one raid spawn. Account access is gated
throughout the commit. A failure before the shared receipt leaves everyone home;
a failure after durable intent locks participants and account access. On restart,
complete recorded projections finish forward and interrupted raids forfeit their
issued gear. An unknown initial intent remains blocked for explicit recovery.
Recovery never reconstructs issued gear as a second copy.

The mode fixture checks four real human constructors and original gear atoms,
consent races, readiness changes, member replacement, live access gates and
independent extraction. `--probe groups` runs three native processes across
eleven journal/account interruption points, including initial and final receipt
writes. Its debit and visibility negative controls must fail at the intended
assertions. These checks do not establish connected invitation dialogs, client
movement/rendering or production restart acceptance.

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
Each private house has an account-bound secure crate. Deposit a held supported
item to commit its entire graph and secure-storage location in the same account
snapshot. Withdrawal rechecks current ownership and commits the location change.
Released rooms retire their materialized contents; admission restores secure
entries into the newly bound crate. Other accounts and stale sessions cannot
withdraw. Secured gear stays outside raid loadouts until withdrawn, and survives
raid death through the existing stash journal. This uses the fixed room pool;
there is no background world or timer for each offline account.

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

The industrial district closes thirty minutes after its round starts and warns
players five minutes before closure. Extract or use shipment boxes before the
deadline. Closing forfeits unsent raid gear and saves equipment left at home.
Human bodies follow the shared corpse lifecycle; extraction does not delete them
after five minutes.

The private terminal offers insured PMC deployment. Its confirmation shows the
premium: one workshop part per reusable equipment component, including attached
sights and magazines. Leave payment parts at home. Ammunition and consumed
supplies are excluded. Payment and claim issuance commit together. Unrecovered
insured gear retains its actual condition until closing, then eligible components
are returned through account mail after their physical sources retire. Gear
recovered into another account's stash does not also return to its original owner.
Use the house terminal's mail action in a later round to move returned equipment
into available stash space. Full mailboxes or unresolved ownership journals hold
settlement for recovery. A process restart does not resume an active raid or infer
physical retirement from missing world objects. Connected-client acceptance and
the separate long-running Nomads version remain pending.

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
See [offline journal reconciliation](extraction-recovery.md) for exact-intent
completion, ownership conflicts, non-reissuing delivery retirement and explicitly
approved conservative stash-loss settlement. Recovery is never automatic.
Graphical container interaction and whole-world restart remain acceptance gaps.

`tests/extraction/run.py --byond-bin <516.1681-bin>` compiles the production
account journal and executes real native file operations in temporary storage.
It checks restart readback, isolation, stale revisions, bounded slot reuse,
interruption after intent and snapshot writes, corruption and unsupported
schema rejection. It does not start game systems or verify playable extraction.
