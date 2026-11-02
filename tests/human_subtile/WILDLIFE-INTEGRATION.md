# Default-off wildlife movement integration

This is a source integration for review. It does not opt ordinary wildlife into
smooth movement. `npc_subtile_enabled`, the pursuit, follow, flee, pet, species,
recovery and large-exit gates remain false by default; the existing NPC vendor
opt-in remains. The existing ordinary human-animal friendly-swap veto stays in
place. BYOND's native group Bump swap is not an implementation of that veto.

The shared walker serializes its continuous producer behind one owner and one
authenticated physical pulse transaction. A completion signal is delivered once
after transaction cleanup; replacement, invalidation, cancellation, and error
do not replay the old command. Identical active commands retain their deadline.
Timed flee preserves its original absolute ticket deadline. Food and stop-only
producers stop the appropriate continuous owners, while `following_mob` remains
a durable relationship. Human rider destruction and distance cleanup invalidate
the affected mount's pending command only after confirming that the mount still
belongs to the rider, before releasing it back to AI.

The reviewed cardinal experiment found that native walk lag should be passed in
deciseconds for the tested fixed-direction cases, rather than multiplied by
`world.tick_lag`; the old mosquito/bat empirical multipliers are not restored.
This observation does not establish parity for other modes, tick rates, random
directions, attack contacts or pathfinding. The real AI's exclusive movement
ownership can differ from a legacy overlapping wander and pursuit. Do not hide
that difference by widening timing or contact acceptance thresholds.

The normal admitted footprint remains 32x32. The large collision bridge is
present but disabled, and does not make 96x96 wildlife safe: facing, full
footprint collisions, diagonals, save restoration and callback mutation remain
open. Controlled, incapacitated, restrained, pulled and mounted animals remain
outside the ordinary pulse admission path. Actual producers and inherited
overrides still need per-family audit; no all-species acceptance is claimed.

The current source retains its existing NPC offset save/import behavior; the
user's later tile-only persistence direction must be integrated with the
separate persistence owner, not inferred to have been implemented here. The
merged rider lifecycle safeguards and call-local LOS invalidation contexts are
preserved. The registered `wildlife_offline` suite uses source checks, simulated
ownership and inert projection boundaries. These checks do not run BYOND or
establish native collision, client rendering, full-game save/reload or timing.
