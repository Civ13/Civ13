# Vendor AI movement candidate

For the staged wildlife coverage matrix and mutation-hook limitations, see
[`WILDLIFE.md`](WILDLIFE.md).

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

The staged `ai_step_wait` helper requires pulse admission and waits for the
transaction to finish; it reports arrival only after all requested axes reached
their step boundary through authenticated pulses and the completion hook did not
change ownership, position or the captured AI state. Ineligible or unowned-offset
bodies refuse instead of falling back to legacy Move. Its only callers are the
separately disabled pursuit, leash-follow, scared-flee and pet-walk adapters; no additional
wildlife is enabled. A caller must allow sleeping and must not add another full
movement interval after waiting. The
existing non-waiting `ai_step` and its legacy fallback remain the default.

The staged pursuit adapter is separately default-off and no species enables it.
It coalesces repeated requests for the same target, invalidates an old owner on
retarget, and waits for pulse completion before considering an attack. It retains
the path loop's selected interval without adding another full sleep after the
receipt. The legacy AI-tick stuck observation and side-direction random choice
remain on the AI tick. One latest side direction waits for the current pulse and
is discarded if its actor or target turf changed; a side-step consumes a pulse
interval instead of overlapping the path loop. The legacy code can issue both
instantaneous steps concurrently, so exact movement timing, path decisions, stuck
counts and RNG order cannot be claimed equivalent under exclusive physical pulses.
The AI's observed turf can also change at a different time during a pulse. Native
review and an explicit gameplay decision are needed before enabling this path.
The attack gate refuses an owned partial offset even if pursuit has ended, and
an adjacent pursuit attempts collision-safe alignment before the normal AI tick
can attack.

The default-off recovery owner retries an orphaned owned offset on later Life
ticks once the animal is eligible, using authenticated pulses in either direction
and never snapping or using legacy Move. Offset-recovery intervals are scaled by
the remaining pixel distance, with a one-tick minimum. Recovery stops existing
native walkers and temporarily owns movement, while unrelated AI decisions keep
running. A recovery worker relinquishes after a blocked attempt in both directions;
subsequent Life ticks may retry at the existing movement interval. Follow and
pet-towards owners attempt to settle and relinquish when a partial offset reaches
their distance cutoff, so an idle continuous owner cannot hold recovery forever.
While recovery owns movement, or an owned partial offset is temporarily ineligible
before recovery starts, staged pursuit, follow, flee and pet starts replace one
runtime-only pending intent. Automatic owner cleanup transfers a still-valid
intent to the next generation. Explicit stop callbacks cancel their respective
pending intent; the scared-flee request also expires at its original 50-ds boundary.
Before dispatch, the pending target, generation, AI state, control state and
relationship are rechecked, the offset must be aligned, and the slot is consumed
before starting a worker. A recovery interrupted only by temporary physical
ineligibility retains a still-valid pending intent; a changed owner generation
or invalid command state discards it. A command from a client-controlled or
unconscious actor is not retained; an actor that remains restrained, controlled,
blocked or non-32x32 may remain
unable to settle. Pulse-time checks avoid view or path searches. State changes
that invalidate and then restore a value between checks are not recorded by a
universal epoch, so the source model does not establish that such transient
invalidation can never replay. These checks do not establish ordering for every
native callback or state transition. Do not enable species until replay, interactions
and native timing have been resolved. Continuous owners authenticate each pulse,
including between steps, so ordinary wandering cannot silently take over an active
intent.

The staged leash-follow worker also has its own default-off gate. It retains the
existing start threshold, 6 ds step interval, one-tile near distance and six-tile
leash cutoff. The durable `following_mob` relationship remains separate from the
runtime worker. Pursuit cancels follow's worker while preserving the relationship;
follow refuses to preempt an active pursuit. It uses `get_step_towards` for each
decision; parity with native `walk_to` around obstacles and when combat competes
with following is not established and must be reviewed and tested.

The staged scared-flee worker has a third default-off gate. Its existing producer
still selects the first nearby human, uses a seven-tile cutoff and two-ds interval,
and schedules the 50-ds stop. Flee takes the movement worker from follow or
pursuit; a new pursuit can take it back, without changing the durable leash link.
The worker chooses the direction away from the target for each step. This has not
been shown equivalent to native `walk_away` obstacle handling or command restart
timing. The scheduled stop cancels staged continuous follow/flee as well as native
walk, matching the old callback's broad stop for native walkers.

The crab's independent Life movement has a fourth default-off gate. It keeps its
single lateral random choice and existing move counter, and requires pulse-only
admission when staged; otherwise it retains the native Move call. A successful
first pulse can still be interrupted later, so crab timing and blocked movement
need native review. Crab is not enabled until its inherited movement and linked
states are coordinated too.

The pet scan's staged worker is also default-off. Cat and dog scans stop their
worker where they already stop native walking, then retain their existing prey,
friend or flee decision and 3, 4 or 2 ds interval. A pet command takes the single
movement worker from leash, flee or pursuit; those commands can take it back when
their producers next issue one. This precedence is an explicit proposed handoff,
not verified parity with concurrent native walk and `do_movement`. Mouse-on-turf
attacks, friend health thresholds and scan cadence remain in their existing AI.
Native obstacle routing, movement interruption and attack timing need review.

The remaining wildlife migration needs cancellable ownership for native walk,
walk_to, walk_towards, walk_rand and other flee users, including frog, insect
and bat paths and their external redirects. Multi-tile animals such as mammoths
are outside the present 32x32 pulse admission and need a collision-safe design;
they must not be silently presented as supported.
Only enable a species after every movement producer it can enter has a safe
transition and owned partial positions can recover after eligibility returns.
`test_npc_completion.py` checks the side-effect-free source predicates and bridge
wiring offline. It does not execute a DM worker, native collision or gameplay.

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
