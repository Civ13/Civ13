# Extraction survival verification

`run_economics.py` accepts explicit `--byond-bin`, `--php`, `--bot-root` and
`--bot-head` arguments. It checks the bot's immutable head and records runtime
file hashes, then uses its actual PHP driver against a temporary native spool.
Every step restarts the full production-source fixture with ordinary startup
disabled. It exercises quotes, escrow listing, purchase, cancellation, buyback,
immutable replay and a fresh status query after an interrupted shared receipt.
It also discovers the actual escrow listing, inspects native stable node IDs and
confirms a game-priced house upgrade. The upgrade consumes five fixture parts
and stores the original request receipt in the same account snapshot; deleting
only its temporary transport reply must recover that exact receipt without
another upgrade. The final native assertions check all wallets and graph ownership.
`--output` retains synthetic evidence in a new directory, including failures.
This does not enable the live bot or establish connected-client acceptance.

Use BYOND 516.1681 and a verified full Python interpreter path:

The native private-house terminal exposes `Inspect stash`, using the same
saved-node projection as `stash.detail`, including original IDs, parent links,
condition, found-in-raid status, material, amount and ammunition links. Native
detail access requires the owning body's physical terminal access. The mode
probe checks another account's item ID, loss of terminal access and invalid
pages. House upgrades select exact workshop-part IDs and show a final payment
quote; the shared economic part eligibility and upgrade planner reject insured
or unsuitable graphs. Native regressions check cancellation, movement during
confirmation and changed physical equipment before debit. These injected-input
regressions establish the authoritative operations, not graphical acceptance.

```powershell
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe store
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe restart
& $PythonPath tests/extraction/test_recovery.py --byond-bin $ByondBin
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe equipment
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe equipment --room-payment-negative-control
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe mode
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe mode --supply-negative-control
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe city
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe city --city-presence-negative-control
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe groups
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe groups --group-negative-control debit
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe groups --group-negative-control visibility
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe groups --group-negative-control premium
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe groups --group-negative-control car
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe groups --group-negative-control return
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe groups --group-negative-control fee
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe vehicles
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe vehicles --vehicle-loss-negative-control
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe mode --vehicle-purchase-negative-control
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe mode --vehicle-raid-negative-control debit
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe mode --vehicle-raid-negative-control credit
& $PythonPath tests/extraction/test_map_environment.py
& $PythonPath tests/extraction/check_catalog.py --byond-bin $ByondBin
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe equipment --provenance-negative-control
```

All probes use temporary storage, close their listening port and disable normal
game startup. The restart probe runs three separate native daemon processes over
one disposable directory. Its equipment entries are opaque transaction records:
it proves account journal behavior, not rendered items or full-world restart.
The equipment probe uses production item constructors and native journal files.
The mode probe uses the original map and production transition procedures with
injected client identity and accelerated action waits. None replaces gameplay
acceptance. Generated compilation files are unique and removed on completion.

The mode probe additionally checks PMC/Scav eligibility, carried/nested backpack
denial, eligibility changes during the extraction wait, actual keyed-door
unlock/close/lock state, room occupancy and lost-key rejection. Native hand
dispatch needs a client, so the fixture calls the production door switch and
leaves real click dispatch for graphical acceptance. Nested item shipment tests
cover another-account/concurrent/replay rejection, physical retirement after
commit and actual gun/optic restoration after death and journal reopen.
Private-crate checks cover owner-only deposits and withdrawals, materialized
item retirement on room release, actual gun restoration into the rebound crate,
and secured magazine retention through raid death and journal reload.
First-access loot checks cover untouched containers, deterministic appearance
and weight boundaries, incompatible types/weights, maximum quantities, persisted
empty/results, repeated and concurrent opens, exact single claims, partial
constructor retry from a committed plan, and interrupted delivery acknowledgement
with a fresh store rejecting its incomplete native journal. These tests reload
container journals within a fixed raid; they do not establish live-raid process
restart or rendered container interaction.

## Shared ownership ledger fixture

Run `run.py --byond-bin <516.1681-bin> --probe settlement` to execute three
separate native processes against temporary journals. This internal ledger moves
unchanged stored equipment graphs and conserves integer credits among at most
16 released accounts. A durable shared receipt precedes account projections;
normal service access remains gated until every projection and finalization
finishes. Restart finishes the exact forward projection from that receipt.
An initial receipt intent without its snapshot remains blocked without applying
account effects. The fixture covers interruptions around receipts, participant
writes and finalization, reentrant service access, ownership conflicts, modified
graph/payment rejection and exact replay. A 130-settlement run checks the
128-receipt history bound and six fixed journal files.

The settlement fixture uses synthetic stored graphs and injected interruption
points. The separate production equipment probe transfers a real encoded gun,
nested optic and magazine through released-account settlement, reopens the
service and reconstructs their identity, condition, serial, provenance and ammo.
Neither fixture proves multiple server writers, operating
system power-loss durability, bot authentication or live trading. Callers must
retire materialized home items and release sessions before submission. Insurance,
crafting transformations and trade adapters are not supplied by this ledger.

## Insurance ownership evidence under implementation

Industrial PMC and Scav exits open five minutes after the district starts.
Manhole and secured-room exits retain immediate access subject to their actual
backpack/key/room checks. These timings are implementation balance defaults.
Exit fees default to zero, and NPC currency defaults to zero. Configured fees
must be integer credits and are charged with successful solo extraction; unpaid
actors cannot extract. Paid party vehicle extraction charges
each consenting rider the quoted fee through the shared return journal. It
rejects insufficient funds and fee changes during consent or the extraction
wait. Native group and full-mode checks pass; defaults remain zero. Connected
client acceptance remains pending.
Vehicle-only exits reject foot extraction. NPCs have no private vehicle bay or
secured-room account, so those exits are unavailable to them; no vehicle, key,
currency or player account is invented.

NPC extraction uses local perception capped at sixteen exits, existing bounded
paths and a continuous ten-second adjacent wait. Per-round receipts cap at 128
NPCs with eight roots each and the ordinary two-MiB journal bound. Original item
graphs, fees and component identities are persisted before retiring the actual
atoms. Insurance reads these receipts even after physical retirement. An uncertain
retirement blocks recovery after restart rather than guessing success.
`--probe npc` checks actual stolen gun/optic separation, native disk reopening,
faction/time/payment/backpack/key/vehicle denial and interrupted receipts.
The corpse integration also retires a real dead human through the
production corpse record before the NPC takes the original detached gun and
optic. It checks item IDs, insurance tokens and mixed found-in-raid flags across
the drop. The focused native NPC fixture passes with a real human constructor
and normal species registry setup; it also checks the actual hand drops on death
before staging the original components for corpse retirement.

The production equipment probe also covers read-only graph projection for a
subset of surviving node identities, including a recovered nested optic and
independent components when their parent gun is recovered. References are
remapped within each surviving component; detached attachments become unattached.
Issued source evidence is unchanged.

The internal `begin_raid` interface can atomically archive selected insurance
graphs with its stash debit. Each node receives a token tied to the account,
round, raid sequence and item identity. Actual equipment serialization retains
that token. Extraction and shipment snapshots retain recovered tokens even if
their items are later consumed, and a later insured issue gets a different token.
Claims are bounded to 64 roots and 4096 nodes; recovered tokens are bounded to
4096. Invalid or full records reject mutation instead of dropping evidence.
Shared exchanges must preserve these records unchanged.

The original district house terminal offers insured PMC deployment. A confirmed
quote charges one obtainable workshop part for each reusable component, including
default sights and magazines. Parts must remain at home; ammunition is excluded.
The quoted revision and complete offer are revalidated, then premium consumption,
claim issuance and loadout debit commit together. Cancellation, stale quotes and
altered offers cannot issue claims. Insured gear and its outer containers bypass
ordinary loot expiry until the finite thirty-minute district closes. Human bodies
use the merged bounded corpse lifecycle and release their actual gear.

The mode fixture runs actual human death with a worn backpack containing an
two insured pistols and real magazines. Accelerated scalar age runs production corpse
retirement and later bones expiry, preserving the original nested gear before
another account loots and successfully extracts one original gun. Round-end
insurance returns only the unextracted damaged gun and denies delivery replay;
disk reopening retains exactly one stolen gun in the thief's stash. The thief
reuses a previously admitted fixture account, respecting the 32-participant cap.
`--probe mode --corpse-release-negative-control` omits the production root drop
in a generated source copy and must fail that integrated assertion. This is
native isolated evidence, not connected-client or elapsed-hours acceptance.

The equipment probe also uses native SKS/PSO-1 construction, paid component
coverage and production configuration removal. Three cases cover the weapon
extracting while its detached scope remains, another account extracting the
scope while the weapon remains, and both covered components remaining.
A replacement scope installed after purchase never gains coverage or returns
through the insured gun. Stable identity, damage and original FIR state survive
independent component returns. Actor construction and action waits are injected;
connected menus and elapsed crafting time are separate acceptance.

The internal return consumer journals its plan before retiring physical roots,
records retirement before applying account projections, and delivers surviving
insured reusable equipment into journaled mailbox shards of eight roots per page. Current condition and
identity survive; ammunition and uninsured nested items do not return. Claiming
mail atomically moves its graph into the stash and rejects repeat claims or a
full stash. Returns remain pending through the loss round and become eligible
only after one additional full completed round. Early closure, reconnect and
restart do not advance eligibility. Historical unstamped mail conservatively
waits another completion after its first persisted eligibility stamp. Expiration
is "to be implemented"; there is no expiration deletion.
The equipment probe checks thirteen interruption points, changed physical state,
forged tokens, 73 stored returns, finite stash capacity, legacy eligibility and generation overflow.
The insurance probe uses three separate native processes to check retirement
receipts, partial account writes, completed-round ledger recovery and replay.
Mailbox inspection reads one page and claims resolve at most sixteen selected roots
through direct identity indexes. Owner-bound authenticated cursors reject changes
and stale mailbox revisions. Legacy profile mail migrates through a durable receipt.
The equipment probe has a 120-second runtime limit for its native shard and recovery
writes. This bound does not establish gameplay performance. Its optional
`--insurance-fixture-output` exports native signed inspection replies for
`insurance_bot_compatibility.php`, which checks a separately supplied bot checkout.
Standalone store, restart and settlement probes compile production journals and
mail storage with fail-closed unused equipment/round adapters; they do not establish
native equipment or insurance acceptance.
A prepared receipt without durable retirement proof stays blocked after restart.
The mode closes at its thirty-minute deadline, warns five minutes beforehand,
forfeits stranded loadouts, checkpoints home accounts, releases sessions, and then
settles the bounded physical inventory before acknowledging round end. It caps
participants at 32 and insured issued nodes at 4096; physical tracking and return
plans cap at 2048 nodes. The house mail action commits its debit before constructing
returned objects. Mode tests inject only identity, confirmation and action waits;
they check actual paid deployment, nested expiry protection, interrupted closure,
live stranding, sheltered gear, partial recovered-parent ownership and physical
mail replay. Longer-running Nomads expiry archival, active-world restart and real
client acceptance remain pending. These fixtures do not establish graphical
insurance acceptance.

The explicit round inventory reads at most 4096 account directory entries and
indexes at most 4096 relevant claim tokens. It compares recovered tokens and
current stored identities, rejects ambiguous ownership or unresolved journals,
and gates normal account access while building. A later consumer must freeze
service access and revalidate exact profile digests and the account set before
writing a receipt. This is a read-only disk index, with no world scan, timer,
physical deletion or payout. Native tests cover a recovered old claim versus a
new issue, stored ownership without a recovery receipt, conflicting owners,
pending journals, stale inventory and access-gate release.

## Required safe-house concept video

### Connected acceptance preparation

Use two distinct authenticated BYOND accounts, labeled A and B in the recording.
Do not capture passwords, login tokens or private reference material. Admission
uses actual ckeys and rejects guests; two guest windows cannot substitute for
account isolation. Availability of both signed-in sessions remains unverified.

The existing disposable launcher is `run-playable.ps1`. Prepare the exact build,
clean source inventory and passed local regression record before requesting both
the native slot and exclusive screen lease. After those grants, use the pinned
absolute BYOND bin with `-Visual -Port 18342 -TimeoutSeconds 600`; use a separately
prepared `-City` run for the Modern city. The launcher owns only its daemon,
retains evidence and temporary storage, disables outbound game exports, and
checks runtime logs. Client windows and recording processes require separate
ownership and cleanup. Engine authentication is outside the outbound adapter.

| Route | Visible result to capture |
| --- | --- |
| Privacy and hub | A and B enter distinct rooms; foreign entry fails; empty-handed public hub visits return each account to its own room; carried gear blocks hub travel |
| Storage and reconnect | Deposit recognizable original equipment, disconnect A, reconnect A and compare contents; B cannot inspect A's private stash |
| Upgrade and idle release | Label any injected workshop parts as setup; show quoted cost, native payment and room level; show bounded idle release and preserved items on admission |
| Group and paid vehicle return | Show driver/passenger consent, real seats, separate personal returns and owner-only car/boot return; show an unfunded rider or changed quote refusing settlement |
| NPC and conditional exits | Show actual NPC loot/extraction and receipt outcome; show faction, opening time, backpack, secured-room key and vehicle-only gates using real actors |
| Insurance and components | Show paid original gun/optic, actual detach and death/theft route; recovered original components stay excluded from mail; reconnect does not advance eligibility; an additional complete round is required |
| Crafting and city parity | Show native workbench payment/completion and identifiable output; repeat privacy, stash and return routes in the Modern city, including its real NPC presence |
| Same-world restart | Stop only the owned disposable daemon, restart identical saved artifacts over the same retained account directory, then compare both accounts' items and upgrades |

Restart is a launcher gap: a second ordinary invocation creates a fresh run
directory. Prepare a verified same-directory restart path before filming that
row; a second fresh world or the three-process journal fixture cannot count as
connected restart acceptance. No active raid resumption is promised.

Computer-use preparation verified that `@oai/sky` imports through `node_repl`,
and the pinned `dreamseeker.exe` exists. No window inventory, screenshot or input
was performed. Screen access and remaining capture budget are unverified until
the exclusive lease. Bounded tool discovery found ffmpeg and ffprobe; discovery
does not prove capture or editing. Reconcile the independently owned capture
tools before use rather than replacing them with parallel infrastructure.

Keep a per-route result and source commit beside the genuine raw footage.
Edit with readable captions, retain real completion frames, label setup supplies
and accelerated waits, and remove credential-bearing frames. Review the exported
video for legibility and behavior separately from bundle metadata validation.
An unshown route remains pending; failed runtime diagnostics invalidate its run.

The mode fixture also assembles a real car and checks the internal physical
transfer helper: moving/stale vehicles, unexpected footprint/nested cargo and occupied bays
are rejected before relocation; original parts, fuel, wall condition and
steering survive a successful transfer, which cannot replay. These checks do
not establish connected-client interaction or passenger consent. The separate vehicles probe checks a committed explicit
car graph across three native processes, preserving part identities, wall
condition and tank contents, then removing ownership and rejecting stale credit.
An interrupted debit blocks access to the previous garage. Explicit offline
loss settlement discards that uncertain garage independently of an empty stash
and preserves an audit reason. The garage-retention omission control must fail
at this assertion. Ordinary acknowledged reload and explicit forfeiture are
separate outcomes; this is not production restart or playable acceptance.
The mode fixture additionally checks private-bay admission and reconnect,
fuel/damage checkpoint with the stash, moving-car save/release rejection,
blocked-bay failure before equipment construction and retirement of both
top-level parts and the nested controller. Paid acquisition checks the actual
house upgrade, declined confirmation, debit-before-construction, zero-fuel
delivery and acknowledged reconnect. Its payment-retention control must fail
at the durable stash assertion. The vehicles process probe also checks pending
construction quarantine, exact offline forfeiture binding/receipt and no
refund/recreation after a third process. Bounded boot graphs check eight-root
capacity, nested-condition staleness, part/cargo/stash ID collisions, original
atoms through physical relocation and atomic home loading/unloading.
Solo raid tests execute production debit/extraction/cancellation/damage/FIR
and forfeiture/reconnect paths. An independent looter claims the original car
and cargo only after a deliberately conflicting acknowledged garage is cleared.
Finite closure retires both top parts and nested controllers. Native processes
cover interruption before physical deployment, after acknowledged extraction
credit and during uncertain credit. Debit/credit omission controls must fail at
the intended ownership assertions. Account parts and nested equipment have
`should_save = FALSE`; this fixture does not execute a full-game vehicle world
save. Connected car driving, rider dialogs, physical transfer and playable
acceptance remain separate requirements.

The mode fixture also stages actual tool components on an account-bound private
workbench, rejects a foreign owner, executes production finishing and verifies
native account restoration of the resulting identity, condition and materials.
This bypasses the assembly wait; production timed assembly has its own component
checks. `test_map_environment.py` checks that all public hub desks are connected
and private benches leave the fixed garage anchors clear.

The integrated supplies fixture exchanges actual workshop parts, checks declined
and stale physical access, buys production head/handle inputs and restores their
identities with the spent game balance. Its retained-credit mutation must fail
at the payment assertion. Every fixed offer constructs and restores its actual
graph. Partial fuel, opened lids and stack quantities survive native records;
oversized payloads reject before construction and stacks do not auto-merge during
restoration. Ordinary pouring transfers restored gasoline into a real vehicle
tank. This does not establish connected-client purchasing or driving.

The city probe loads its separate original map and uses actual carried loadouts,
native account transactions and an injected accelerated schedule clock. It checks
earned currency, production supply purchases, reservations, early denial, present
versus absent boarding, wrong stations, delayed scheduler rejection, final closure
and shipment survival through stranding. The presence omission control must fail
when the absent account extracts. This does not prove six elapsed gameplay hours,
connected clients, map balance or resumption of an active city after restart.

Record a genuine disposable local playable world after integrated regressions
pass. Use the exact pinned build and record its full commit, dirty patch when
applicable, map dimensions, local process IDs, compiler/runtime versions and
reproduction steps in the evidence bundle. Do not use production storage or
reference material from private repositories.

| Sequence | Visible acceptance | Supporting check |
| --- | --- | --- |
| Two accounts | Distinct identities enter different private rooms; another account is denied entry | Mode ownership and room gate |
| Hub navigation | Leave gear in private room, enter shared concourse, return to bound room; gear remains | Hub transition and carried-gear rejection |
| Reconnect | Disconnect and reconnect the same account; actual identified stored items remain | Native journal plus equipment graph reload |
| Upgrade | Show cost before, completed payment, increased house level and removed payment items | Atomic upgrade and native restart |
| Idle release | Show room/session release after idle grace, then reload without item loss | Mode release/reopen |
| Local restart | Stop only the disposable local world, restart that exact build with its disposable account directory, then show retained items and upgraded level for both accounts | Three-process journal test plus integrated restart |
| Secure storage | Show access isolation, completed deposit, death and retained contents when implemented | Deposit transaction and failure controls |

Request an exclusive bounded screen turn from the coordinator only when the
build, test scripts and storyboard are ready. There is no standing screen grant.
`run-playable.ps1 -ByondBin <absolute-516.1681-bin>` compiles and checks normal
full-game startup with temporary storage and a closed listening port. Add `-City`
for the Modern city. After an exclusive screen grant, `-Visual -Port 18342
-TimeoutSeconds 600` keeps that disposable world open for a bounded capture.
The launcher terminates only its own daemon and retains its run directory,
compiler log, source provenance and runtime logs. The opt-in adapter disables
outbound `world.Export`; native BYOND engine login is still outside that hook.
Two authenticated account clients can use **Local Verification > Enter extraction
test world**. Admission uses actual client identities and production account
journals. Guest identities are rejected. The optional fixture-parts verb injects
labeled setup supplies; footage must identify this setup and cannot claim those
parts were earned. Native gameplay payments, action waits and room guards remain
unchanged. A clean startup does not establish connected interaction acceptance.
`-VehicleWorldSave` runs an ordinary world-owned car through the actual full-game
whole-world disk saver and loader, checking its exact graph, stable identities,
fuel, frame condition/orientation, controller links, live nested boot cargo and
unchanged house marker count. Encoding for comparison excludes account vehicles
from world saves by design; this fixture explicitly restores world ownership
before saving. Account-owned garage vehicles use their separate account journal
checks. No connected sessions are present, and old queued garbage atoms are not
counted as live restored duplicates. This does not authorize production loading.
Use readable captions and zooms/highlights. Compress no-frame-change waits and
label accelerated periods; preserve genuine completion and before/after frames.
Do not claim unshown mechanics, production behavior or indefinite durability.
Record blocked flows explicitly rather than substituting mock images.

Reuse the independently owned PR 3083 capture tools after they merge; do not edit
that owner's active capture infrastructure. Authorized evidence uploads still
need attachment-access verification before any local generated media deletion.
Respect later retention instructions. Validate the bundle with the repository's
game-evidence checker, then review the actual video separately: bundle validity
only establishes metadata and file consistency.

The combined `--probe mode` fixture has a 120-second runtime limit because it
also retires and reopens actual native home inventories during market sales,
escrow listings, purchases and cancellation, alongside the existing equipment,
group, vehicle and round tests. Other isolated probe phases retain 60-second
limits. Native market checks cover conserved wallets and original IDs,
condition/FIR, private receipts, party retention, replay, duplicate/unknown
payload rejection, foreign listing cancellation and unfunded settlement.
These fixture calls do not establish connected modal UI acceptance.

The city fixture also exercises its separate zombie population from actual map
markers, with twelve active actors maximum and one spawn attempt per thirty
seconds. Native zombie appearance/limbs and melee remain inherited. Local AI
decisions run at most every two seconds, idle wander goals every ten seconds,
with seven-tile perception and thirty-two-node path searches. The fixture checks
physical street wandering, visible raid actors, private-home exclusion, spawn
cooldown and corpse expiry alongside shipment/evacuation/stranding contracts.
This is accelerated fixture evidence, not connected combat or elapsed city play.
