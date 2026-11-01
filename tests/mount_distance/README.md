# Separated mount ownership

Run `py -3 -m unittest discover -s tests/mount_distance -p test_distance.py`.
The stdlib-only suite projects the complete uniquely anchored riding-distance
branch from human Life, including every nested instruction. Its frozen preimage
is checked-in data; tests do not query Git or launch BYOND.

Nine tests cover 48 admission/owner/retirement combinations, reciprocal cleanup
and exact effect order, movement callback reassignment to another/same mount,
foreign ownership, mock retirement, icon callback transfer/reattachment/partial claims,
and unchanged handling of forceMove's return. Four mutation controls remove
owner binding, same-mount protection, retirement checks or the post-icon check.

Current production forceMove(H.loc) targets the human's existing location. The
base movement procedure checks save admission then returns FALSE for this same
location; human wrappers retain that result. This slice preserves that call,
range and human-clear ordering. Horse update_icons currently has no yielding
game-code callback. Artificial movement/icon callbacks test ownership robustness;
they are not evidence that those reassignments occur on the current native path.

Range, movement, icons and QDELETED are explicit fake boundaries. Retired mock
animals reject property accesses, but no native qdel/nulling/GC timing, rendering,
AI cadence, save round trip or general movement/control safety is established.

Production touches only human distance cleanup. Keep the merged death tests and
wildlife's separate pending-intent invalidations. npc_subtile_pending_intent is
absent on this base. On integration, clear that old mount's pending intent inside
the verified ownership transition, before clearing ride/rider and before
update_icons. Never clear it afterward or on a different owner: callbacks may
have installed a new intent. This suite does not introduce that mechanism.
Resetting stop_automated_movement is only one flag change; it does not establish
that a fully paused or otherwise ineligible animal will start moving.
