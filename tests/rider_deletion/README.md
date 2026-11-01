# Reciprocal mount cleanup during rider Destroy

Run `py -3 -m unittest discover -s tests/rider_deletion -p test_destroy.py`.
Twelve stdlib-only tests project the complete current/frozen human.dm Destroy
body and its earlier same-type carbon.dm layer. The checked-in preimage is data;
tests neither query Git nor start an engine. DME include order is checked.
The targeting/living/mob/atom parent chain is an inert boundary, not executed.

The 192-case matrix covers absent mounts, matching/foreign/null ownership,
four mount retirement markers and both values of each human riding, animal ride
and stop_automated_movement flag. Retiring fake mounts reject mount-state accesses
and icon calls. Complete existing human/carbon effect order and propagated parent
hints are observed through fake exercise, corpse, global-list and qdel boundaries.
The list adapter models DM -= removing the last matching member.

QDELETED comes from actual qdel.dm macros: null or nonzero gc_destroyed, not an
independent gcDestroyed check. Actual qdel's admission prefix checks both markers
and writes the modern retirement marker before the inert dispatcher invokes the
projected human body. Tests do not execute profiling, native del, finalization,
full garbage collection or real icon/organ/exercise/corpse cleanup.

All added state writes precede update_icons and every existing cleanup callback.
Tests observe callback reassignment, icon-time mount retirement, admission-blocked
reentry and direct repeated cleanup. Synthetic assignment to a retiring human is
only a no-late-overwrite control, not a supported gameplay mounting operation.
Five negative controls demonstrate omission, lost ownership/retirement guards,
wrong-subject guarding and a late movement-flag write corrupting callback state.

This intentionally clears stale reciprocal mount state during ordinary rider qdel.
It does not intercept raw del, change parent/GC return contracts, force movement,
animate, reset offsets, retire active movement transactions or change AI logic.
Resetting stop_automated_movement is not a claim of universally resuming paused AI:
the current AI can continue combat/detection while that flag is true.
Native rider deletion, reference nulling, mounted visuals and save/load behavior
remain untested. No native fixture, runner or workflow admission is introduced;
the separate mount-deletion native proposal explicitly excludes this direction.

## Future wildlife integration seam

Wildlife confirms this source scope does not overlap its fixture. Current master
does not declare npc_subtile_pending_intent. When that feature is integrated,
invalidate the verified old_mount's pre-existing pending intent inside the
reciprocal ownership guard, before clearing ride/rider or invoking update_icons.
Never invalidate after the callback or on a foreign/reassigned owner. This is a
pending-intent invalidation seam only. An active transaction or owner retirement
needs its own reviewed path; do not infer either from these field assignments.
This slice deliberately adds no absent wildlife field or retirement mechanism.
