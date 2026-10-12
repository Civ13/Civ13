# Extraction survival implementation

This mode is under implementation and has not received playable acceptance.
Vehicle extraction remains incomplete. An internal helper preflights a stopped,
unoccupied car and a clear floor footprint, then moves its existing parts and
nested controller, steering and wheels. It rejects loose footprint cargo and
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
The private terminal sells a Piccolino for 25 uninsured workshop parts after a
paid level-two house upgrade. A clear bay and a confirmed, unchanged stash
revision are required. Payment commits before the production factory creates
the car, without fuel. Completion records the actual car graph in the next
account revision; reconnect restores that acknowledged graph once. Pending
construction quarantines the account on restart. Explicit offline forfeiture
records the purchase identity and receipt, without refund or car reissue.
A payment-retention mutation control detects keeping spent parts in the stash.
Boot tiles now accept up to eight equipment roots and 32 total size units,
including nested contents. Size uses each approved type's initial item size.
Cargo saves its original equipment identities, condition and provenance beside
the car graph, and cannot also appear in the stash. Reload validates boot
positions and car/cargo identity collisions before constructors run. A changed
nested cargo graph invalidates a previously captured transfer.
The terminal now deploys a solo PMC car. A clear raid footprint and stopped,
empty seats are required before the account atomically debits the car, cargo
and carried loadout. The original parts move into the raid; brought-in cargo
loses found-in-raid status. Normal exits offer vehicle extraction for the
session's parked car or a nearby registered looted car within four tiles. Car, current boot cargo and carried
equipment credit together before the original parts return to the clear bay.
Cancellation, running engines and occupied bays leave raid ownership intact.
Death/session release leaves the actual car in the finite raid; reconnect
cannot reissue it. Remaining raid cars retire after round insurance settlement.
Native process checks cover interruption before physical deployment, after
acknowledged extraction credit and during uncertain credit. Account parts and
nested equipment are excluded from world-save ownership with `should_save`.
Looted-car credit verifies the actual registered controller and exact current
graph, and rejects an identity already acknowledged by another account.
Occupied driver/passenger extraction now asks every seated rider for consent.
It binds their account and carried graph, unloads consenting riders at the exit,
then waits and revalidates the unchanged car, loadouts and clear private bay.
One shared receipt credits each rider's own loot and only the driver's garage
before relocating the actual car and sending each player to their own house.
Declines preserve occupied seats; cancellation after unloading leaves everyone
in the raid. This is isolated transaction evidence, not playable acceptance.

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
member is ready. Each member may authorize their own paid insurance quote instead
of uninsured readiness. Readiness reserves no money: the exact premium is debited
with that member's loadout in the shared deployment receipt. A changed quote or
physical garage invalidates deployment before any account debit.

A PMC leader may select their saved garage car for group travel. That selection
invalidates every ready vote. Each member explicitly agrees to ride when readying;
the selected car identity and exact snapshot bind that consent. Deployment checks
actual stopped-car seats and a clear raid footprint, includes the leader's garage
debit in the same shared receipt, then moves the original car and buckles the
original players into separate seats. A two-seat car cannot carry three members.
Interrupted shared deployment cannot restore a second garage car on reconnect.
Passenger return uses the same forward journal with separately validated
raid-to-home projections. Three native processes exercise eleven interruption
points for deployment and return; incomplete receipts gate all participant
accounts, and exact acknowledged return replay does not credit again.

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
consent races, readiness changes, member replacement, mixed paid/uninsured
loadouts, physical premium retirement, live access gates and independent
extraction. `--probe groups` runs three native processes across
eleven journal/account interruption points, including initial and final receipt
writes with a paid member. Its debit, visibility and forged-premium negative controls must fail at the intended
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

The original hub has a central return/voting square, west lounge, east crafting
reference room and north district briefing room. Four-tile passages connect the
rooms. The crafting desk opens the existing Crafting Atlas. Each private room
has an account-bound production tool workbench outside its car bay; nine raid
warehouses also provide shared benches. Private staged inputs and finished tools
are included in the account stash checkpoint, and release cancels pending
assembly and retires those physical items. No second world-save owner is added.
The native mode fixture verifies access, assembly and condition-preserving
account restoration; offline map checks verify connected public desks and fixed
room/bay placement. Connected-client presentation remains unverified.

Equipment graph schema 2 preserves unique identities and found-in-raid status
for each contained node. Successful extraction retains provenance; bringing
equipment into a subsequent raid clears it throughout the bounded graph.
Schema 1 graphs migrate with new identities and no invented provenance.
Only the explicitly supported material stack types preserve quantities and
default material. Jerrycans preserve approved fuel quantities and lid state;
constructor defaults are cleared before restoration. Other stack and reagent
container types remain rejected. Duplicate identities within a graph
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

A separate original Modern-city Nomads version uses the same bounded account,
shipment, gear, private hub and game-credit services. Select
`modern_city_extraction.dmm`, or compile with `EXTRACTION_MODERN_CITY_MAP`.
Ordinary Nomads remains the default compile target. The city has six apartment
blocks, wide roads, a central park with ordinary trees and food bushes, a public
workbench and water sink, eighteen finite loot containers and reactive NPCs.
Modern era baseline crafting remains subject to the existing specialist research
gates; buying gear does not complete research nodes.

The city runs for six hours. Hourly departures alternate north railway and south
bus stations, with a five-minute announcement. Click the currently named station
to reserve, then be beside it conscious at departure. Reservations alone do not
extract. Boarding checks the same account and raid sequence and synchronously
commits carried equipment before returning the actor home. A scheduler delayed
ten seconds or more skips that departure rather than awarding late extraction.
After the sixth departure's ten-second processing allowance, closing forfeits
unsent city gear and reconciles insurance. Home currency and committed shipments
remain. These stations evacuate on foot; car garage return remains available in
the short district. No active playable city is resumed across process restart.
Accelerated native tests and an absent-player negative control cover settlement;
six-hour live behavior, connected clients, survival balance and video acceptance
remain unverified.

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

The original district has 27 persistent container journals. Untouched containers
have no generated contents or journal directory. Workshop, ammunition and armory
tables use integer basis-point appearance chances (75%, 80% and 35% per slot),
explicit common/rare/exceptional weighted outcomes, one to four slots and one or
two items per outcome. A validated plan commits before constructors run; full
equipment records commit before the list becomes visible. Partial construction
retries that plan rather than rolling again. Empty results persist too.

Each warehouse also has a finite supplies container: three slots at 85%
appearance, with weighted cloth, binding cord, steel, wood and gasoline cans.
The private terminal's Supplies action exchanges one actual uninsured workshop
part for ten game credits. Fixed offers sell tool heads and handles, ten-unit
material bundles, ammunition, an AKM, PASGT helmet, carrier vest and gasoline.
Advanced gear, steel and fuel require house level two. Prices are displayed and
confirmed; the account snapshot commits both spent credits and the complete
product before delivery. Reconnecting restores that identity once. These are
prototype game prices, separate from external bot currency, without playtested
economy or connected-client acceptance claims.

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

The disabled bot transport foundation implements SHA-256 and HMAC in native DM
with two 16-bit limbs per word, avoiding inexact 32-bit arithmetic. Strict compact
envelopes match Civilizationbot's `civ13.safehouse.ipc.v1` signing bytes. Decimal
Unix timestamps are split into days and seconds before comparing the 120-second
lifetime and five-second future allowance. Canonical base64 rejects invalid
padding and nonzero unused bits; the MAC comparison visits all 64 characters.
`tests/extraction/run_crypto.py` compares production code with Python's standard
library and the bot's public synthetic signing fixture. Its negative control
changes a SHA-256 constant in a generated copy and must fail the first hash vector.
The UTC clock combines coarse calendar dates with precise `world.timeofday`,
correcting rounded dates across midnight. The clock comparison and synthetic
midnight cases are independent of envelope signing. Keys must be 32-4096 ASCII
bytes, such as an operator-provisioned random hexadecimal secret.

The disabled native service now validates exact request schemas/digests, stores
five-minute game-origin challenges, and atomically commits one-to-one account
links together with request receipts. Proofs derive from a secret HMAC domain;
only their SHA-256 digest persists. Replayed request IDs must retain the same
actor and digest. A fresh actor-bound `trade.status` request can inspect the
original receipt without repeating its operation. Saved room/stash inspection
reports a bounded eight-entry page and rejects stale revisions or raid state.
It reports the saved snapshot, not unsaved physical changes in an occupied room.
`tests/extraction/run_ipc.py` uses an independent Python signer across challenge,
processing and restart processes with temporary account storage. Removing the
proof check must fail the wrong-proof assertion; interrupted journal intents
block restart rather than rolling back account links.

No listener, spool processor, operator key or player linking interface is enabled.
An explicitly injected native economic adapter now supports game-priced buyback,
player listings, purchases and cancellation. Quotes expire after 120 seconds and
bind the linked actor, account revision, exact equipment graph, price table,
counterparty and listing revision. Listing requires raid provenance and excludes
secured or insured graphs. The shared settlement journal conserves item identities,
equipment graphs and credits across all participants. It stores the actor's
operation receipt in that same durable transaction, so a fresh signed status
request can recover the original result after interrupted projection. Duplicate
confirmation requests return that receipt without another debit or delivery.

The prototype vendor has a finite one-million-credit treasury and 64 storage
roots; market escrow has 64 roots and at most 128 listing records. These reserved
accounts cannot be opened as player accounts. Prices use the explicit
`modern_safehouse_prices_v1` game-price table and `civ13.game_credits.v1` currency,
with no external currency conversion. Active game accounts cannot participate in
offline economic mutations. Capacity, funds or revision failures retain escrow.
The equipment fixture checks signed buy/list/cancel paths, actor/action/expiry and
funds rejection, replay/status and fresh-service recovery of a pending buyback.
Its `--economic-payment-negative-control` deliberately omits buyer payment and
must fail at the purchase assertion because the shared journal rejects creation
of credits. The adapter and transport remain disabled unless explicitly wired;
the connected bot integration remains unaccepted. Current checks do not
establish security acceptance, connected bot acceptance or activation readiness.

The private terminal now offers owner-only Discord linking. Host code must
explicitly configure and enable the adapter with an ASCII key; its default is
disabled and no key file or network connection is opened. A conscious owner at
their home terminal receives a five-minute challenge only after checkpointing
their stash. The proof is shown to that player only. Connected-client interaction
still needs gameplay acceptance.

The optional native spool uses a private `data/`-relative directory and the
existing map tick, with eight directory entries per second and a 256-entry cap.
Configure exactly one native writer for a spool directory. Final reply publication
creates `<request-sha256>.reply.pending` before copying reply bytes. The bot must
wait while this marker exists, both before and after its authenticated bound read.
Marker recovery authenticates the original immutable request and requires the
matching durable operation receipt; the marker alone never authorizes a mutation
or replacement. A completed reply is never overwritten. Recovery preserves the
original signed expiry, so expired operations use a fresh read-only status query.

`tests/extraction/run_ipc.py` uses three disposable native processes and an
independent Python signer. It checks marker creation failure, partial publication,
interruption before marker removal, expired recovery, immutable completed replies
and mismatching signed markers. `--publication-negative-control` removes the
durable-receipt comparison and must fail at that exact assertion. `--output` can
export only synthetic request/reply fixtures for isolated bot compatibility tests.
Exports record the source commit and whether the checkout had local changes.
Ordinary process restart does not establish filesystem flush ordering through
power loss. The host must provision a private directory and enforce single-writer
operation before any separately authorized activation.

City Survivors receive the ordinary Nomads faction and leadership controls.
The municipal materials laboratory at (42,42) is a shared tier-six research bench:
it supplies a station, while specialist recipes still require the faction's
prerequisites, study and any prototype submissions. Progress remains round-scoped
under the existing research system. Private supplies also offer carved planks,
copper, gold research stock and kevlar at fixed game-credit prices and house
levels. Planks support the normal eight-plank research bench and gunsmithing
station recipes; gold can be crafted into the coins ordinary benches consume.
The shared laboratory avoids requiring a new bench to be upgraded through six
tiers during a six-hour city run. These prototype prices still need playtesting.
