# Experimental straight-leaf pair producer

The producer is now connected to `client.Move -> human.SelfMove`, through an
explicit body-local `human_subtile_pull_enabled` flag that defaults FALSE and has
no player verb. Its setter requires alignment, no active physical owner and the
existing safe human adapter setter. Existing gameplay is unchanged while OFF.

Initial targets are exact wood/steel/iron material-stack types and the base empty
crate type. Both participants start aligned; the target must be directly behind
a cardinal intent, empty, movable, appropriately sized and reciprocally pulled.
Every capability still requires the actual admitted client's moving permission.
No fake client or generally relaxed target/player authority is introduced.

The original client input pays nutrition/water/stamina/velocity and the existing
pull slowdown once, then captures the same transformed absolute deadline. The
producer executes at most 16 rounds of leader-first/follower-second native 2px
moves. The native seam checks each exact participant capability and position.
It bypasses only the old full-tile follower subtree for these owned pulses;
unrelated collision remains native. Human/living completion hooks are consolidated
once per attempted intent, including blocked attempts. Target native glide is
compare-and-restored. No global tick rate, path search, crafting or RNG loop is
added per pulse.

Cancellation retains observed physical offsets and exclusive ownership. A fresh
reverse input can recover the pair back along its owned straight path under the
current real client, using its ordinary paid input deadline. Recovery catches the
maximum 2px gap, then moves the follower before the leader. Its source-derived plan
finishes all 96 valid 0..32px/gap 0..2 states within 16 rounds/at most 34 native calls.
Actual collisions may stop recovery; no raw rewind, snap or foreign relocation is
adopted. Starting another pull is refused while a participant has an outstanding
lease. Stopping a pull cancels old forward work; recovery permits the former pair
only if neither participant has acquired another pull link.

Save contract is deliberately fail-closed: the movable before_save_context hook
revokes capabilities and restores temporary target glide before export. A fully
aligned pair releases and delegates to the original saver. A partial pair throws
before normal participant save hooks, preventing an incoherent target raw-offset
snapshot. The runtime enable flag and all leases are excluded from persistence;
no partial-pair import/replay is added. This does not provide arbitrary-time pair
saves and is a blocker to default activation until reviewed/extended.

Remaining gates before gameplay enablement:

- Compile and native positive/blocked/cancellation/reverse/stop cases; exact
  costs, hooks, corner behavior, frame interpolation and coherent failed saves.
- Partial native displacement or unexpected callback movement must remain
  fail-closed; automatic repair of external transport/deletion/ownership changes
  is not completed here. Those cases can retain a lease and require further
  lifecycle work. Do not enable the prototype in production with that gap.
- Living targets, turns/diagonals, loaded containers, assemblies, arbitrary leaf
  types, client handoff UX and partial-save roundtrip need separate profiles and
  actual-client acceptance. No claim that all dragging is now smooth is made.

The 16 pulling offline checks include 8,192 source-derived displacement comparisons,
the 96-state reverse planner and source contracts for admission, native routing,
once-only costs/hooks, cancellation and saves. They do not execute a world.
The existing walking regression suite remains a separate baseline.

Shared seams: retain the crafting branch's passive-UI helper/pre-input cleanup.
This branch conservatively excludes using_object in its pair profile. Its added
pair-owner exclusions in normal and posture readiness prevent concurrent physical
workers; carry those exclusions into the prone owner's new readiness predicates.
NPC native pulse dispatch and this pair dispatch must remain independently scoped
when merging their neighboring movable seam changes.
