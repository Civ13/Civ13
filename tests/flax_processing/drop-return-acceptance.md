# Issue #3322 source review and remaining acceptance

The production fix merged in #3324 at `ee976baa004ad86528d7eddc4c06da3d94a43ec9`.
The earlier review and acceptance proposal below remain historical evidence.
The previously unpublished fixture is now prepared on current source; see
[the reconciled source-only plan](human-entry-plan.md). No native compiler,
daemon, client, capture or workflow was run for this preparation. Main owns
independent review and any later admission.

## Decision and dispatch boundary

Forward the result in both existing human definitions using `return ..()`.
This repairs the common reporting contract without a special flax bypass.
The parent body, two-argument human signatures, bare implicit forwarding, organ
early returns, and DME include order stay byte-for-byte unchanged. The parent
also accepts an implicit third argument; its existing `ignore_nodrop` rejection
polarity is deliberately preserved, not repaired as part of this issue.

Both declarations name `/mob/living/human/drop_from_inventory`. Their file
locations are not evidence of different inheritance levels. The include order is
inventory.dm, living.dm, then human.dm. Offline tests check each explicit body
independently; they do not establish how native DM chains repeated definitions,
which guard executes, or how extra implicit arguments are forwarded. Native
acceptance must resolve these points, including both organ exclusions. If an
exclusion fails on baseline, report it explicitly before broadening the fix.

Removing the return gate only in flax would leave the parent-reporting defect in
place and risk admitting false-result actions. Replacing flax placement with the
tanning transfer API would change ordinary drop event/admission semantics. Neither
is needed for this proposal. Keep flax's `loc != W` guard: the parent returns TRUE
after an unchecked `forceMove`, so propagated TRUE alone does not prove placement.

## Bounded caller audit

The audit covers literal references in tracked `code/**/*.dm` and test fixtures
at base `3d3970b388c33aa332409ebc4c51a5e8df805874`. It is a source audit, not a
runtime trace or proof against dynamic proc lookup.

| Consumer | Effect of forwarding successful human drops |
| --- | --- |
| `flax_processing.dm`, bundle `afterattack` | Enters production `soak` only when the return is true and the actual bundle remains on the selected water turf. |
| `items/weapons/defib.dm`, `attack_hand` | Enables the existing successful paddle-return notice. The subsequent `forceMove(src)` and icon refresh were already unconditional. |
| `mob/inventory.dm`, `drop_l_hand`, `drop_r_hand` | Return the corrected result; downstream `drop_inactive_hand`, `drop_item`, and `drop_active_hand` forward it. |
| `structures/table.dm`, `MouseDrop_T` through `drop_item` | A successful human drop can now reach the existing `step` toward the table. Failure still returns early. This is an additional behavior requiring native regression coverage. |
| `mob/mob_movement.dm`, client `drop_item` verb | Forwards the corrected result, with no subsequent result-dependent action in its body. |
| Remaining literal callers | Ignore the result. Physical removal, callbacks, nodrop gates, forceMove events and HUD cleanup remain in the unchanged parent. |

`unEquip` calls the drop but returns its own TRUE; it does not propagate the
corrected value. No callers of `drop_active_hand` or `drop_inactive_hand` were
found beyond their definitions. Ordinary direct drop callers, wrapper consumers,
the parent and both same-path definitions were inspected separately. This does
not imply that their existing physical ownership contracts are all correct.

The production tanning rack still uses `transfer_held_item_to`. Do not replace it
with an ordinary drop: floor merging and destination rollback protections from
#3286 remain necessary after return propagation. Its native regression now checks
a successful production-human ordinary drop and preserves the historical false
return plus real floor transfer through a named `legacy_return` wrapper adapter.
The adapter deliberately discards the result; it is not a claim that production
still has the defect. All floor-merge, bag, denial and redirect tests remain.

## Smallest remaining native acceptance proposal (not executed)

After independent review and a separately authorized exact-head native grant:

1. Compile the full game and relevant fixtures with the approved pinned BYOND
   version; retain complete diagnostics. The failed V46 scene used 516.1688,
   which is also the current manifest target. The selected Linux flax runner
   verifies that target through the reviewed archive/member identities and one
   exact compiler banner. The unselected historical harvest runner remains at
   516.1681; its amended tanning fixture still requires separate admission and
   version reconciliation before native execution.
2. Use an isolated awake, live production human with real pickup, inventory slot
   updates and drop dispatch. Do not use `flax_tester`: it overrides the drop
   result and its existing direct `B.soak` calls bypass the failed entry path.
   Initialize the existing observer/HUD dependencies through reviewed fixture
   setup. Preserve the production inventory proc and implicit forwarding.
3. Tie two actual raw flax, pick up the resulting bundle through normal inventory
   APIs in each hand, then enter production bundle `afterattack` on reachable
   fresh water. Instrument only the wait seam to prove one wait entry after
   physical transfer; assert exact bundle identity, no hand slot or client-screen
   ownership, no duplicate bundle/output, and actual location on that water.
   Do not invoke `soak` manually to satisfy this case.
4. Check null input, nodrop, nodrop_special_check, both organ exclusions, omitted
   and explicit targets, and the existing third-argument behavior. Refusal must
   not enter soaking. Exercise denied and redirected moves: even a true parent
   report must not enter soaking when the item is elsewhere. Record actual
   ownership/HUD state; do not substitute an unconditional-success test actor.
5. Retain a legacy-return negative control that physically drops the bundle but
   fails the same genuine afterattack-to-wait oracle. Also run both repaired
   same-path definitions under production include order, not reordered extracts.
6. Exercise real wait cancellation/movement after one completed stage, retained
   stage, resumption, invalid/salty/irradiated water, full completion to exactly
   two rotten flax, and replay rejection. Keep the existing downstream paid
   processing and save-round-trip cases as separate coverage.
7. Run the updated tanning rack fixture with its production and legacy controls,
   bag rejection, floor merging and denied/redirected transfer recovery. Check
   table MouseDrop_T success/refusal and paddle return as affected consumers.
8. Genuine connected-client acceptance must use production human drop-to-soak
   entry and the ordinary wait, with hand/screen cleanup observed. Existing V46
   failure remains failed. A click on a placed bundle is only the workaround;
   no manual soak invocation, fabricated success, or old capture can accept this
   new head. Main separately owns capture, publication and merge decisions.

Python source/contract models cannot prove DM dispatch, implicit argument
semantics, movement callbacks, native inventory/HUD cleanup, or genuine wait
entry. The amended DM regression is prepared source and remains uncompiled and
unrun until the separately admitted native phase.

## Preserved CI failure and selected-runner correction

At head `45c9e9c77286c12af94b47b3e505a32134ea4ba2`, ordinary PR CI run
`40238731403` compiled the full game successfully with 516.1688. Its flax fixture
also compiled with zero errors/warnings, but the runner rejected that clean result
because it still searched for 516.1681. This is a runner version-contract failure;
the original failed run stays failed. The selector admitted only
`tests/flax_processing`, with `extensive=false`; editing the existing tanning
fixture did not admit `tests/animal_harvest`.

The flax runner now reads the reviewed manifest, checks a single exact compiler
banner and clean summary, and passively verifies the pinned Linux archive and its
four installed runtime members immediately before each existing compiler/daemon
launch. Offline tests inject these launch seams; they never launch BYOND. Existing
180-second compile/45-second runtime bounds, isolation, output preservation,
cleanup and payment/replay/persistence controls remain. The follow-on source
preparation reconciles the harvest runner's version contract and passes its
archive argument without changing native selection rules. Ordinary PR CI still
runs the older processing probe, not the explicit human-entry mode; it cannot
establish production-human afterattack/HUD acceptance.
