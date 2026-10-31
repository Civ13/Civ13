# Modifier-held precision movement

Hold Alt and press an arrow (either macro mode) or WASD (hotkey mode) for a
2-pixel physical step. Alt+numpad diagonal direction keys issue diagonal steps.
Release the chord to stop repeating; unmodified directions keep the existing
alignment movement. There is no directional HUD movement button in this skin.
Alt+L remains LOOC. Smooth movement must be enabled (including default activation).

Each native `+REP` chord sends one fresh input, not a server-held modifier latch
or worker. It releases ordinary held-axis requests through the existing key-up lifecycle
(including drone/turret stop hooks) before entering `client.Move`.
No input state persists across release, focus loss, logout, body transfer or save.
Actual DreamSeeker macro/repeat/focus delivery still needs connected-client QA;
this source-level design does not establish that UI evidence.

The existing client admission, native one-use pulse authority, collision chain,
offset normalization, persistence capsule and completion hooks remain authoritative.
Fine steps stop after 2 pixels on each moving axis, including across tile borders
(e.g. west from offset 0 becomes offset 30 in the western tile). No `pixel_x/y`
visual displacement or forced placement is used. Blockage does not refund costs.
Pulling, linked states, posture movement, driving, confusion and unowned legacy
offsets refuse precision input rather than falling back to a tile move.

Nutrition, water, stamina and run warming cost 1/16 of a tile input. The existing
speed/terrain/trait/diagonal delay is scaled by 1/16 with a minimum server tick;
precision cannot move faster than ordinary input. Precision does not accelerate
run velocity. Ordinary-input arithmetic is unchanged. Fine positioning does not
perform tile stomps, avoiding rapid boundary-oscillation attacks. Completion still
updates vision/UI/chat anchors and movement appearance and notifies nearby animals
once per successful fine input; it does not grant silence. Existing native
per-pulse collision/movement effects retain their current behavior.

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
