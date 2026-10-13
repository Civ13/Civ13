# Extraction survival verification

The native quiet-window queue includes `run_ipc.py` normally and with each
`--receipt-negative-control action` / `--receipt-negative-control reason`, then
each `--replay-negative-control cached` / `--replay-negative-control processed`,
`run.py --probe store` and `run.py --probe mode`. Supply the pinned explicit
`--byond-bin` to every command. The new receipt/census-lease assertions are
authored but UNRUN until native permission is released. During the hold,
`--compile-only` on these runners compiles without launching DreamDaemon.

The surface mode queue also includes `--surface-negative-control escrow`,
`mail_binding` and `auxiliary_pending`. These mutate generated copies only and
must fail their exact ownership assertion. The actual escrow and sharded mail
census fixtures and all three controls are authored but native UNRUN until the
quiet window is released. Full-world/private-home replica reconciliation remains
incomplete; auxiliary completion does not authorize service activation.

The next surface source candidate adds floor-only durable home replica binding
and load freshness barriers. Queue `home_owner`, `home_graph`, `home_placement`,
`home_revision`, `world_stale` and `fresh_incomplete` controls after native release.
Bindings block admission until a future explicit retirement/unbinding handoff;
the current-world completeness gate stays false because no authoritative pre-map
constructor ledger exists. Fixtures and omission detection are native UNRUN.

Add `home_admission` and `marker_save` to that queue: the actual two-owner admission
fixture guards the bound room and physical stash, while the production native
entry round trip guards room/binding/parent-field preservation and session exclusion.
Partial binding fields always reserve the room. These assertions and omission
detection are native UNRUN; compile-only does not establish runtime privacy or save
acceptance.
`test_compile_only.py` verifies that boundary using injected subprocess results;
it does not execute native assertions. Mode covers census lease revocation and
abandonment; store covers competing writers and direct child-journal projections.

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

The component fixture now carries the configured weapon through production
`retire_corpse()` before each split outcome. It uses an injected actor and direct
DEAD state, bypassing elapsed corpse age; the mode fixture above retains actual
human death coverage. It compares the complete weapon graph across native root
release, checks the detached optic's identity and damage, and requires retirement
alone to leave the raid account revision and mailbox unchanged. Returned roots
must remain unclaimable after the loss round and account reopening, become
claimable after one additional full round, and reject repeat delivery. These new
component/corpse assertions are authored only, uncompiled and unrun while local
execution is held. Run the normal equipment probe and the existing mode corpse
release negative control after explicit quiet-window release.

The `corpse_retired` hook remains observational. It neither mints identities nor
settles a raid, grants credits, recreates gear or advances insurance eligibility.
Physical retirement preserves actual roots; `forfeit()` changes account raid
state, while the round-end return consumer reconciles per-node coverage against
all account custody. Another account's extracted component is excluded even
when the original owner's remaining weapon qualifies for return. This source
contract does not establish native execution or persistence-generation acceptance.

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

On October 13, the human selected OpenDream for the end-of-day extraction
connected-client/playable-loop target, relayed through the extraction coordinator.
Package provenance must record the exact source head, OpenDream compiler/server/
client identities, selected map and artifact hashes. Track room/hub navigation,
storage, paid progression and return/reconnect results against that runtime.
Pinned BYOND 516.1681 compilation and isolated native probes remain a separate
compatibility/evidence track; neither engine's result establishes the other's.

The BYOND launcher and account preparation below are existing verification paths,
not an implemented OpenDream launcher. This checkout has no tracked OpenDream
launcher identified in the bounded source inventory. OpenDream authentication,
account identity mapping, save compatibility and client readiness remain explicit
acceptance gaps. Do not reuse BYOND DMB/RSC or retained-run receipts as OpenDream
artifacts. Selecting OpenDream grants no launcher/startup changes, production
restart/deployment, screen control, live economy or release of queue/native/shared
implementation holds. Coordinate the current launcher owner's package before
any connected run; no such run was performed by this documentation change.

See [the OpenDream readiness audit](../../docs/extraction-opendream-readiness.md)
for the client-to-account ownership path, runtime room allocation, journal engine
contracts and prepared identity-refusal vectors. Those vectors remain uncompiled
and unrun while execution is held.

The human confirmed only one BYOND account is available. Prepare a genuine
single-account concept capture of room/hub navigation, private stash, paid
storage/upgrades, reconnect, disposable restart and idle reload where the UI
supports them. Connected access denial between two distinct accounts remains
unverified; production-path isolation fixtures provide separate evidence.
Do not create another account or use guests/synthetic identities as graphical
privacy proof. The two-account routes below remain acceptance gaps.

When two accounts become available, use distinct authenticated BYOND accounts,
labeled A and B in the recording.
Do not capture passwords, login tokens or private reference material. Admission
uses actual ckeys and rejects guests; two guest windows cannot substitute for
account isolation. Only one account is currently available; its signed-in client
readiness must be checked during the granted screen turn.

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

An ordinary second invocation creates fresh storage. For connected restart,
wait for the first owned daemon to exit, then use the same `-Visual`, `-City`
choice and pinned `-ByondBin` with `-ResumeRunDirectory <retained-run-directory>`.
This skips compilation and config copying, reuses `area.dmb`, `area.rsc` and
account storage, archives the old readiness/startup files, and requires fresh
readiness. It requires a clean matching current commit, matching map/runtime,
recorded artifact hashes, an original direct temporary directory, and no existing
daemon. It never reuses or stops a foreign process. Older manifests without
artifact hashes cannot restart through this path. The optional
`-ValidateRestartOnly` checks provenance without launching. Eight offline guard
tests in `test-playable-restart.ps1` pass using inert files; real restart/client
acceptance remains pending. No active raid resumption is promised.

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

Vehicle deployment is allowlisted to Industrial Extraction and Modern City
Extraction. Alleyway and Bank Robbery do not support the extraction vehicle
lifecycle. Solo deployment and group selection, readiness and deployment reject
unsupported missions before saving or debiting profiles or moving original cars
and riders. The vehicle and group fixtures include unchanged-state assertions
for this boundary; these new assertions await the next exclusive native slot.

The dealer's 25-salvage purchase is separate from the required player construction
feature. Construction from actual components, reachable workshop power and
progression prerequisites, and durable interrupted-build recovery remain pending.
Dealer purchase evidence must not be reported as component construction evidence.
The construction preparation adds paid level-two glass (six sheets, 20 game
credits) and cable (ten units, 30 game credits) offers. Equipment snapshots retain
their original identities and bounded quantities, including cable color. Native
assertions cover restoration without constructor merging and rejection of empty,
oversized or invalid-color cable graphs; these additions are unrun until a slot
is granted. A paid level-two standard wheel offer (40 game credits) owns one
actual unattached native wheel inside its crate. The wheel codec preserves its
separate identity and wear, rejects attached/anchored contents, and forbids
performance upgrades in saved payloads. Pending reservations remove exact native
recipe quantities from available stash and retain the full input graphs in the
account journal. Interrupted pending reservations quarantine admission; they do
not refund or recreate components automatically. Native wheel and disk-backed
reservation assertions are added but unrun. Player-facing assembly, its power
installation and interrupted-build recovery acceptance remain unfinished.

Both generated mission maps place a fixed private automobile press in each
room, outside its garage turning square. The source adapter retains native
research, recipe, action-wait and cable-power checks and journals exact inputs
before consumption. Its attachment step replaces factory template wheels with
the four actual paid wheels, retaining their identities and wear. A level-two
private generator kit costs 200 game credits and contains an empty actual
jerrycan; gasoline is sold separately. Use the kit in your room to install and
toggle its native engine, refuel it with an actual gasoline jerrycan while off,
and drag its short laid cable onto the press. Its fuel and damage are saved;
live supply, connections and callbacks are reconstructed only on installation,
with the engine off after reload. Electricity research remains required.

The equipment probe adds original-wheel substitution, missing/duplicate payment,
busy/cancel cleanup, missing power, interrupted pending-account quarantine and
generator fuel/damage restoration assertions. `--workshop-negative-control wear`
deliberately resets paid wheel wear; `--workshop-negative-control cleanup` retains
paid preview references. Both must fail at their respective ownership assertions.
All new native assertions and compilation remain unrun locally during the quiet
window. End-to-end assembly, reachable research/power and interruption/restart
acceptance remain pending; source implementation is not acceptance evidence.

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

### Shared mission-floor and vehicle map contract

`mission_z(level)` defaults to z1. Additional raid floors must be explicitly
admitted by map metadata; private homes on z2 and the public hub on z3 remain
excluded. On-foot arrival selects an admitted marker before durable deployment.
Combat, NPC extraction and proximity checks require actors on the same floor.

Vehicle support requires `vehicle_mission_supported()` plus an admitted entry
marker, a clear native footprint and an admitted exit. Maps override
`vehicle_entry_allowed(marker)` and `vehicle_exit_allowed(exit)` to restrict
road arrivals and highway departures. Solo arrival places the player on a clear
floor near the actual car; groups use the actual car seats. These source changes
await native regression runs after the quiet window is released. A larger map
may pad the unchanged private rooms and hub with inaccessible walls, provided
all z-levels share dimensions and their original coordinates are preserved.

Map size does not expand extraction budgets. Sealed containers require unique
integer IDs 1 through 64. More shelves must remain decoration unless the loot
contract is deliberately changed and verified. Raid equipment is capped at
2048 tracked nodes, NPC population at 12, and round participants at 32; the
existing 16 private rooms remain a separate admission constraint. Keep entry
and NPC marker counts bounded instead of scaling them with floor area.

A 256x256x5 map allocates 327680 turfs; 512x512x5 allocates 1310720.
Inaccessible wall padding still allocates turfs. Shared home scans remain local
9x9 scans and vehicle deployment checks a radius-four native footprint, but
these bounds do not establish whole-world startup, lighting, environment or
save costs. Larger maps require full-map startup and memory measurements and
runtime checks of navigation and extraction before scalability is accepted.

Pharmacy loot may persist only the exact medical stack types
`/obj/item/stack/medical/bruise_pack/bint` and
`/obj/item/stack/medical/splint`. Their amount must be an integer from one to
that subtype's native maximum (30 bandages or five splints). The equipment
probe checks quantity and identity round trips and rejects empty, fractional,
oversized and uncatalogued subtype payloads. These new native assertions are
pending CI and do not establish connected gameplay or medical balance.

### Exact-target cache keys (source integration)

The six catalogued keys target one map and one cache each. Native generic door
and closet keys do not recognize them. Only the exact type and remaining-use
scalar are persisted; target injection and exhausted-key payloads are rejected.
Ordinary container plans have a one-percent roll for at most one key from the
whole catalog, including foreign-map keys. Locked rewards have no key bonus.
These are implementation values, not validated balance claims.

Unlocking checks the actual carried key, map, immutable cache binding and unique
live container ID. It commits a pending receipt before consuming a physical use,
then acknowledges the unlock. Receipt or acknowledgment uncertainty quarantines
the session and cache without refund or replacement. Same-epoch acknowledged
reopens do not charge again. Pending receipts survive epoch changes and require
explicit reconciliation. Only acknowledged unlocks use the open-cache sprite.

The added catalog, codec and mode probes cover wrong targets, use bounds,
concurrent/duplicate access, receipt interruption and acknowledgment failure.
They remain unrun locally under the native hold. Full successful-extraction key
persistence, factory-construction negative controls and connected gameplay
acceptance must be established before readiness; codec output alone proves
neither extraction settlement nor gameplay. Cache placements are owned by the
stacked map PR and are not included by this shared source change.

Keyed caches retain the existing `container61`/`container62` account-style
recovery files under a map namespace:
`data/extraction_loot/maps/<canonical-map-id>/container<ID>/`. Pending receipts
in one map cannot block the same numbered cache in another. Ordinary container
paths remain unchanged. There is no automatic migration, replay or refund of
older ambiguous receipts; preserve those files for explicit reconciliation.
The native namespace probe interrupts one map's journal and checks a separate
map's same-number journal can commit; it remains unrun under the native hold.

City pursuit correction: the normal city probe checks immediate route/goal
cancellation when a visible survivor leaves, with the idle wander timer still on
cooldown. It also checks a cleared target reference cannot preserve pursuit.
Run `run.py --probe city --city-pursuit-negative-control --byond-bin <bin>` after
native release: the generated source omits cancellation and must fail only
`zombie lost perception cancels pursuit before idle cooldown expires`.
`--compile-only` checks source without launching DreamDaemon; native assertions
and omission detection remain UNRUN during the hold.

Floor-replica preparation/retirement vectors now include wrong owner, partial
marker binding, actual graph changes, exact runtime replay, restart refusal,
interrupted intent, partial root removal and interrupted retirement snapshot.
The privacy guard remains in all outcomes. Mode omission controls are
`home_retire_owner|home_retire_partial|home_retire_graph|home_retire_remove|
home_retire_restart|home_retire_prepare`; each must fail its exact named assertion. Equipment adds a
full mail page at the decimal sequence boundary and checks preservation of actual
gear and original claims. These new native assertions remain UNRUN during hold.
