# Ordered movement discovery candidate

The two historical observer-loop excerpts in fixtures/ come from
bc7209b23d4ee39651a736a7a9ddb1d1081166ac; they are independent ordered
callback, RNG and geometry oracles. The current registry inventory and lifecycle
guard excerpts audit source revision 5015ab8f495a1d33938005c8a6583c30c7175e12.
The offline suite does not read Git history or regenerate its own expectations.
Issue: https://github.com/Civ13/Civ13/issues/3267 (movement discovery only).

Run offline with a verified Python executable:

```powershell
& '<Python313/python.exe>' -B -m unittest discover -s tests/movement_discovery -v
```

The two synchronous helpers mirror the existing living-list writes into an
ordered complex-animal subset. They do not infer membership from stat, remove
duplicates, use dog_mob_list, filter z, or prune geometry. Compare exact
observer-loop bodies to the frozen legacy excerpts, with only the collection
change and the declared base_type comparison normalized. The animal body
intentionally retains its existing abs(x - C.y) calculation. Check each
current registry reference against a reviewed inventory by file and owning
procedure; check admission, death/revival, and cleanup ordering in separately
reviewed contiguous guard fragments. Unrelated code no longer needs to match a
historical whole-file snapshot.

## Complete production mutation audit

| File | Current call sites | Lifecycle |
| --- | ---: | --- |
| code/_helpers/mobs.dm | 2 | Guarded admission, removal and living/dead switches; defib uses these |
| code/game/mob/mob.dm | 2 | Constructor append at the original parent-call position; Destroy removal |
| code/game/mob/death.dm | 1 | Death removal, before dead-list admission |
| code/game/mob/living/living.dm | 1 | Rejuvenation appends before stat becomes conscious |
| code/game/mob/living/simple_animal/simple_animal.dm | 1 | Life revival appends before conscious stat |
| code/modules/admin/verbs/modifyvariables.dm | 2 | Existing stat edit death/revival, accepting the original datum target |
| code/processes/mob.dm | 1 | Deleted-mob cleanup; null/nonliving entries are filtered before it |
| code/_helpers/unsorted.dm | 1 | dview removal; cannot be a complex animal |
| code/game/mob/living/carbon/human/announcer.dm | 1 | Announcer removal; cannot be a complex animal |
| code/processes/human_corpse_decay.dm | 1 | Restored dead human removal; cannot be a complex animal |

Thirteen current calls to the paired helpers; the removed processor null branch
is historical, not new coverage. Tests scan production DM for list references
and helper calls (including the living/dead wrappers and defib call);
unreviewed readers, aliases, reassignment, extra calls or list mutations fail.
Readers other than the two movement loops keep living_mob_list. Test-only writes
in hud_visual (human only), process_snapshot_ownership (standalone stub registry)
and the season_transition generated human control remain separate test adapters.

Appending retains duplicates and order. Removal uses the original helper's
Remove return, and matches subtraction's documented last-match semantics
(`tests/processing_list_removal/README.md` records existing native evidence).
Thus `[animal_a, human, animal_b, animal_a]` becomes `[animal_a, animal_b]` in
the subset after one removal of animal_a, then appends animal_a at the tail on
re-admission. Dead constructors, duplicate calls and restored stat anomalies
retain the original admission behavior; the subset tracks membership, not a
new definition of alive. Explicit destruction remains at the original hook.

## Offline evidence and limits

The helper interpreter accepts only the selected production vocabulary. Movement
translation preserves condition order and short circuiting, with deterministic
RNG tapes and callback/knowledge traces. Comparisons include duplicate/self
entries, re-add order, death/revival/removal writes, 5,000 mixed lifecycle
operations, absent removal and return values, empty populations, cross-z and
distance boundaries, same/different/missing base_type and draws inside callback
adapters. Controls reject omitted transition/maintenance writes, duplicate
suppression, front removal, dog-only membership, changed RNG and a new z gate.

Iteration, callbacks, RNG, native object reference clearing and last-match
removal are explicit Python adapters. Source checks preserve original lifecycle
guards; they do not execute full constructors, death, Life, admin input, defib,
custom saves or GC. Null reference clearing is modeled independently in both
lists and surviving animal order compared; this is not native deletion evidence.
In particular, mutation/reentry/yield while native movement iteration is active
remains unverified. The source-only packet below prepares these comparisons;
preparation does not close native acceptance. No compiler, daemon, client, port,
credential, OpenDream, live Gaia or deployment action is part of this work.

Candidate-entry counts per movement pass, for each of the two original loop
shapes, with identical callback/RNG output in the adapters:

| Unrelated humans | Complex animals | Original entries | Subset entries |
| ---: | ---: | ---: | ---: |
| 0 | 0 | 0 | 0 |
| 1,000 | 0 | 1,000 | 0 |
| 0 | 32 | 32 | 32 |
| 1,000 | 32 | 1,032 | 32 |

These are operation counts, not timings, native profiling or server performance
claims. Maintenance adds one type check per living-list mutation and a second
append/removal for complex animals; no cost comparison is claimed. The new CI
step is offline and uses the existing introduced-suite/extensive guard. Ordinary
BYOND compilation is separate from staging and offline adapter evidence.
Historical frozen Windows fixtures remain historical; the repaired packet is
not compiled or executed by the suite. No real-client or native acceptance is
claimed by these checks.

## Source-only native parity packet

```powershell
& '<verified Python>' -B tests/movement_discovery/prepare_native.py --output '<new-directory>'
```

The preparer has no execution flag. It writes a new directory and refuses reuse;
its only subprocesses are read-only Git identity/diff reads. The manifest binds
the exact checkout head, dirty patch, production-reference source hashes, the
thirteen-site inventory, frozen oracle and guard fixture hashes, and selected
control. Git is consulted only for the active checkout's provenance; semantic
checks run from the files on disk. Final review packets must
be generated from the exact committed candidate with an empty dirty patch.

The prepared 16x16x2 world contains no game startup, map, credentials or external
integration. It extracts complete production mob New/Destroy, dview/announcer
New and all membership/switch helpers. Named adapters extract contiguous death,
rejuvenation, simple-animal Life, admin-stat and restored-human membership
fragments and the sole processor cleanup's membership write. The native
nulling case calls the list helper directly, not an obsolete processor branch.
The frozen legacy and extracted candidate loops iterate without copying their
input lists. Unrelated agent/HUD bookkeeping is an inert fixture adapter.

Parent movement returns through a fixture stub, probability calls use a logged
deterministic tape, human constructor bookkeeping is adapted, and native Del
explicitly invokes the actual Destroy body through a fixture adapter. Client,
HUD, ghost and other unrelated effects are inert. The tiny membership fragments
do not execute complete death/Life/admin/restore/defib or real game GC paths.
set_stat is an adapter, so protected-sleep enforcement is not tested here.

`native_expectations.json` defines the exact acceptance contract. Each of two
loop shapes runs the legacy and candidate paths for sixteen cases: plain,
duplicates, different base type, far/cross-z geometry, existing x/y policy,
knowledge insertion, removal of an unrelated human/current/next animal,
append during iteration, deletion of current/next/duplicated animal, bounded
reentry, and yield with removal/append. One lifecycle record plus 32 complete
paired records are required. Main dispatches total 64, with one nested level
allowed; ordered trace length is capped at 256 per scenario.

For every pair, the entire ordered probability/callback trace, surviving member
order and knowledge arrays must be byte-equal under native JSON serialization.
Stable/reentry cases additionally have literal event arrays, and every case has
an exact final member sequence. Native-dependent mutation cases intentionally
do not guess whether the engine snapshots or repairs an active iterator: their
exact legacy trace is the oracle, and any candidate difference fails. Full raw
traces must be retained and reviewed; passing only final membership is invalid.

The fail-fast controls have these required first failed assertions:

| Prepared control | Required first failure |
| --- | --- |
| missing-add | lifecycle.constructor-complex |
| missing-remove | lifecycle.guard-remove |
| deduplicate | lifecycle.duplicate-append |
| reverse-order | lifecycle.constructor-second |
| same-z | parity.human.plain |
| rng-order | parity.animal.plain |

`fixed` requires all 33 records, zero failures and no compiler/runtime diagnostic.
A missing record, timeout, wrong control failure, or error before its intended
assertion is not accepted. All seven variants are prepared and hash-checked by
offline tests; no native result is established. Their native expectations remain
proposals requiring compiler/runtime review, not established engine results.

No native runner or dispatch is added to CI. The existing guarded movement step
runs the offline staging tests only. A future native run requires separate
parent authorization and a reviewed bounded runner, process/output/memory/time
limits and external listener census. Source closes the runtime port, refuses
reopening and rejects clients, but those declarations do not prove startup
listener isolation. No native workload is authorized by this packet.

Historical validation at master 5bd242b and published b252e3d failed one of five
CI-policy checks because its regex did not recognize the introduced-PR-only roof
guard. The retained failure is not relabeled. Current master includes the #3295
policy fix; this integration changes no shared policy tests or native guards.

The old Windows attempt under reservation 3140b230 has UNKNOWN execution outcome
and NOT_PROVEN program-owned cleanup. Its resource reservation was retired only
after the verified host reboot. Frozen packets and evidence remain unchanged;
their embedded October 24 deadline has expired. No native test is authorized by
this integration, and no fixture/full-game acceptance follows from it.
