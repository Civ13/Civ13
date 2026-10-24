# Ordered movement discovery candidate

Original audit oracle: `978a13d526ecc891fd7e755b7d6d6add2ca720ec`.
Current reconciliation oracle/master: `5bd242bedd45494b53e2c07a4cfd0c0a1d6ce010`.
The full-file projection now pins this master so its newer persistence guards,
set_stat handling and animal retaliation code remain intact.
Issue: https://github.com/Civ13/Civ13/issues/3267 (movement discovery only).

Run offline with a verified Python executable:

```powershell
& '<Python313/python.exe>' -B -m unittest discover -s tests/movement_discovery -v
```

The two synchronous helpers mirror the existing living-list writes into an
ordered complex-animal subset. They do not infer membership from stat, remove
duplicates, use dog_mob_list, filter z, or prune geometry. All surrounding caller
guards and the full movement files are projected against immutable Git source.
The animal body intentionally retains its existing `abs(x - C.y)` calculation.
No existing feature branch is imported. The published draft remains at
`bb7595dae299b1244817a9cd6e78f69bbfb86ba1`. This local reconciliation is held
for parent review; it is not published or merged into the PR branch. The sole
textual merge conflict was adjacent guarded CI steps. Both movement and
persistence-year steps were retained, along with all other master CI/AGENTS
changes. No production conflict required manual resolution.

## Complete production mutation audit

| File | Original writes | Lifecycle |
| --- | ---: | --- |
| code/_helpers/mobs.dm | 2 | Guarded admission, removal and living/dead switches; defib uses these |
| code/game/mob/mob.dm | 2 | Constructor append at the original parent-call position; Destroy removal |
| code/game/mob/death.dm | 1 | Death removal, before dead-list admission |
| code/game/mob/living/living.dm | 1 | Rejuvenation appends before stat becomes conscious |
| code/game/mob/living/simple_animal/simple_animal.dm | 1 | Life revival appends before conscious stat |
| code/modules/admin/verbs/modifyvariables.dm | 2 | Existing stat edit death/revival, accepting the original datum target |
| code/processes/mob.dm | 2 | Deleted-mob cleanup and existing null cleanup branch |
| code/_helpers/unsorted.dm | 1 | dview removal; cannot be a complex animal |
| code/game/mob/living/carbon/human/announcer.dm | 1 | Announcer removal; cannot be a complex animal |
| code/processes/human_corpse_decay.dm | 1 | Restored dead human removal; cannot be a complex animal |

Fourteen writes total; no production alias, reassignment, Copy/Insert/Cut or
other list mutator found. Tests scan all tracked production DM and permit only
the paired helper writes. All fourteen original sites are mapped one for one;
readers other than the two movement loops keep living_mob_list. Test-only writes
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
BYOND 516.1681 compilation remains separate and has not been run for this local
candidate. Screenshots, full gameplay and runtime acceptance remain unavailable
under the explicit no-launch scope. $0; OpenDream remains paused.

## Source-only native parity packet

```powershell
& '<verified Python>' -B tests/movement_discovery/prepare_native.py --output '<new-directory>'
```

The preparer has no execution flag. It writes a new directory and refuses reuse;
its only subprocesses are read-only Git identity/diff reads. The manifest binds
the exact checkout head, dirty patch, source hashes, all fourteen write sites,
fixture hashes, oracle commit and selected control. Final review packets must
be generated from the exact committed candidate with an empty dirty patch.

The prepared 16x16x2 world contains no game startup, map, credentials or external
integration. It extracts complete production mob New/Destroy, dview/announcer
New and all membership/switch helpers. Named adapters extract contiguous death,
rejuvenation, simple-animal Life, admin-stat and restored-human membership
fragments plus both processor cleanup writes. The full original and candidate
movement discovery loops are extracted without copying their input lists.

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
offline tests; none has been compiled or run. Their native expectations remain
proposals requiring compiler/runtime review, not established engine results.

No native runner or dispatch is added to CI. The existing guarded movement step
runs the offline staging tests only. A future native run requires separate
parent authorization and a reviewed bounded runner, process/output/memory/time
limits and external listener census. Source closes the runtime port, refuses
reopening and rejects clients, but those declarations do not prove startup
listener isolation. No native workload is authorized by this packet.

The pinned master and this reconciliation both fail the same one of five CI
regression-policy tests: the introduced-PR-only saved-roof native step is not
recognized by the general guard regex in tests/test_ci_regression_policy.py.
The movement step has its existing extensive/introduced-suite guard. No roof
step, collector step or shared policy test is altered to hide the inherited
failure; parent review must resolve that separate policy mismatch.
