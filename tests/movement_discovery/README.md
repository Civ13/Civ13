# Ordered movement discovery candidate

Pinned master: `978a13d526ecc891fd7e755b7d6d6add2ca720ec`.
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
No existing feature branch is imported. This is an uncommitted local candidate;
publication and acceptance belong to the parent review.

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
remains unverified. A future separately authorized native fixture should compare
callback removal/addition, deletion/nulls and nested movement against the pinned
original before runtime parity is accepted. No compiler, daemon, client, port,
credential, OpenDream, live Gaia, merge or deployment action was used.

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
