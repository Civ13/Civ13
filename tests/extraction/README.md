# Extraction survival verification

Use BYOND 516.1681 and a verified full Python interpreter path:

```powershell
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe store
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe restart
& $PythonPath tests/extraction/test_recovery.py --byond-bin $ByondBin
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe equipment
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe mode
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

The internal return consumer journals its plan before retiring physical roots,
records retirement before applying account projections, and delivers surviving
insured reusable equipment into a bounded account mailbox. Current condition and
identity survive; ammunition and uninsured nested items do not return. Claiming
mail atomically moves its graph into the stash and rejects repeat claims or a
full stash. The equipment probe checks nine interruption points, changed physical
state, forged tokens and mailbox capacity. The insurance probe uses three separate
native processes to check retirement receipts, partial account writes and replay.
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
