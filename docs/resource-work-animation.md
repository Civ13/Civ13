# Mining and chopping work images

Timed pickaxe mining and axe-family chopping use a call-local
`resource_work_animation` datum in `code/game/mob/animations.dm`. It repeats the
existing combat tool-image convention every five deciseconds: the actual held
tool icon, scaled to 75%, moves toward the work target. Only the image is
animated. Actor/client pixels, physical step offsets, glide, direction and camera
state remain owned by movement and other existing effects.

The helper refuses creation while the actor is already busy. Its bounded worker
waits without drawing until the originating synchronous caller enters `do_after`
and the busy lock is observed. A synchronous refusal or exception stops the
caller's visual companion before it can display a strike. Both callers stop it
immediately after the wait, before rewards, destruction or mining collapse can
yield; mining release also stops it before releasing its owned action state.
There is no new action timer, admission lock, actor field or change to `do_after`.

While running, the worker checks the original body/client, consciousness, tool
possession, original active hand when applicable, target, physical location and
step offsets every decisecond. Death, body handoff, removal/deletion, movement,
interruption or the original action deadline removes the owned images. Cleanup
also clears every retained actor/tool/target/client reference and is idempotent.
The visual datum is excluded from saves. It cannot release an action lock.

The existing paid waits remain `240 / strength / usespeed` for mining and
`30 * chopping_speed` for chopping. Existing yields, wear, XP and cancellation
fallthrough remain in their owning handlers. The timed chopping path no longer
uses the body-offset combat animation; ordinary instant attacks still do.

`tests/test_resource_work_animation.py` executes restricted production predicates
and worker flow using inert clocks and image clients. It checks admission,
repetition, completion, cancellation, body/tool/target loss, cleanup and offset
ownership. The exact test file runs in the normal offline baseline; its stdlib
import graph is checked by baseline policy. Only this exact offline file is
excluded from introduced-native-test selection. Other new test files retain
normal selection.

The extracted bump-mining fixture has an explicit null rendering adapter. Its
behavior checks do not establish rendering, and its old native pin remains
separate migration debt. No new native fixture is introduced here. Normal
publication selects the canonical game compile, offline baseline and evidence
checker, with extensive tests off and no daemon run. Rendering, real-client
movement, native lifecycle timing and gameplay/save acceptance remain unverified
until separately reviewed tests are authorized and run.

## Root-tree strike composition - 2026-11-03

A chopping strike formerly entered each viewer's client image list as a
foreground GAME image. The root-tree composition audit correctly treats unknown
foreground images as a reason to release the whole scene. That production path
can therefore switch every tree to native fallback during a strike; this source
mechanism is consistent with the reported flicker and canopy darkening, without
establishing the timing or pixels of the live report.

For an active root scene, the running resource-work producer now asks that
viewer's presenter to construct an owned strike. The presenter accepts only the
producer's sealed, unanimated appearance, a currently published ordinary tree,
its committed root RGB, valid plane/context ownership, and a fresh ordinary
visual decision for both worker and target. The copy keeps the tool art, scale,
offsets, layer and animation, uses the tree plane and root RGB, and receives no
mouse events. It shares the existing scene shadow with the forest. A denied or
unsettled lease suppresses only the cosmetic strike. Non-tree work and viewers
without an active root scene retain the previous native effect.

There is no foreign-image whitelist: unknown foreground images still require
fallback. Each presenter holds at most 64 strike copies. Stop/cancel, tree
withdrawal/removal/republishing, LOS invalidation and scene release remove only
owned effects. Tree frames and lighting caches remain unchanged by strike
creation. Existing blocker/destruction denial remains in force.

The focused offline tests execute production ownership, authorization, audit and
cleanup procedures, including two viewers of the same root, different committed
RGB, hidden worker/target, forged appearance, missing light/capture, cancellation
and foreign lookalikes. They do not render pixels. Native continuous-canopy,
strike layering, shadows, overlap darkness and dense-scene cost remain untested.
The fresh per-viewer geometry capture adds work once per displayed strike; no
performance improvement is claimed.

Equipping is tracked separately. On this source, the human inventory path moves
the item through forceMove; transparent-item invalidation marks nearby contexts
dirty but does not withdraw their tree frames. Hand overlays use body layer
plus 0.02, and progress bars use HUD_PLANE. The earlier unconditional Entered
invalidation is absent. These findings do not establish an equip-only cause or
claim this chopping correction resolves it.
