# Crew Log reader migration

Prepared independently from master
`5bf745fc202ca5cc3794b778b5a5acdb9971264f`, following the bounded-reader step
of the all-screens inventory. It does not stack on Known Languages, Ship Stocks
or Religion List. Ship Stocks edits a separate quartermaster-book block in the
same Voyage file; this patch preserves that whole block and all following code.
No overlapping active Crew Log owner was found in bounded issue/PR searches.

The original admission rule remains: Pirate Boatswain or Pirate Captain by
original_job_title, or Deputy Boatswain by current title. The roster still scans
every non-dead human in world order, including NPCs/disconnected humans and
non-pirate jobs; it is not narrowed to the ship, faction or connected crew.
Pirate becomes Sailor; other job labels retain the exact Pirate-space replacement
rule. Existing display name is used, not real_name. Names/jobs are escaped once
for classic markup and rendered as inert React text.

The existing default modern adapter supplies a labelled table and real classic
fallback. It is a snapshot: reusing the book refreshes it; manager refreshes only
recheck/send status, without scanning the world. Fresh snapshots require ordinary
physical interaction. An opened snapshot stays readable while walking, without
setting using_object or adding a movement lock. Per-window state binds the original
human and book and rechecks the role rule, so role loss, logout or transfer closes
access. Rechecking role revocation is an explicit authorization tightening over
the old detached browse snapshot; it changes no job/title assignment.

Both renderer protocols are update-only; no action route, saved/mob field,
new manager or automatic polling is added. Close disables the inherited
machine-reset callback so unrelated interactions survive. Gameplay job allocation,
role assignment, roster scope, ship inventory and other Voyage controls are outside
this patch and unchanged.

Validation is offline: component/source/bootstrap checks, TypeScript, actual
classic doT and production-bundle JSDOM. BYOND/native client, role-revocation UI,
Topic, focus, cache, movement/scroll, concurrent close and transfer acceptance are
unrun. Publication/native/deployment remain held for Main review. Future normal
PR CI reuses existing compiler/offline/frontend commands; dependency path additions
do not admit a new native fixture or broaden its resource envelope.
