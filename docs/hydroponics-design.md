# Modern hydroponics: accepted direction and implementation contract

Status: **design documentation; no tray implementation or activation.**
This records the accepted #3050 choices and the remaining integration decisions.
Merging this document does not complete #3050 or admit live runtime execution.

Source reconciliation: master `0f12bdd809f93ea8d8d6c631332404a894eb55df`.
The source links below are immutable. Test requirements are acceptance criteria,
not claims that those tests have run.

## Accepted user decisions

| ID | Accepted choice | Boundary |
| --- | --- | --- |
| H1 | Potato, carrot, cabbage, tomato, beans and wheat | Exact initial whitelist. No automatic addition of #3314 crops or later crop types. |
| H2 | 60 total reservoir units; 1 nutrient unit and 2 water units per powered, supplied minute; 6 cycles to ready; 5 power units (PU); 2 seeds and 1–3 produce | Abstract game units. Nutrient identity, physical binding and partial-cycle transaction semantics remain to be specified. |
| H3 | Shortage pauses growth; prolonged shortage can kill fragile or water-dependent crops | Fragile crop identities, grace/death durations and recovery/reset rules are unsettled. No universal death timer is approved. |
| H4 | Ready crops have no time expiration for now, except exposure to poor weather such as a snowstorm | Exposure, harmful-weather selection and damage/death timing are unsettled. Trays are not implicitly weatherproof. |
| H5 | Era tier 6 after advanced agriculture and electricity; 4 steel, 2 glass and 1 cable | Bench tier, research study price, exact material item units and dismantling refunds remain separate decisions. |
| H6 | Hand-filled first; pumps later | No nearby-water refill, automatic intake, pipe or pump scope in the first implementation. |

These choices supersede conflicting earlier proposals. In particular, do not
reopen the accepted cycle debit, construction counts or whitelist as if they were
still pending. Do not infer a 120-second death timer, 240-second ready expiry,
bench tier 5, or unconditional shortage immunity from them.

## Current source contracts

| Source fact at the pin | Design implication |
| --- | --- |
| Ordinary [crop growth](https://github.com/Civ13/Civ13/blob/0f12bdd809f93ea8d8d6c631332404a894eb55df/code/game/objects/farming.dm) requires ploughed soil and owns a recursive `spawn(600)`. It uses virtual `stageGrowth()` and checks death past `readyStageMax` even when eligibility prevents advancement. | Do not fabricate a dirt turf or call the ordinary growth chain from a tray. A shared stage boundary must preserve outdoor eligibility, timing, subtype dispatch and terminal checks exactly. |
| Ordinary readiness begins at stage 7; planting starts at stage 1. At high nutrition, stage advancement is deterministic. Seed and produce helpers emit at `loc`. | Six productive cycles match the accepted ready target. A contained crop needs an explicit turf output destination and one-time harvest ownership. |
| The same farming file has the timber seedling's saved remainder, runtime clock anchor, `persistence_runtime_var`, `after_load()` and `process_interval()` pattern. | Reuse the single-owner, saved-remainder principle; do not assume its crop or power behavior is a tray implementation. |
| [Holder](https://github.com/Civ13/Civ13/blob/0f12bdd809f93ea8d8d6c631332404a894eb55df/code/modules/reagents/Chemistry-Holder.dm) `add_reagent(..., accepted_amount)` can report the admitted addition; `remove_reagent()` still returns a boolean. Transfers are proportional, and mutation callbacks still occur with `safety = TRUE`. Small amounts below the chemical minimum can be pruned. | The new admitted-addition output improves fill accounting. It does not make a multi-resource debit atomic or prove exact removal. Revalidate owners and quantities after callback boundaries; do not equate requested transfer with retained volume. |
| [Cable](https://github.com/Civ13/Civ13/blob/0f12bdd809f93ea8d8d6c631332404a894eb55df/code/modules/1713/machinery/cables.dm) `update_power()` returns rebuilt capacity. Request acceptance is exposed by `draw_cable_power()` / `rebuild_supply(requester, request)`. Reservations are consumer keyed. | Capacity is not a boolean acceptance result or proof of a delivered minute. Do not debit a battery again at the consumer or invent stored energy from `powerflow`. |
| [Chemistry](https://github.com/Civ13/Civ13/blob/0f12bdd809f93ea8d8d6c631332404a894eb55df/code/modules/reagents/Chemistry-Recipes.dm) includes a water/potassium explosion. Registered fertilizer products do not by themselves supply a paid recipe. | The former proposal of 8 water +1 potassium +1 nitrogen →10 nutrient solution is withdrawn as a selected route. Elemental potassium is not a safe nutrient solution. Recipe registration, competing reactions and mixing order need chemistry review. |
| [Research nodes](https://github.com/Civ13/Civ13/blob/0f12bdd809f93ea8d8d6c631332404a894eb55df/code/modules/research_tree/research_node.dm) distinguish `era_tier`, `min_bench_tier` and prerequisites. | Accepted era tier 6 and both prerequisites do not approve bench tier 5 or grant completed research from global era alone. |
| Save/load uses explicit runtime-variable exclusions and load repair hooks. A primary reagent holder has special handling. | A second holder or crop-host link needs an explicit tested ownership/rebinding contract. A `tmp` field alone does not establish persistence exclusion; do not rely on a repair order before holders are rebound. |

The source pin has no `advance_stage_if_allowed` helper or production hydroponics
tray. The behavior-preserving helper is an independently reviewable source slice;
it is not evidence of a merged feature. #3049 owns protected outdoor soil, #3048
owns route coverage, and mining/material infrastructure retains its own owner.
Coordinate their interfaces without redesigning those systems here.

## Units and finite accounting

Use U for abstract reagent-volume units, N for the accepted nutrient accounting
unit, PU for requested power load and seconds for productive active-server time.
None is an SI litre, mole, watt or joule. The physical mapping of 1 N to a
registered solution quantity is unresolved.

For each completed, certified productive cycle:

- productive time increases by 60 seconds;
- nutrient cost is 1 N and water cost is 2 U;
- one shared crop-stage step occurs;
- requested load while productive is 5 PU.

A complete crop therefore costs 6 N and 12 U water across 360 productive seconds.
The nominal load-times-time is 1800 PU·s; this is arithmetic, not evidence of energy
delivery or a new fuel/battery debit. Paused time contributes no productive time.

If a reviewed binding chooses 1 N =1 U solution, a balanced 60-U fill of 20 U
solution plus 40 U water pays for 20 cycles: three crops and two cycles of a fourth.
Pure water has no nutrient credit, and pure solution cannot replace the water cost.
The reservoir is 60 U combined, not a 60-U water chamber plus a second free chamber.

### Payment boundary and precision: decision required before integration

Accepted per-minute totals do not choose continuous debit, upfront payment,
escrow or payment on completion. Choose one transaction contract and test it
before wiring resources to growth. Candidate approaches are:

1. Whole-cycle reservation/escrow, retaining an exact saved productive remainder.
   This avoids tiny repeated physical removals, but cancellation, refill and
   destruction require explicit ownership/refund rules.
2. Completion-time debit after a certified service window, with invalidation on
   relevant state changes. This avoids an upfront payment, but must prevent
   free progress when resources disappear during the interval.
3. Fractional physical debits with a bounded remainder. This follows partial work
   closely but must solve holder pruning, callbacks and exact-removal accounting.

These are alternatives, not selected implementation parameters. No negative
volume, synthetic refill, rounded-away repeated cost or duplicated credit is
permitted. Fractional process credits must retain their own dimension and may not
silently enlarge the physical 60-U capacity. A failed callback or changed owner
must not advance the stage after an incomplete payment. An interrupted transaction
must have a defined durable state; blind rollback through reactive holders is
not automatically safe.

## Nutrient route and bootstrap

Product ID, recipe, yield and ingredient prices remain proposed product choices.
The minimal route candidate is a dedicated registered nutrient solution made
through a controlled, paid conversion of existing compost/nitrary material.
A separately reviewed mineral-salt route is an alternative. Neither is approved
by H2. Reusing `eznutrient` would also require review of its existing toxic
fertilizer behavior, naming and dispenser exposure.

Before implementation, identify exact source item/reagent IDs and retained
quantities; bound reactions and callbacks; verify reachability at the accepted
research gate; and compare total inputs with seed/produce/compost outputs.
Do not infer a closed-loop gain or safety from a nominal recipe equation.
The paid upstream crop material, water, ash, processing time and any mineral costs
must remain in the ledger. Bootstrap must work from available seeds, water,
nutrient inputs, construction materials and an actual power route without an
already-running tray. Route coverage belongs with #3048; new mineral supply is
not implicit hydroponics scope.

## Shared crop adapter and one lifecycle owner

Proposed integration boundary:

- The existing crop retains its stage/yield/type rules. A shared stage helper
  performs virtual `stageGrowth()` only when admitted, then retains the existing
  terminal check. Outdoor callers retain all original eligibility and cadence.
- The tray owns the crop host relation and is the only tray scheduler owner.
  Establish hosting before any ordinary recursive growth chain can start.
  Define constructor, unhost, removal and delayed-callback behavior explicitly.
- A tray calls the shared stage helper only after a certified productive cycle
  and committed resource accounting. No second crop sleeper, per-resource timer
  or unbounded catch-up loop may be introduced.
- Harvest retires that crop's harvest authority once and emits the accepted
  two seeds plus 1–3 produce on the tray's turf. A repeated request emits nothing.
  Uproot, deletion and failed admission cannot produce an extra harvest.
- Growing state owns bounded progress observation. Ready state stops growth
  and its growth debit, while still receiving whatever bounded exposure
  observation is selected for H4. Removing every observer would miss storms.

The exact crop-host flag/interface and processing registry schema require source
review. They are not already present APIs. Do not change outdoor nutrition,
climate, water sampling, ready aging, RNG or specialized crop behavior to fit trays.

### Power interruption

A capacity check admits instantaneous demand; it does not certify a 60-second
service window. Define interval start/end, source settlement order, topology
changes, source exhaustion, consumer deletion and restart invalidation against
actual power processing. A candidate source-window witness must fail closed on
those changes and cannot carry a stale claim over reload. No such service-window
API is established by this document.

When power or supply is unavailable, productive growth pauses. Retained
partial progress and paid-credit treatment follow the selected transaction
contract. No catch-up credit accrues while offline. Fragile-crop shortage damage
requires the still-unsettled trait, duration and recovery policy; do not add a
universal timer as a convenience.

### Save/reload and teardown

Persist only validated durable crop identity/stage, reservoir contents, productive
remainder and any explicitly selected paid/escrow state. Exclude runtime anchors,
processing membership, power reservations and service witnesses explicitly through
the persistence contract. Reload must rebind owners, validate state, re-anchor time
and register at most one eligible observer after repairs. It must not award
offline progress, repeat a debit, revive a stale lease or duplicate a harvest.

Unplant, death and destruction release processing/power ownership exactly once.
Wrong or partially accepted manual fills must have a specified retained/refused
quantity and must not discard the donor's unaccepted contents. Dismantling refunds,
spill behavior and input reagent rejection are not silently settled here.

## Acceptance matrix and next source slices

| Case | Required result | Evidence needed |
| --- | --- | --- |
| Shared stage extraction | Outdoor callback order, eligibility, subtype dispatch and terminal behavior match the baseline; no tray activation | Source parity with meaningful mutation controls, compile, focused regressions and exact-head CI |
| Manual fill: empty, partial, full, mixed or rejected | Capacity never exceeds 60 U; donor loss equals accepted retained quantity under the selected input contract | Actual holder integration plus callback/precision negative controls |
| Six productive cycles | 6 N +12 U paid, six stages advanced, exactly one ready crop | Deterministic accounting cases and admitted real-source integration |
| Power interruption/exhaustion/reconnect | No uncertified productive time or free stage; no duplicate consumer demand or extra source debit | Source-order tests including mid-window invalidation and restart |
| Supply starvation/refill | Pause; no partial unpaid stage or negative reservoir; defined remainder behavior | Chosen transaction boundary and failure controls |
| Fragile shortage/poor weather | Only selected crops/predicates/timing apply; sheltered ready crops have no time expiry | Product policy still required, then focused cases; no invented default |
| Repeated harvest/remove/delete | At most one accepted yield; finite registries and released reservations | Actual host/harvest lifecycle and destructive negative controls |
| Save/reload at partial, ready, starved and unpowered states | One owner, preserved paid/remainder state, no offline gain or stale service witness | Save round trips against current serializer and load repair order |
| Crop-to-compost recycling | No free nutrient/water from rounding or duplicated output; upstream route costs retained | Recipe-specific finite ledger including every accepted harvest and returned seed |
| Research/build/bootstrap | Both prerequisites and era tier 6; paid 4 steel +2 glass +1 cable; hand fill only | Exact item/recipe/research integration and #3048 route coverage |
| Appearance/interaction | Tray and crop visible and usable with correct output location | Source/compile checks plus genuine client evidence where uncertainty remains |

Offline models or source projections support the named contracts only. They do
not establish native callback timing, actual chemistry, engine save compatibility,
client appearance, runtime acceptance or deployment. Historical results retain
their original parameters; they are not relabeled as tests of the accepted rates.

Proceed in narrow reviewable slices: (1) behavior-preserving shared crop-stage
helper and outdoor parity; (2) resolve/test quantity transaction and power-service
interfaces with their owners; (3) dormant tray host/scheduler/save integration;
(4) reviewed nutrient, research, construction and interaction wiring; (5) admitted
runtime/gameplay verification and separately authorized activation. A missing
mortality policy does not prevent slice 1. No production activation, pump, native
game/server/client start, merge or deployment is implied by this proposal.

Remaining product decisions are precise: nutrient product/recipe and physical
binding; fragile-crop list and shortage duration/recovery; poor-weather exposure,
damage/timing; bench/study pricing; dismantling policy. Quantity atomicity,
partial-cycle payment, source-window proof and save ownership are technical
contracts to resolve before resource-integrated gameplay. Accepted H1–H6 remain
fixed unless the user changes them.
