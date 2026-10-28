# Movement combat: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- 2026-10-27: staged pull-pair ownership kernel -->
<!-- 2026-10-28: default-on pull pairs with stuck-pair resolver -->
pull_pair_ownership.dm now has a default-ON pull_pair_producer.dm caller (owner
request); it follows the smooth movement toggle. Only aligned straight cardinal pulls of whitelisted empty leaf stacks or
base crates are admitted; no turns, living targets or assemblies. Client costs
and deadlines are captured once; both bodies use authenticated native pulses,
with consolidated actor hooks and reverse recovery. Partial pair exports refuse
before normal save hooks; only aligned checkpoints export. Native collision,
lifecycle acceptance and partial-save support remain unverified.
Offline projections are not native authority/collision evidence. Keep the shared
ready/posture exclusivity guards when integrating crafting/prone/NPC work.
pull_pair_lifecycle.dm revokes logout/stop/deletion capabilities and restores the
target glide. Deleted actors leave no registry key/member/controller reference;
unrecoverable pairs (dead/downed/disconnected leader, deleted member) settle
immediately to nearest aligned tiles; others after a 5-second recovery grace.
Save admission reads every bounded lease before creating the operation: native
calls/intents must unwind, hooks must complete, and live survivors must have valid
aligned shapes; save admission first settles quiet pairs, so none holds forever.
Never serialize a half-applied pair or release an offset to legacy movement.

<!-- 2026-10-26: diagonal human movement candidate -->
The human adapter uses sixteen native 2px pulses per admitted input, bitmask
diagonals, and the legacy ordinal cooldown multiplier. Default activation waits
for an eligible input and calls the safe setter; an explicit aligned opt-out
clears pending initialization. Owned restored offsets may resume; arbitrary
legacy offsets are not adopted. Native glide/client FPS ownership is runtime-only
and restored on opt-out, restricted input, logout, body handoff and death.
tests/human_subtile/run-diagonal.py targets 516.1688 with exact-Git staging and
a separate executable allowlist; historical helpers remain frozen. Preserve the
Windows startup-socket rejection rather than weakening its no-socket policy.
Headless displacement/compile checks never prove DreamSeeker visual smoothness.
<!-- 2026-10-28: pulling and menus keep smooth movement -->
Pulling and open menus (any using_object except a stationary gun) keep the
adapter eligible: a restricting state mid-step refuses all input until alignment.
Headless fixtures have no client, so living/Move stops pulling there; pull-follow
during smooth steps needs connected-client confirmation.


<!-- 2026-10-19: combined sub-tile mining acceptance -->
`tests/human_subtile/run.py --suite mining` stages the full merged game and
exercises native collision dispatch, mining snapshots and physical offset drift.
Its mining-position control must fail the same-anchor drift oracle, not merely
some assertion. Headless authority is adapted: only a separately attached real
client can establish client.moving ownership through the optional client entry.
Keep the production adapter disabled until that separate acceptance is met.

<!-- 2026-10-15: hover name HUD -->
`code/_onclick/hud/hover_name.dm` uses a weak target reference on a disposable
human HUD screen object. Mouse events update it; the existing HUD process
revalidates stationary targets. Keep masked names behind `get_visible_name()`,
require a screen slot for inventory visibility, and forward runtime persistence
exclusions. `tests/hover_name/run.py` exercises native production decisions with
an injected client boundary, not real client mouse delivery or rendering.
<!-- 2026-10-12: NPC cover decision parity -->
`tests/npc_cover/run.py` compiles production cover scoring, LOS and line helpers
with native BYOND ranges in an isolated 32x32x2 world. It compares every score
and choice, including officer/clump boundaries and tie controls. Cover allies
are cached only within one synchronous decision after its second cover candidate;
keep candidate order and strict score comparison. The benchmark reports native
wall time, not server CPU or combat movement acceptance.

## Train verification

<!-- 2026-10-11: firearm configuration verification -->
Gun configuration is centralized in `code/modules/1713/gunsmithing/gun_configuration.dm`.
Keep runtime action owners and work reservations out of native item saves; saved
optics can be nested inside one rail adapter. `tests/gun_configuration/run.ps1`
checks production handling, interruptions, maintenance, crafting gates and nested
save migration; `-NegativeControl` must catch omitted completion ownership checks.

<!-- 2026-10-11: automobile construction -->
`tests/car_workshop/run.ps1 -ByondBin <516.1681-bin>` exercises paid AOTD
assembly, interruptions, cable reservations, driving, turning and temporary
world-save round trips with production sources and isolated startup/actor waits.
Nested vehicle controllers have no direct turf coordinates; use `get_turf()`
when comparing their positions. Workshop power connects by dragging a laid cable
onto the workshop; cable coils feed its material stock.

<!-- 2026-10-11: train collision investigation -->
`code/modules/1713/trains.dm` connections point from leader to follower. Reject
coupling cycles and stop failed movement before recursively moving followers;
`Bumped` is deferred by the movable atom's bump callback. Run bounded isolated
regressions with `tests/train_collision/run.ps1 -ByondBin <516.1681-bin>` and real
game callback/locomotive-loop tests with `tests/train_collision/run-game.ps1`.
The full-game probe uses temporary state and outbound-hook controls. Its optional
visual mode needs separate capture authorization; it never proves production
crash behavior. Do not replace required gameplay captures with fixture output.

<!-- 2026-10-11: conveyor verification -->
`tests/conveyor/run.ps1` compares production tick snapshots with isolated storage;
retained entries are distinct from OS private memory. `run-game.ps1 -ExerciseCapture`
checks real forward/reverse/stop behavior. Its optional bounded `-Visual` mode
requires the coordinator's exclusive screen turn; see tests/conveyor/README.md.
<!-- 2026-10-12: animal health and combat dispatch -->
<!-- 2026-10-23: domestic defensive retaliation -->
Adult domestic sheep/goats/pigs/cattle, horses and camels explicitly opt into
zero-damage immediate retaliation. `Weaken(2)` counts Life updates, not ds;
ten-second runtime deadlines on both participants prevent herd stun chains.
Keep juvenile and larger-attacker escape gates, husbandry dispatch and custom
save exclusions. tests/animal_combat has offline source checks and a prepared
native fixture; native/client acceptance remains separate.

Simple-animal starting health and maxHealth must match unless an explicit policy
is documented: Life clamps health and updatehealth recomputes it from maxHealth.
Do not call parent attackby after an explicit item attack; that repeats damage,
logs and material wear. tests/animal_combat/run.py checks compiled inherited
health defaults, native Life, single sharp/blunt attacks and wear across behavior
branches, noncombat dispatch, healing/death and generated negative controls.

<!-- 2026-10-19: independent typed wait contexts -->
`do_after` keeps mining_context in its ninth argument; opt-in gameplay_context
is tenth and forwarded by name. Reject simultaneous contexts before either
claim. Preserve mining progress/owner cleanup and ordinary null callback order.
The gather disabled-source hashes project reviewed master; refresh them only
after verifying all four full-file projections. Idle-metabolism extraction must
project the disabled helper before finding its conditional proc declaration.
