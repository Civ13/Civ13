# Pointer classification regression

Run with a verified Python interpreter:

```powershell
& $PythonPath -B -m unittest discover -s tests/persistence_pointers -v
```

This is an offline source contract. It does not launch BYOND or send messages.
The bounded baseline CI registry runs it for the declared impact paths, without
changing existing native admission. `inventory.py` prints file/line/type/owner
for the 28 typed atom-pointer declarations in the ten #3407 audit modules.
`classifications.json` records every scoped field, including unsaved owners and
deliberately retained links. New or changed declarations require review.

`runtime` fields are tested against complete production hooks with parent
delegation. The ancestor hook is an injected boundary; separate source guards
forbid global exclusions of ambiguous target names. Mutation controls remove a
target exclusion and a parent call. AI target exclusions also omit dependent
stance, movement and path state, so a newly imported mob starts at its type's
initial AI state. Export never resets live targets or stance.

This is a bounded declaration audit, not exhaustive pointer discovery. It does
not resolve arbitrary DM aliases or `parent_type` changes, block-style vars,
other files, untyped fields, list contents or dynamic writes. Type inheritance
and parent hook delegation still need compiler/native coverage. In particular,
the untyped human `laddervision` is reviewed separately and explicitly excluded;
mob `actions`, `grab_list` and `grabbed_by` are excluded list indexes. Grabs and
actions are whole unsaved graphs, including their reciprocal owners and HUDs;
legacy imports reject these types before running constructors.

`tests/world_save/full_game_probe.dm` adds a real-frog regression to the existing
isolated full-game runner. A target moves from z1 to z2 while the frog retains
its AI/last-attacker pointers; a real `ticker.savemap()` must succeed. A separate
disk-backed export verifies omission without live mutation, and a legacy
dangling reference plus attack stance must be ignored on import. The probe
subtype only disables Life to prevent incidental target reacquisition during
yielding saves. It uses real constructors, movement and persistence. Compile it
with the existing full-game runner's preparation, or a DME that includes
`civ13.dme` and this probe. Running it needs separate authorization for the
existing isolated trusted DreamDaemon; compilation is not a runtime pass.

No production saves, daemon, client, external message or server operation is
part of this offline suite.
