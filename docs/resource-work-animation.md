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
