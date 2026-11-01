# Mount death cleanup

Run `py -3 -m unittest discover -s tests/mount_lifecycle -p test_death.py`.
This stdlib-only suite projects the complete riding death procedure and the
unchanged human unlink/character-return guards through the existing source
adapter. The checked-in preimage is data; tests never query Git or launch BYOND.

The 48-case matrix compares all existing effects/flags and parent/default-return
behavior. Only an owned rider back-pointer changes. Cases cover non-rideable and
missing riders, null/owned/other links, both riding flags and parent returns.
Focused tests verify callback observation before forceMove, a transfer during
that callback, parent withdrawal, repeated death, unchanged guard restrictions,
and omission/unconditional-clear/late-clear mutation controls.

Messages remain opaque at the mock output boundary. Parent death, native movement,
animation, weakness and overlays are inert effects. Character-return tests use
an already valid destination; no world/save files are read or written. These
tests do not prove native scheduling, qdel/reference nulling, collision, visuals,
save round trips or general rider/force-movement behavior.

Production changes are limited to death's matching-link clear. Distance cleanup,
Destroy, movement engines, serializer and return guards remain separate work.
Wildlife's unpublished npc_subtile_pending_intent invalidations must be retained
when that owner's work is later integrated; this slice does not duplicate them.
