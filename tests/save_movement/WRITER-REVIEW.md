# Focused classification of the original direct-writer inventory

The original 325 statements are not 325 demonstrated cross-z transfers. The
inventory does not establish runtime type, physical ownership, included-map
reachability, or safety of callbacks. This is an incomplete call-path review;
unclassified statements remain an acceptance blocker.

| Risk class | Actual source evidence | Current disposition |
| --- | --- | --- |
| Arbitrary destination or saved location across input | occupations.relocate selects latejoin landmarks; admin Topic retains H_oloc/H_jobloc across input and spawn; SpawnAtFob previously detached H before prompting | Occupation location commits now use guarded helpers. Admin-only Topic/jump rewrites were removed after the user excluded those paths from required blocking. Broader occupation/caller retry acceptance remains pending. |
| Timed relationship/attachment | punishment handlers retain target while waiting; tablepush confirms a grab; bedroll completion; drone payload installation; vehicle-axis attachment | Admission precedes hanging/resting/weakening/payload links or axis state, and actual commits recheck. Source checks cover these paths; native and broader callback behavior remain pending. |
| Multi-object relocation | football reset selects per-player/ball landmarks; arena cleanup uses another area's loot turfs | Football preflights the complete batch before match/ownership changes and returns success to its caller; same-z resets remain available. Arena moves are guarded and wrestling preflights strips. Both manual and automatic arena cleaners now reject save ownership before any cleanup. A rejected automatic attempt waits for its existing normal caller cycle; no new worker or unbounded wait is created. Partial completion after unusual save-starting subtype callbacks remains a limitation. |
| Construction followed by relocation | objective spawner creates cursed treasure on src.loc and then selects a landmark | It now constructs directly at the final turf. This uses the explicit empty/new-object exception rather than moving a placed atom between z-levels. |
| Proven coordinate-local target | living.near_wall advances get_step from get_turf(src); both hitby paths use its returned turf. Tesco bag scatter uses center.z and iterates the bag's contents after removal to center | These are not arbitrary landmark teleports. Snapshot/ownership effects of unusual callbacks are not proven by target coordinates alone. |
| Checked physical containment | folder Topic requires loc == usr and P.loc == src; clipboard pen/remove paths require loc == usr and the selected item's loc == src | The selected item, container and user share physical ancestry at those immediate transfers. This is stronger evidence than an inventory-looking filename. |
| Confirmed remote UI risk, guarded locally | wand assembly bench Topic only rejects absent/lying user before eject_wood/eject_core. Its fallback directly assigns a bench part to get_turf(user), with no final proximity/z check | Bench insertion/ejection preflights admission and checks the actual setter. Human hand and equipment commits check movement success before assigning slots; the safe wrapper propagates refusal without deleting a blocked item. Already-contained same-z items retain successful no-op behavior. |
| Modal construction/layout risk, guarded locally | stack.dm mailbox color selection calls WWinput, then relocates the constructed mailbox to get_step(user,user.dir) without a final z admission check | All raw location writes in stack construction now use checked setters. The mailbox checks after the color prompt before color/overlay mutation. Creation/consumption elsewhere in the larger crafting routine remains outside a rollback guarantee. |
| Active nullspace placement and launch phases | plastique.afterattack sets loc = null after planting; projectile lifecycle has direct null assignments | Planting now rejects save ownership before dropping and checks its actual null commit after callbacks. Projectile launch/reuse placements use guarded setters. Projectile impact null assignments are terminal retirement paths immediately followed by impact/qdel, preserving callback order; this is not a global exemption for projectile teleports. |
| Creation/retirement/pooling | New constructors, Destroy/qdel, and datum_pool Prepare/ResetVars | Pool entry uses a reviewed type whitelist and cleanup; arbitrary contained players are not a legitimate new-object exception. The shared guard now rejects live contents in retired/nullspace carriers. Remaining raw pool/lifecycle writes still need their own review. |
| Non-movable data | vector_loc is a datum carrying a turf result; sound.z is a sound positioning field; image.ResetVars changes an appearance location | These do not move a player or an atom/movable between world levels. |
| Internal visibility helper | dview_mob is anchored, simulated=FALSE, removed from ordinary mob lists, and temporarily placed by dview/FOR_DVIEW | It is a runtime visibility helper, not a player transfer. Serializer/lighting use and cleanup must remain available. This is an explicit internal exception requiring review, not a global movement bypass grant. |
| Privileged admin operations | admin-only jumps, vars/list modification and arbitrary proc invocation | Explicitly excluded from required coverage by the user. The shared guard naturally affects normal movement APIs, and the admitted-save announcement warns against cross-z movement. No credential or security changes were made. |

No code is ready for deployment as universal coverage. The classified residual
risks above need review or fixes before that claim; native BYOND compilation and
engine acceptance are also still pending under the offline-only scope.

Additional concrete gameplay paths corrected locally: camel removal retains selected
items across WWinput; vehicle cargo methods retain objects across do_after; tank
autoloaders retain shell lists across spawn and WWinput; turret unloading can be
called from a stale UI. Their actual location commits now reject before ownership
removal/linking or success messages, and autoloader refusal releases is_loading.

on_mob_jump resolves to a base no-op or ghost.stop_following. The latter only
sends text and unregisters observation/list counters; the inspected unregister
bodies neither yield nor move. Admin-only changes were nevertheless removed per
the clarified scope.

The published 57f59c3e snapshot passed CI build and offline checks as verified by
the parent (run 39889062764). This newer local revision has no native compilation
evidence yet. Native gameplay fixture jobs were skipped on the published snapshot.
