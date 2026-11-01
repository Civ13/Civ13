# Matching rider cleanup during mount Destroy

Run `py -3 -m unittest discover -s tests/mount_deletion -p test_destroy.py`.
Ten stdlib-only tests project the complete production/frozen animal Destroy body.
The checked-in preimage is data; no test queries Git or starts an engine.

The guard examines the surviving rider, not the deleting animal. QDELETED is
derived from the actual qdel.dm macros: null or nonzero gc_destroyed. It does not
independently consult gcDestroyed. Current qdel admission checks both markers and
sets gc_destroyed before calling Destroy. The suite projects that admission prefix
through the marker write, then uses an inert dispatcher for the selected body.
It does not execute profiling, finalization, native del or the complete GC path.

The 48-case matrix covers matching/foreign/null pointers, missing riders, four
modern retirement-marker states and both riding flags. Additional cases verify
existing effect order, ignored parent hints, source-admission rejection of
recursive qdel, callback reassignment, direct repeated cleanup and four mutation
controls. Retiring mock riders reject mount-state reads/writes, checking guard
short-circuiting. Parent/spawner callbacks and field observations are fake effects.

This is only the ordinary mount-deletion direction. Rider-deletion reconciliation,
raw-del interception, GC hints/timing, movement, animation and AI effects are
outside this change. Native reference nulling and mounted deletion are unproven.
See [the separate current-pin native plan](NATIVE_PLAN.md); no native runner or CI
fixture step is introduced here.
