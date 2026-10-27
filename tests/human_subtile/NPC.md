# Vendor AI movement candidate

Omar is `/mob/living/simple_animal/npc_vendor/smuggler`, created by the map's
vendor placeholder. His family uses `simple_animal.handle_ai()` and
`do_behaviour("wander")`. Although vendors declare `wander = FALSE`, the existing
handle_ai branch falls through to the shared logic; this patch preserves that
behavior. The turn gate, idle AI throttle, direction selection and RNG are
unchanged. One existing tile `Move` becomes `ai_step(destination, move_to_delay)`.

Only NPC vendors enable this adapter by default. Other simple animals retain
legacy behavior; `smart_step_towards` also exposes the reusable helper for opted-in
AI. Native `walk`, `walk_to`, combat pursuit and `do_movement` pathfinding are not
converted. Their scheduling, A* calls, path-score JIT and fallback direction
selection stay unchanged. This is vendor/explicit-AI integration, not a claim that
every mob or every movement producer has been converted.

The helper admits only conscious, unowned, unlinked, mobile, tile-sized AI bodies.
It returns actual initial physical progress synchronously, then starts at most
one worker with at most sixteen native 2px collision pulses. The supplied interval
controls interpolation; it does not add a sleep to the AI caller. Vendor interval
4 means 0.4 seconds; the existing AI turn counters still determine when another
intent is selected. Absolute deadlines avoid sixteen accumulated rounding delays.
The actor's native glide is compare-and-restored at completion or cancellation.
No fake client, player authority change, client FPS assignment, cosmetic offset,
global simulation-rate change, per-pulse pathfinding or input queue is involved.

Native pulse capabilities require the exact actor, destination, direction and
starting position, and can be consumed only once. Diagonal pulses bypass legacy
cardinal decomposition only at this seam. Living completion hooks run once per
native attempted intent, including blocked attempts, instead of per pulse. Native
collision, turf callbacks, doors and other Move-chain effects remain engine-owned.
Retargeting, generation changes, lost authority, changed position, persistence
admission and injury interrupt old work. No worker may adopt an external teleport
as a new anchor. A shortened recovery still reserves the original admission
deadline. Opted-out and ineligible aligned bodies use their legacy Move path.

Partial displacement remains physical: the next supported AI intent can recover
each moving axis to its next alignment. Opt-out and unsupported movement at an
owned offset refuse rather than snap. Pulling/restraints/client possession during
an interrupted intent therefore need explicit interaction acceptance: release the
unsupported state before ordinary AI recovery. This is a retained limitation to
review, not evidence that every legacy interaction works during an offset.
Save/load captures owned offsets through a five-scalar capsule, excludes runtime
state, rejects occupied/malformed placements and does not replay workers. Legacy
unowned raw offsets are not silently adopted.

Update budget is at most 16 top-level Move calls per admitted AI intent, versus 1
previous top-level tile Move (legacy diagonal decomposition adds its own internal
calls). At a 4ds interval the ceiling is 40 pulse calls/sec for a continuously moving
actor, while vendor idle throttles typically admit intents less often. This is
arithmetic, not a CPU/bandwidth/concurrency benchmark. Each actor owns at most one
finite worker; no pathfinding call is multiplied by 16.

`test_npc.py` provides offline wiring, authority, scope and source contracts.
`npc.dm` prepares actual unowned Omar-derived native scenarios for all 8 directions,
blocked moves, partial cancellation/reverse recovery, opt-out and graph-codec
roundtrip. It does not override NPC authority or attach fake clients.
`run-npc.py --prepare-only` stages exact Git objects;
`--compile-only --byond-bin <directory>` uses the existing 516.1688 compiler and
unchanged resource/socket/owned-process guard. There is deliberately no runtime
launch mode. Compiling those scenarios does not establish their assertions pass.
Its separate preparer writes a bounded local Git tar before extraction, avoiding
the historical stream producer's Windows pipe-tail wait. It retains archive and
input hashes, uses the same extraction/startup limits and checks every staged
input again after compilation. Historical preparers and native guards are unchanged.

NPC native execution, diagonal/corner interaction, pulling/client-handoff behavior,
rendered smoothness, tile-boundary camera behavior and representative-load cost
remain pending separately reviewed acceptance. No live TDM change or restart is
part of this draft. The user's accepted regular-walking result belongs to #3337;
full crawling is a separate proposal and is not modified here.
