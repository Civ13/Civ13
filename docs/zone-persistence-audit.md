# Area, level and persistence review notes

Source baseline: `58404f5bd16e3fed80f1d9844c5db3edd144942c`, 2026-10-24.
This audit uses public source and bounded offline checks. It launches no native
tests, touches no running world and reads no private payloads. Source findings,
native reproductions and full-world acceptance are distinct. These contracts
reduce risk; they cannot prevent every future spatial failure. Line numbers
below refer to this baseline.

## The #3290 mechanism

An ordinary area reference stores an anchor turf coordinate and type, not an
independently reconstructed area object
([saving.dm:186](https://github.com/Civ13/Civ13/blob/58404f5bd16e3fed80f1d9844c5db3edd144942c/code/modules/persistence/saving.dm#L186)).
Roof construction changes that turf's area. Fresh startup has the unroofed DMM
area there, so validating the reference before rebuilding the roof topology
rejected a valid saved generation. Durable area fields shared this assumption.

[PR #3290](https://github.com/Civ13/Civ13/pull/3290) projects topology only from
validated direct turf contents, explicit scalar roof settings and supported
base/climate relationships. Preflight retains exact instances or a supported
destination's proven absence. Import rechecks these, creates only a permitted
missing destination, and materializes membership before graph fields decode.
Constructors reuse the validated identity; unrelated mismatches still reject.
The fix requires neither rewriting saves nor a fresh-world fallback.

Historical evidence, not new execution in this audit:

- Reviewed head `7d9f2f3cf005ab72da3607bedc82141a7e2942a1` passed
  [CI 40043920923](https://github.com/Civ13/Civ13/actions/runs/40043920923): 120
  main native assertions and the projection-defect/cleanup-namespace controls,
  using a synthetic 8x8x2 world.
- Merged canonical build `58404f5b` subsequently imported the retained generation,
  reached ready state at 2026-10-24 00:46:41 UTC and advanced ready ticks with zero
  errors. Original backup/payload hashes were preserved. This establishes that
  generation's recovery, not every map, client appearance or future payload.
- Ordinary roof destruction restoring the exact base instance is already tested.
  Do not confuse `new area_type(turf)` with ambiguous explicit
  `new area_type()` instances, which have separate controls.

## Findings and proposed PR boundaries

### Z1: landing effects after refused movement

**Confirmed source control-flow defect; new native reproduction not run.**
[building_levels.dm:52-75](https://github.com/Civ13/Civ13/blob/58404f5bd16e3fed80f1d9844c5db3edd144942c/code/game/objects/building_levels.dm#L52)
calls `A.forceMove(below)` without checking its result, then announces a fall,
stuns a human and applies damage. Production forceMove returns FALSE before
movement when the save guard refuses a cross-z transfer (`atoms_movable.dm:145`).
Same-z entry onto open building sky can reach this callback while the downward
move is refused. The guard is intact; its caller continues side effects.
The ordinary broken-floor path already returns on setter refusal
(`code/modules/multiz/open_space.dm:202`).

Follow-up: verify success and actual final physical turf before landing effects.
Preserve normal falling and renderer/projectile exemptions. Test actual Entered
control flow with refused, successful, redirected and deleted entrants, followed
by separately admitted native callback checks. No movement/serializer wait or
automatic retry should be added.

### Z2: known cross-level and first-capture gaps

**Existing characterization, not a new discovery or a #3290 repair.**
[saving.dm:104](https://github.com/Civ13/Civ13/blob/58404f5bd16e3fed80f1d9844c5db3edd144942c/code/modules/persistence/saving.dm#L104)
checks native `movable.z`; contained atoms can have z=0 and a different physical
turf z. Per-level references reset between planes. Existing
[`BASELINE_DEFECTS`](../tests/world_save/run-cross-level.py) identifies nested and
backward foreign fields, duplicate export, multiple same-z spatial parents and
unplaced first capture. An expected failure is characterization, not repair.

Coordinate with [serializer PR #3105](https://github.com/Civ13/Civ13/pull/3105)
before duplicating traversal work. Extend its existing fixture with physical
ancestry, both traversal directions, list keys/values and durable aliases while
retaining valid local containment. Test movement after the first spatial parent
completed. Meaningful foreign relationships remain errors; only proven runtime
fields such as `original_target` use field-specific export/import exclusions.

### Z3: input-file preservation during rejected preflight

**Unguarded read sites confirmed; malformed-file byte effects unmeasured here.**
Roof planning reads required fields without first checking directory membership
([loading.dm:45-75](https://github.com/Civ13/Civ13/blob/58404f5bd16e3fed80f1d9844c5db3edd144942c/code/modules/persistence/loading.dm#L45)).
AGENTS.md and the reclaim legacy fixture already document native absent-field
reads creating null entries. The roof `missing-scalar` case supplies a wrong-kind
envelope rather than removing the field. World-nonmutation assertions do not
establish closed-file byte preservation.

Follow-up test support: remove required fields on copied fixtures, compare
directory inventory and hashes before/after rejection and after handle release.
Include version, generation, entry type, roof settings and list length. If
mutation is established, guard presence or inspect a disposable copy. Never
experiment on original recovery data or call a post-ClearMap failure atomic.

### Z4: membership and lighting integration

**Source-backed coverage gap; visual defect not established here.**
[`ChangeArea`](../code/game/area/areas.dm) at line 210 sends area Exited/Entered
callbacks. [`turf.change_area`](../code/modules/lighting/lighting_turf.dm) at line
167 invalidates window coefficients and builds/clears overlays. The inspected
tree declares them without an explicit production call joining the contracts.
Roofs use native area construction; import assigns `A.contents += T`
(`loading.dm:132`). Roofs also do explicit overlay work, and import later rebuilds
opacity/light sources. Missing textual calls do not prove native dispatch or
black tiles.

Follow up under [lighting issue #3200](https://github.com/Civ13/Civ13/issues/3200):
measure actual callback counts, coefficients, overlays and source ownership for
creation/destruction/import and inside/outside or dynamic/non-dynamic changes.
Any shared helper needs explicit import versus gameplay semantics; blindly
firing occupant callbacks while decoding can introduce another failure. Keep
this separate from client rendering and oversized-sprite
[#3225](https://github.com/Civ13/Civ13/pull/3225)/
[#3233](https://github.com/Civ13/Civ13/issues/3233).

### Z5: partial batch relocation

**Control-flow property confirmed; harmful gameplay result needs reproduction.**
[`area_teleporter.dm:75-110`](https://github.com/Civ13/Civ13/blob/58404f5bd16e3fed80f1d9844c5db3edd144942c/code/modules/multiz/area_teleporter.dm#L75)
delays and calls guarded z setters separately for area members. A missing
destination can refuse one member while others move; there is no complete
destination preflight/rollback result. This is not a save-guard bypass. Vehicle
do_move also plans destinations but ignores several forceMove results after
callbacks may redirect/retire members (`modular_vehicles/axis.dm:274-346`).

Follow up one transport family at a time: retain source/member/destination
identities, validate every destination first, and define partial-failure handling
after callbacks. Test an edge plane, contained cargo, deleted components and a
callback starting a save. Preflight alone is not atomicity. Coordinate with
[#3118](https://github.com/Civ13/Civ13/pull/3118) and
[#3082](https://github.com/Civ13/Civ13/pull/3082) for instance/extraction work.

### Z6: cover-destruction map predicate

**Suspicious source expression; native predicate/lifecycle check proposed.**
[`covers.dm:97`](https://github.com/Civ13/Civ13/blob/58404f5bd16e3fed80f1d9844c5db3edd144942c/code/game/objects/covers.dm#L97)
uses `!map.ID == MAP_BATTLE_SHIPS`, where the constant is text `"BATTLE_SHIPS"`
(`code/__defines/maps.dm:189`). It negates the ID instead of spelling an unequal
comparison. Do not infer save corruption from that expression alone. Test both
map IDs, wall/incomplete flags, paired/unpaired covers and exact restored area
identity before a focused predicate correction; retain roof-destruction positives.

### Z7: silently truncated offline source projections

**Confirmed test-harness defect on this baseline, not a live guard failure.**
[`source_adapter.extract`](../tests/save_movement/source_adapter.py) at line 18
stops at a noncomment line no deeper than the declaration. The collector's
column-zero `#ifdef CIV13_VARIABLE_OBSERVABILITY` therefore truncates operation
admission before ownership assignment/return and saved-variable selection inside
an if (`functions.dm:57,368,400,421`). Models then behave as if no save began or
produce invalid Python; production continues after its conditional block.
An import-source regex likewise stops before conditional instrumentation.

Observed offline discovery: roof-area 28 tests PASS; cross-level source 15 PASS;
save_movement 46 tests FAIL with 21 failure records and 11 errors, including
subtests. Preserve the failed result. Proposed first prevention PR: reject
unhandled directives instead of silently shortening a body, explicitly project
declared enabled/disabled branches, and check a sentinel after #endif. Keep
meaningful mutations and failing receipts; do not remove cases to get a pass.

## Guardrails for future changes

- Type, coordinate anchor and exact area identity are different. Count empty
  explicit instances; require bases; create only proven supported destinations.
- Entry/list IDs are local to a plane. Cleanup and cross-level bookkeeping use
  `(z, ref)`, never a matching numeric ref alone.
- Validate grids, graph envelopes, generation, prospective topology and durable
  area coverage before ClearMap. Restore terrain/membership before object fields,
  after_load and metadata. Full ticker import also applies round/lighting/player
  state; Load_Entry alone is not full-world acceptance.
- Preflight yields. Recheck identities at materialization and verify postconditions.
  Failure after mutation requires a recovery hold and preserved original data,
  not a blind retry or fresh world.
- Use physical turf ancestry for contained atoms. Raw loc/z/pixloc/contents/vars
  writes bypass shared movement methods. Honor refusal before side effects;
  forceMove callbacks and guarded raw setters intentionally differ.
- Preserve sleep's retained client/body through waits, transfer-time admission,
  reciprocal buckle release and final-turf check. Invalid return coordinates keep
  protection. Same-z sleep-zone transfers are blocked during load/preparation too.
- Reserve the entire target grid before yields/resizing. Existing planes and
  proposed expansion differ. Production new-z growth stays UNMEASURED/refused
  under [new-z-budget.md](new-z-budget.md); shrinking is not allocation rollback.
- Cross-z guards do not make yielding saves atomic. Same-z movement, deletion,
  creation and callbacks still need explicit first-capture/ownership policies.

## Regression matrix

Existing native means recorded #3290 evidence, not new execution in this audit.
Proposed cases remain unrun and require their normal separate admission.

| Case | Required invariant | Evidence / next step |
| --- | --- | --- |
| Fresh unroofed map, valid partial roof | Exact area/roof identity, settings and aliases | Existing native writer/reader |
| Every base turf roofed | Base durable row may be absent; prospective areas covered | Existing native covered writer/reader |
| switch_area FALSE | Preserve setting without invented membership | Existing native reader |
| Zero / one destination | Plan absence / retain exact instance | Existing native absence/identity controls |
| Duplicate including empty destination | Reject ambiguity before import | Existing native empty-instance |
| Replaced instance or filled absence | Reject changed plan, retain failure | Existing native postflight-empty |
| Missing roof, wrong base, duplicate placement | Reject unsupported projection without clearing startup | Existing native malformed modes |
| Missing/duplicate durable rows | Reject incomplete or duplicate inventory | Existing native ordinary/covered cases |
| Equal numeric entries on different z | Never spare unrelated contents | Existing native cleanup-namespace control |
| Nested aliases/list area keys | Same resolved instance, not only type | Existing native reader |
| Destruction after import | Exact base identity and paired/overlay cleanup | Existing native; rendering separate |
| Refused/redirected building-sky move | No landing effects without arrival | Z1 actual-body adapter then native |
| Missing required savefile field | Reject; inspect closed-file hashes/inventory | Z3 copied fixture proposed |
| Foreign contained target, both directions | Reject physical foreign ownership, retain local links | Z2 existing characterization |
| Same-z move after first capture | One object/parent with consistent aliases | Existing characterization; #3105 |
| Mutation during materialization yield | Detect mismatch and hold, never automatic reset | New bounded callback control proposed |
| No-turf area or duplicate explicit identity | Clear unsupported-state rejection | Existing rejection; lifecycle case proposed |
| Inside/outside or dynamic-light change | Callback, coefficient, overlay/source consistency | Z4 reuse lighting fixtures |
| One invalid transport destination | Reject before batch change or defined partial recovery | Z5 per-family fixture proposed |
| Save begins during sleep/transport wait | Recheck; preserve body and ownership on refusal | Offline coverage limited by Z7; native gap |
| Malformed proposed z expansion | No resize before validation, partial failure held | Existing dimension/budget fixture |
| Mixed generation, missing marker, wrong dimensions | Reject before ClearMap; retain backup | Existing world-save/restart fixtures |
| Directive inside projected proc | Full declared branch or unsupported error | Z7 offline correction proposed |
| Valid full import | Exact generation, complete, ready, advancing ticks, no error | Recorded retained-world acceptance |

## Checks and diagnostic discipline

Future post-modern atmosphere requirements are tracked in the
[atmosphere persistence readiness plan](atmosphere-persistence-readiness.md).
Logical zone identity, topology, authoritative inventory and safe activation
need explicit contracts beyond the roof-specific compatibility path.

Use a verified full interpreter path on Windows. These commands launch no BYOND:

```text
<verified-python> -I -B -m unittest discover -s tests/roof_area_recovery -p test_*.py -v
<verified-python> -I -B -m unittest discover -s tests/save_movement -p test_*.py -v
<verified-python> -I -B -m unittest discover -s tests/world_save -p test_cross_level_sources.py -v
<verified-python> -I -B tests/save_movement/audit_writers.py --output <review-output.json>
```

Do not present the failing movement command as acceptance. Lexical writer counts
do not establish reachability or blanket safety. Reuse existing
[WRITER-REVIEW.md](../tests/save_movement/WRITER-REVIEW.md); privileged arbitrary
admin edits are not silently added to normal-gameplay scope.

Retain build/map/dimensions, operation/stage, generation, sanitized error path/line,
expected/actual types and bounded coordinates. Use already authorized
[structured readers](variable-observability.md); their presence does not authorize
collector activation. Disabled/stale/unavailable data is not an empty result.
Keep refs, player identities and private payloads out of public issues. Inspect
copied data with a reviewed bounded tool, never by clearing unknown relationships.

Priority: Z7 restores trustworthy offline coverage, then Z1 refusal effects and
Z3 missing-field integrity evidence. Coordinate Z2 with the serializer owner,
Z4 with lighting and Z5 per transport; Z6 is a separate small lifecycle review.
[Issue #3267](https://github.com/Civ13/Civ13/issues/3267) owns scheduler work.
None of these notes authorizes a live change, collector, security change, native
execution, deployment or merge.
