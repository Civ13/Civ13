# Free movement and modifier-held precision movement

Plain direction keys slide freely by default: `startmoving*` and the
movementMachine pass `FINE_STEP_FREE`, which `client.Move` turns into a held
slide (below) when the body can slide (`human_subtile_fine_ready` and no trench
edge ahead, `human_subtile_trench_near`), and into an ordinary tile step
otherwise (driving, trench edges, linked or posture states, non-humans). The
body stops where the key is released, with no tile snapping. There is no player
toggle back to tile walking. Pulling slides too: `human_subtile_pull_follow`
steps the pulled object onto the uncovered neighbouring tile nearest the body
whenever a gap opens, so it trails round turns. Confusion picks a random
cardinal direction for 40% of slide steps instead of forcing a tile step.

A blocked slide tries Graal-style sliding before it stops
(`human_subtile_slide_attempts`): a diagonal runs along a wall on whichever axis
is free, and a straight move that clips a corner shifts sideways 2px per pulse
toward the open tile ahead (a doorway), or toward the nearer alignment when it
is within 12px and both tiles look open. Native collision judges every attempt;
a sideways shift does not count as travel along the step.


Hold Alt and press an arrow (either macro mode) or WASD (hotkey mode) to move
by offset instead of by tile. Alt+numpad diagonal direction keys move diagonally.
Unmodified directions keep the existing alignment movement. Alt+L remains LOOC.
Smooth movement must be enabled (including default activation).

A press (`ALT+key` -> `.fine-offset-start`) nudges 2 pixels at once. If the chord
is still held after `FINE_OFFSET_GLIDE_DELAY` (0.1 s), the movementMachine slides
the body at the ordinary walking/running pace: each held step covers one tile's
distance from wherever the body is, in sixteen 2px pulses on the same admitted
interval and held-key chaining as ordinary smooth walking, without stopping at
alignments. Releasing the chord (`ALT+key+UP` -> `.fine-offset-stop`, or the plain
key-up if Alt was let go first) clears the held axis; the running step sees it
before its next pulse, stops, and the unused part of its interval is not kept
as a cooldown. Precision input therefore no longer depends on OS key repeat
(about 0.5 s initial delay) or a tick-floored 2px step (about half walking speed).

The held axes are the same `movement_northsouth`/`movement_eastwest` used by
ordinary held keys, plus `mob.movement_fine`. Ordinary direction presses and
logout clear `movement_fine`, and key-up uses the existing stop verbs (including
drone/turret stop hooks), so release, logout and body handoff end a slide exactly
as they end held walking.

The existing client admission, native one-use pulse authority, collision chain,
offset normalization and completion hooks remain authoritative. No `pixel_x/y`
visual displacement or forced placement is used. Blockage does not refund costs.
Pulling, linked states, posture movement, driving, confusion and unowned legacy
offsets refuse precision input rather than falling back to a tile move.

A nudge costs 1/16 of a tile input (nutrition, water, stamina, run warming) and
its delay is scaled by 1/16 with a minimum server tick. A held slide costs one
ordinary tile input per step. Precision does not accelerate run velocity and does
not perform tile stomps, avoiding rapid boundary-oscillation attacks.

An ordinary (unmodified) step from an interrupted offset travels only to the next
alignment. Its delay is scaled to that share of a tile and its pulses are spread
over the shorter interval, so it moves at the ordinary pace instead of covering
the distance at once and then waiting out a whole tile's cooldown.

## Dependency and verification

**Integration hold:** this branch starts at ef3faa6b. Its `los_context.dm` rejects
nonzero offsets. Review/integrate with the separately maintained offset-aware LOS
fix (#3424); do not merge this feature alone ahead of that compatible fix. This
change does not modify LOS or activate/deploy any server feature.

`python tests/human_subtile/test_fine_offset.py` covers all 32x32 offsets in eight
directions and their reverses by translating the production integer normalization
block, plus a broken-wrap negative control, pulse/cost/authority/macro/save source
contracts. This is offline projection, not execution of native Move/collision.

Full offline suite: `python -m unittest discover -s tests/human_subtile -p 'test_*.py'`.
The shallow/local object store lacks historical blobs used by pre-existing
crafting/NPC tests. Baseline ef3faa6b has six such errors; candidate has five after
replacing an obsolete whole-module equality check with focused ownership/stance/
save contracts. Candidate's seven added tests pass. Native compilation was attempted
with the existing 516.1688 DreamMaker and existing i386 loader; both fail with
`Exec format error` on this kernel. No daemon/client was launched. Hosted compile,
native collision, graphical repeat/focus, persistence roundtrip and LOS integration
remain unverified.
