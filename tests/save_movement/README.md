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
ghost/admin jumps, generic storage APIs and delayed client identity checks. These
are source assertions, not execution of every entire transport procedure. Removing
the cross-z predicate or identity-owned release produces the demonstrated defects
in generated-source controls; production files are never mutated by the tests.

## Review limits and pending acceptance

- **This patch does not establish universal direct-assignment coverage.** BYOND
  raw `loc`, `z`, `pixloc`, `vars` and contents edits do not dispatch the shared
  movement methods. Audited transport paths now use guarded helpers, but legacy
  direct location writers still exist, including job/admin relocation, spawner,
  magic and many inventory/constructor/local/nullspace paths. Run
  `audit_writers.py --output <review-report.json>` to inventory residual statements.
  Their safety requires call-path review; the inventory makes no benign-type claim.
  Arbitrary administrator variable/procedure editing remains a bypass surface.
- The physical sleep area is `(1,1,1)` plus `/area/caribbean/admin`, matching the
  existing sleep destination and zombie exclusion. Humans visiting that admin
  area also stay asleep. Other maps or a narrower admin sub-area need an explicit
  map contract before changing this definition.
- Ordinary placed-to-null movement is refused while saving to prevent a two-step
  nullspace detour. qdel retirement is allowed. Already unplaced/new atoms can be
  constructed/placed; this is not an object-creation or whole-world snapshot freeze.
- Same-z movement remains available, including serializer-owned paid rack transfers.
  Existing same-z serialization consistency limitations are not repaired here.
- Spawned elevator/landing-craft batches defer while the owned save exists. Simple
  blocked teleports/falls cancel that attempt and require their ordinary retrigger;
  protected sleep explicitly offers a safe user retry. No wait was added inside a
  serializer or synchronous movement helper.
- No native compilation, gameplay, CI dispatch, live checkout change or server
  action has been performed. Before deployment, review the residual writers and
  compile the exact reviewed commit with BYOND 516.1681; the existing isolated
  world-save-operation and protected-sleep native probes remain separate pending
  acceptance. Source-only preparation of those probes is not native verification.

The feature branch is a sparse source checkout. It is not a second runtime
installation and contains no hosted server or compiled game artifacts.
