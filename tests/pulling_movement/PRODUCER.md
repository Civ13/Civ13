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

Save contract is deliberately fail-closed. The global persistence admission reads
the bounded registry before creating an operation or setting busy flags. Every
pair must have no running intent, native call or capability; completion hooks must
already have finished and each surviving actor must have a valid aligned shape.
Otherwise the request returns a visible held-save message without entering save
preparation/backend or clearing the previous failure record. Load admission is
unchanged. A participant before_save_context remains a second guard for direct
exports: active calls revoke then refuse, quiet partial pairs refuse, and aligned
checkpoints release before original hooks. The runtime enable flag and all leases
remain excluded from persistence. No partial-pair capsule/import/replay is added.

Logout/body handoff cancels forward work, restores target glide and clears the
old controller. Hooks/lease release wait until a native callback and its intent
unwind. A newly admitted actual client can pay for reverse recovery under the
unchanged authority predicate. Pull release keeps its old paid deadline, cancels
further forward work and settles immediately if no worker remains. A callback
interruption records only the capability's unchanged position or its exact fully
consumed native endpoint, and only if the other live participant is unchanged;
foreign/partial displacement is never adopted. A throwing native call unwinds its
in-flight flag before outer cancellation/completion.

Deletion retires only the exact matching registry entry, clears the deleted
member/snapshot/origin and controller references, and revokes capabilities before
the original movable Destroy detaches contents. An aligned survivor releases; a
partial survivor retains exclusive ownership and blocks saving. Orphaned pairs
cannot issue another paired recovery. This intentionally does not invent an
autonomous object mover, borrow another body's client, or snap a survivor. A valid
explicit aligned checkpoint or retirement of the survivor can clear the hold;
automatic orphan recovery and arbitrary-time saves remain activation blockers.

Remaining gates before gameplay enablement:

- Compile and native positive/blocked/cancellation/reverse/stop cases; exact
  costs, hooks, corner behavior, frame interpolation and coherent failed saves.
- Partial native displacement or unexpected callback movement must remain
  fail-closed. Automatic repair of external transport/ownership changes or a
  partial orphan is not completed here. A retained lease can intentionally hold
  map/restart saves until resolved. Do not enable in production with that gap.
- Living targets, turns/diagonals, loaded containers, assemblies, arbitrary leaf
  types, client handoff UX and partial-save roundtrip need separate profiles and
  actual-client acceptance. No claim that all dragging is now smooth is made.

The pulling offline checks include 8,192 source-derived displacement comparisons,
the 96-state reverse planner, a 1,152-case actual checkpoint-expression projection,
interrupted-receipt policy, and admission/native-routing/cost/hook/lifecycle source
contracts. The existing save-movement adapter also executes the complete selected
production admission and Destroy control flow with an injected pair-manager
boundary. It verifies held admission preserves operation/failure state, load
admission is unchanged, and nested qdel retires each actor before detachment.
These checks do not execute DM or prove native lifecycle behavior. Walking stays
a separate baseline. The initial failed boolean-extractor run is retained.

Shared seams: retain the crafting branch's passive-UI helper/pre-input cleanup.
This branch conservatively excludes using_object in its pair profile. Its added
pair-owner exclusions in normal and posture readiness prevent concurrent physical
workers; carry those exclusions into the prone owner's new readiness predicates.
NPC native pulse dispatch and this pair dispatch must remain independently scoped
when merging their neighboring movable seam changes.
