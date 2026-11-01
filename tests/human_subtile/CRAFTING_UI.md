# Crafting recipe view and movement

The held-stack recipe menu sets `using_object` for legacy refresh and close
callbacks. Previously that pointer alone made the human sub-tile adapter
ineligible, releasing native interpolation and taking legacy tile movement when
aligned. Opening the separate Crafting Atlas does not itself set that pointer;
Atlas-only focus/render behavior still needs connected-client evidence.

The typed passive-UI contract identifies a current active-hand recipe stack,
directly owned by the human, with a recipe list and positive quantity. It is
used for stale-view cleanup; it does not gate movement. The accepted master rule
allows pulling and other object-use links while retaining the mounted-gun,
riding, authority and other existing restrictions. No client authority, opt-out,
speed, costs, hook scheduling or world FPS changes.

A stale recipe view after a hand change, drop, transfer or depletion closes before
the next movement admission. It releases the existing `using_object` association
without changing physical position, so an interrupted offset can use normal
reverse/alignment recovery. Opted-out legacy bodies retain their prior UI path.
No focus assignment or per-pulse browser refresh is introduced. Valid view
refreshes and on-close callbacks remain unchanged.

`do_after` with `can_move = FALSE` now compares its starting `step_x` and `step_y`
as well as `loc` on its existing poll. Otherwise a partially moved crafter could
remain on the same turf and pass the stationary check. This deliberately applies
to all stationary waits, matching physical movement semantics; explicit
`can_move = TRUE`, the existing timer, mining/gameplay context slots, progress,
repeat prevention and cleanup stay unchanged. It detects changes at the existing
poll cadence, not a new event-driven guarantee for movement that returns entirely
between polls. Crafting material/handle charges and cancellation refunds are
unchanged and remain after the existing action wait.

`test_crafting_ui.py` has offline source-derived policy and parity checks.
The held-stack predicate and physical-position boolean are evaluated from their
production expressions. These are not native DM or browser simulations.
All four disabled/enabled gather projections retain the original master0156671
full-file identities in `crafting_gather_baseline.json`. This corrected check
needs no historical Git checkout. It reverses only exact reviewed additions:
the stationary wait's physical-offset checks, #3451's early grass busy-admission
guard, and #3458's call-local mining work image/cleanup around the unchanged wait.
Each inverse must match exactly once; missing or changed guards, image ownership,
wait duration and rewards fail. The normalized whole-file digest must match the
original frozen projection in both feature modes. Current disabled projections
must also match the existing helper hashes, which are not refreshed by this
correction. Enabled context-claim, type and forwarding omissions and arbitrary
file drift are negative controls. Other existing checks in this file retain
their earlier Git-history references; this correction does not migrate them.
Bridge/mechanics, FPS feature code, workflow admission and native fixture inputs
remain unchanged. These controls are offline source checks, not native evidence.
`crafting_ui.dm` prepares fourteen native assertions using real human/stack Move,
inventory drop, reverse recovery and `do_after`, under the existing headless
fixture authority. It is not included or launched by the ordinary walking lane.

Before native execution, review a bounded exact-head fixture adaptation: append
`crafting_ui.dm` after `probe.dm`, replace only the headless scenario call with
`crafting_ui_movement_fixture()`, include its check count in the receipt, and retain
the current source/toolchain/resource/socket/cleanup envelope. No world/client is
launched by this source preparation. Real-client menu-open/close, text focus,
refresh, costs/cooldown, handoff and rendered tile-boundary continuity remain
separate acceptance. Save/load with a held view and partial offset also needs
native confirmation; no new persisted UI or movement worker state is added.

Shared integration seams: prone and pulling also use the human adapter and
eligibility checks. This branch leaves master's `human_subtile_unlinked` rule
unchanged, adds a passive stack API and pre-input stale-view cleanup, and
strengthens the existing stationary action predicate. Prone timing and the
posture transaction stay unchanged. Coordinated pulling is separate.
