# Leather animal tack

This adds two optional uses for ordinary leather alongside the existing armor,
Aztec torso harness and rope leash. Global recipes use the Basic Agriculture node:
a saddle costs six leather sheets and a harness costs four. Existing recipe debit,
time, skill and research handling is reused; no new crafting system is introduced.

Use a held saddle on an unoccupied living horse to fit it. Mounting and voluntary
dismounting then take 20 ticks instead of 40. Bareback riding remains available at
40 ticks; forced dismount and death penalties are unchanged. The existing leather
satchel sprite is reused as an item placeholder; no new mounted horse overlay.

Use a harness on an unoccupied, unhitched horse or cow. Attach it to the existing
carriage by the normal drag interaction. Each of the four draft slots consumes
0.5 extra hunger per movementloop instead of 1 while a compatible harness is fitted.
Unharnessed attachment, propulsion, cargo, speed and movement remain unchanged.
The existing leash item sprite is reused. This is not the human torso harness.

The animal's Remove animal tack verb places the selected item on the ground.
Unride/unhitch before fitting or removing equipment. Removal from a dead unhitched
animal is allowed. The menu rechecks current reach, actor, occupancy, exact item
containment, controller/body identity and save-admission epoch. Fit callbacks recheck those identities and
reject duplicate gear. It neither deletes nor manufactures gear.

Direct contents are the sole equipment ownership edge. There are no animal/item
back-pointers or cached numeric bonuses, so removal/deletion immediately removes
the effect and ordinary atom-content persistence carries fitted gear. There is
no custom serializer or loader assignment. Standard animal/container deletion
also deletes remaining contents; recover tack from the corpse before its decay.
Nested gear and gear on unsupported species do not supply benefits.

Source base: 492d9b7f47d14ec906d5ad8a1b52d8627dce09f7. No open tack PR or exact
saddle/harness issue was found in the current repository checks. Existing carriage
horse/cattle attachment in transports.dm supplies the harness integration; camel
back cargo and the paid rope-leash following relationship remain separate.

Offline tests execute actual selected tack procedures through the existing bounded
DM source adapter with fake inventory, movement and menu boundaries. They cover
species, empty/occupied slots, death, stale/foreign/nested/deleted items, callback
reassignment, save-epoch invalidation, removal-menu revalidation, causal omission
of a callback guard, recipes, riding/carriage wiring and actual reused DMI states.
Containment serializer checks are source contracts, not a native save roundtrip.

Compilation, native equip/remove/save roundtrip, connected-client interaction,
visual appearance and balance remain untested. The prior native testing grant
expired; this work does not start BYOND or activate anything on Gaia. Main retains
source review and publication. All new staging/evidence stays on D:.
