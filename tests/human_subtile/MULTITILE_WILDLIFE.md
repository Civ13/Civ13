# Multi-tile wildlife: collision and persistence contract

Status: design only. Mammoth (`/mob/living/simple_animal/hostile/mammoth`)
and T. rex (`/mob/living/simple_animal/hostile/dinosaur/trex`) declare 96x96
bounds and change `bound_x` between 0 and 64 in `update_icons()`. The current
32x32, zero-bound-offset guard remains mandatory. Subtypes and runtime bounds
changes require an exact-commit inventory. No footprint implementation or
activation follows from this document.

## State and admission

The proposed position is the engine's exact pixel anchor `(x, y, z, step_x,
step_y)`, direction, all four bound fields and relevant visual offsets. Do not
derive the physical rectangle by adding `bound_x` to the anchor: the current
[BYOND reference](https://www.byond.com/docs/ref/info.html) describes newer
`bound_x/y` behavior as subtracting those values from `pixel_w/z` for legacy
compatibility. Its applicability to the pinned 516.1688 runtime and these
types must be measured. In particular, do not assume that changing `bound_x`
from 0 to 64 moves the physical footprint by 64 pixels. Require integral,
in-map, fully supported bounds,
no transaction or external mover, and authenticated save-owned offsets on entry.
Any custom footprint or unverified facing transition remains rejected.

## Boundary crossing and occupancy

For each native 2px pulse, the swept set is the union of the old and proposed
physical rectangles over the whole displacement, including newly occupied strips,
not merely the anchor turf or final center. At a cardinal boundary crossing the
leading 2px strip can span four tile rows if vertically misaligned; every touched
cell and dense atom matters. An exact edge contact must follow the engine's native
inclusive/exclusive rule as measured by fixtures. A movement may not gain access
because a far edge or a neighboring tile falls outside the anchor's tile. Reject
movement that would touch beyond map bounds or implicitly change z. Dynamic blockers
that enter any swept strip between pulses must be considered on the next pulse.

For diagonal movement, use the complete diagonal swept region including both leading
strips and their shared corner. Test both order-sensitive corner obstructions and
adjacent blocked/free combinations; do not replace a corner with only a destination
cell check or assume an axis decomposition matches native behavior. A single
engine-authorized movement operation should own collision and event ordering; do
not issue additional fake moves merely to probe cells. If BYOND cannot provide a
collision-safe swept operation for this footprint, remain unsupported rather than
hand-implementing collision around native callbacks.

Use native `locs` and turf contents as observed occupancy; do not create nine
proxy objects to represent one actor. The existing game `/turf/Enter()` calls
its parent without consuming its return and tests `CheckExit()` only for objects
in `mover.loc`. Therefore a remote occupied turf's `ON_BORDER` exit is a
decisive game-integration case, not something the standalone engine probe proves.
`Bump()` can have asynchronous side effects and must not be repurposed as a
read-only collision validator. Apply the Caribbean boundary and map limits to
the measured complete leading edge, not only `get_step(actor, direction)`.

`Cross`, `Uncross`, `Bump`, `Entered`, `Exited`, `Crossed`, door/border checks,
blocker movement/deletion and actor callbacks must have engine-equivalent ordering
and multiplicity. A callback may change footprint, direction, actor authority,
position or target. Authenticate the entire admitted start and expected end state,
then cancel stale work if any changes; never adopt a callback teleport as an owned
anchor. Deduplicate no callback unless an exact native baseline proves it redundant.

## Facing changes

The existing icon update can change `bound_x` by 64 pixels. First measure whether
this alters physical footprint, visual position, or both on 516.1688. Where a
facing change alters the physical footprint, treat it as a transition with old
and proposed bounds and their full swept union. Validate all newly occupied space and map
edges before committing facing, bounds and movement as one indivisible transition.
If the existing `set_dir`/`update_icons` callback can expose an intermediate or
unchecked physical footprint, the adapter cannot admit that direction until an
engine-backed transition is designed and demonstrated. Never correct a failed
rotation by snapping or temporarily shrinking the box.

## Save, interactions, and LOS

The existing five-field position capsule and 2x2 restore scan do not describe or
validate a 96x96 body. An owned partial-position save capsule must preserve the anchor turf/z, exact
pixel offsets, direction, all footprint fields, a version and ownership marker.
Restore only after validating types/ranges, facing-to-bound consistency, actor
shape, destination existence, and the full 96x96 placement against current collision
state. Stage validation before mutation; on failure leave the original actor/world
state intact and report the failed restore. If native placement itself can trigger
callbacks or is not transactional, a safe rollback strategy must be proven before
support. Runtime movement owners, pending commands and pulse capabilities remain
excluded. Round trips must cover aligned and partial west/south crossings, all
facings, and occupied or missing destination cells.

Keep the existing attack range, including its existing `locs`-aware adjacency,
visibility origin and turf semantics unless
a separate design changes them. Refresh the existing LOS owner at every physical
pulse as required by current hooks, including changes to any occupied turf and
rotation, and verify that observers never receive stale or duplicate updates. A
larger collision footprint does not imply a new 3x3 visual origin. Validate contact,
reach, sight occlusion, interactions, and callback counts on both sides of each
boundary. Riding, control, pulling, restraints, incapacitation, deletion and
teleportation require safe cancellation, ownership transfer and reacquisition;
none should use an unowned legacy fallback from a partial position.

## Required evidence

The draft standalone `tests/subtile_movement/large_geometry.dme` is not included
in the game DME or existing smoke job. At one anchor it captures the engine's bound and visual fields, `locs`, turf
contents and `bounds_dist` before and after setting `bound_x` to 64, then record
native 2px attempts with blockers at fixed neighboring cells for both values.
It must not assert predicted geometry or collision results. Standalone test
objects and native `Move()` would not establish Civ13's `Enter()`, Caribbean
checks, Bump side effects, LOS, or save restoration. Keep this probe out of the
production DME and existing smoke job; compile and run only under a separately
reviewed isolated 516.1688 envelope.

The draft full-source `large_border_observe.dm` places an `ON_BORDER` exit
blocker on an observed non-anchor occupied turf for each animal and offset,
and compares direct `Enter()` calls with an anchor-turf blocker control. It
suppresses Bump side effects and is not a real movement or callback-order test.
A subsequent game-source fixture still needs a true 2px Move and complete
`CheckExit`/`CanPass`/`Move` traces for blocked and free controls in each
relevant facing. Compare those with the engine geometry probe rather than using
`Bump()` as an oracle. No geometry mismatch or unobserved callback may become a pass.

On the exact reviewed build, compare native baseline and candidate at each pulse:
cardinal and diagonal moves, all directions and `bound_x` variants, alignment and
one-pixel offsets, edges, dense turfs, border objects, closed/open doors, moving
blockers, blocked corners, concurrent rotations, callbacks mutating state, and
actor interruption. Verify the full occupied area, callback trace, LOS and attack
results, and temporary save round trips including rejected restore. Real-client
observations must separately check motion and attack contact. The proposed engine
oracle and atomicity remain unproven; these tests cannot authorize removing the
32x32 guard until the collision design has an implementation and review.
