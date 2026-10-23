# Save movement and physical sleep guards

Run offline, without BYOND, network access or game compilation:

```powershell
& C:\Users\valza\AppData\Local\Programs\Python\Python312\python.exe -B -m unittest discover -s tests/save_movement -v
```

`source_adapter.py` executes complete selected production procedures in a small
audited DM-to-Python projection. Engine location ancestry, contents and callbacks
are injected boundaries. Unsupported syntax fails preparation. This establishes
source control flow, not DM compilation, native physics or connected-client behavior.

The regression cases cover the actual save admission/owner/finish/backend and
cleanup bodies, success, false-return cancellation, exceptions including cleanup
exceptions, overlap/reentry, stale completion, and load recovery. Movement uses
actual `forceMove`, raw-location helper and z helper bodies, with nested containers
whose contained player has native z=0. Same-z paid-item transfers and qdel detachment
remain available. Sleep entry/return bodies exercise busy retries, save-starting
callbacks, invalid in-zone return coordinates, physical containment without an
inducedSSD flag, natural sleep decrements, forced sleeping/stat setters and safe exit.

Source checks also inspect Move/turf admission, callback-time stairs, elevators,
landing craft, area/bump teleporters, both ladder families, sky/broken-floor falls,
ghost jumps, generic storage APIs and delayed client identity checks. These
are source assertions, not execution of every entire transport procedure. Removing
the cross-z predicate or identity-owned release produces the demonstrated defects
in generated-source controls; production files are never mutated by the tests.

## Review limits and pending acceptance

- **This patch does not establish universal direct-assignment coverage.** BYOND
  raw `loc`, `z`, `pixloc`, `vars` and contents edits do not dispatch the shared
  movement methods. Audited transport paths now use guarded helpers, but legacy
  direct location writers still exist in magic and many
  inventory/constructor/local/nullspace paths. Occupation location commits and the
  identified objective spawner have since received focused corrections. Run
  `audit_writers.py --output <review-report.json>` to inventory residual statements.
  The inventory makes no blanket benign-type claim or open-ended acceptance gate;
  concrete findings and finite pending acceptance are recorded in WRITER-REVIEW.md.
  Administrator-only jumps, variable editing and arbitrary procedure invocation
  are explicitly outside the requested coverage after the user scope clarification;
  they are not acceptance blockers for normal gameplay. The save announcement
  warns admins to avoid changing levels until completion.
- The physical sleep area is `(1,1,1)` plus `/area/caribbean/admin`, matching the
  existing sleep destination and zombie exclusion. Humans visiting that admin
  area also stay asleep. Gaia's source map has exactly four such black-wall cells
  at (1..2,1..2,1). An admin-jumped human without inducedSSD receives no invented
  return coordinates: Wake Up refuses it; authorized movement can take it outside
  the area after saving, where normal waking resumes. Other maps or a narrower
  admin sub-area need an explicit map contract before changing this definition.
- Ordinary placed-to-null movement is refused while saving to prevent a two-step
  nullspace detour. Empty retired atoms may detach but cannot re-enter a level
  during saving. Nullspace carriers with live contents cannot be placed. Empty
  new atoms may be placed; creation is not a whole-world snapshot freeze.
- Same-z movement remains available, including serializer-owned paid rack transfers.
  Existing same-z serialization consistency limitations are not repaired here.
- Elevator/landing-craft activation rejects active saves. Spawned transfers cancel
  at callback time if saving, release controls and require a normal retry. There
  are no unbounded save waits or success announcements after a refused move. Simple
  blocked teleports/falls cancel that attempt and require their ordinary retrigger;
  protected sleep explicitly offers a safe user retry. No wait was added inside a
  serializer or synchronous movement helper.
- Sleep transfer admission checks both the active save owner and the existing
  legacy load/recovery hold. It rejects same-z sleep transfers too, even if the
  compatibility flag is false while the owned operation is still present.
- No native compilation, gameplay, CI dispatch, live checkout change or server
  action has been performed. Before deployment, review the residual writers and
  compile the exact reviewed commit with BYOND 516.1681; the existing isolated
  world-save-operation and protected-sleep native probes remain separate pending
  acceptance. Source-only preparation of those probes is not native verification.

The feature branch is a sparse source checkout. It is not a second runtime
installation and contains no hosted server or compiled game artifacts.

## Transient throw target follow-up

`test_throw_target.py` executes the production runtime policy, changed-variable
selection and complete throw completion body through explicit engine adapters.
It covers a stale foreign target, preserved amount/location, unchanged active
throw state, inherited exclusions, and impact/Entered callbacks setting a newer
target. Loader source checks verify that the runtime gate precedes both historical
decoding branches; these are not native disk-import results.

`prepare_throw_target.py --prepare-only` stages the real serializer/loader and
complete throw procedures in the existing 3x2x2 isolated world. The prospective
disk fixture exports a 731-unit marble stack, injects an invalid historical target
envelope, checks both typed and flat historical imports, saves/loads the roofbuilder
independently, and checks active export plus reentrant target preservation. Stack
type declarations and rendering/impact effects are minimal adapters; full material
constructors and gameplay are not exercised. Preparation has no native launch mode.
Native compilation/runtime remain unrun while live recovery is in progress.

Saving automatically omits the known process-local `original_target` field through
the existing `persistence_runtime_var` policy, on export and historical import.
The bug is the retained throwing pointer, not the roofbuilder it references. Saving
does not clear that live pointer, interrupt an active throw, change stack amounts
or locations, or delete the target; the roofbuilder remains independently saved.
Only normal throw completion clears its old pointer before callbacks can start a
newer throw.

This is a field-specific policy, not generic repair by deleting relationships.
Valid saved relationships still reach the serializer. Unknown or authoritative
cross-level links remain selected and fail the existing integrity check, with a
bounded `last_save_reference_failure` diagnostic and no completed-save marker.
They require diagnosis rather than silent data loss. Offline tests exercise
changed-field selection and pin the rejection/diagnostic source ordering. The
prospective native fixture also contains same-level relationship alias round trips
and an actual full-save rejection/cleanup case for an unknown foreign relationship;
these disk and failed-save cases have been prepared but have not run.

The repair excludes only `original_target`; cross-level validation remains active.
Target cleanup runs before callbacks. Existing later throw bookkeeping is unchanged;
this follow-up does not establish general reentrant throw scheduling correctness.

The current local revision also guards remote wand-bench ejection, inventory
slot assignment/refusal results, post-prompt construction, camel pack removal,
vehicle cargo installation/removal, tank autoloader selection/unloading and
projectile launch placement. Active plastique planting rejects an admitted save
before dropping equipment and rechecks after drop callbacks; it preserves the
normal nullspace placement outside saving. Terminal projectile-impact null writes
retain their immediate qdel/callback ordering rather than being treated as launches.

Deletion tests execute the production qdel ownership prefix to its post-Destroy
profiling boundary, the complete movable Destroy body, and closet dump_contents.
Queueing/hard deletion and native list iteration remain adapted boundaries. No
movable subtype was found returning LETMELIVE; the repository occurrence belongs
to weak references. Arbitrary runtime errors or unsupported subtype changes still
require native acceptance.
