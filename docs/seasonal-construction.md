# Seasonal construction deterioration (draft balance)

This mechanic runs only while `map.persistence` is true. That flag is set by
the configured `PERSISTENCE` mode or the existing admin Persistence toggle;
map names, the display string, saving being available, and Persistent Chad Mode +
alone do not enable it. It never uses the world's displayed year or research
tier. A straw design built in 2023 still has straw durability.

## Exact opt-ins and rates

The table is an explicit design/material-era policy, not a claim that these
designs become unavailable in later eras. Only the exact types below opt in;
children require their own reviewed entry. Constants in
`code/processes/seasonal_construction.dm` are the balance tuning points.

| Design | Era/material profile | Damage per counted season | Undamaged, unrepaired lifetime |
| --- | --- | --- | --- |
| `/obj/covers/straw_wall` | early woven fibre | 1/16 of type's initial health (6.25%) | 16 seasons |
| `/obj/roof/thatch`, `/obj/roof/palm` | early fibre/leaf roofing | 1/16 (6.25%) | 16 seasons |
| `/obj/covers/dirt_wall` | early earth construction | 1/32 (3.125%) | 32 seasons |
| `/obj/covers/wood_wall`, `/obj/covers/wood_wall/bamboo`, `/obj/covers/wood_wall/log` | early timber construction | 1/64 (1.5625%) | 64 seasons |
| `/obj/roof/wood` | timber roofing | 1/64 (1.5625%) | 64 seasons |

Damage is additive to existing combat/fire damage. Cover repair keeps its existing
health behavior; future seasons resume the same material rate. There is no separate
unrepairable lifetime limit. At four counted transitions per year, these nominal
lifetimes are 4, 8 and 16 game years. Wall-clock duration depends on that map's
season cadence; this feature does not change cadence or game-year progression.

Concrete, glass, steel, stone, brick, clay tile roofs, vault walls, unknown designs,
all floor covers, scenery/turf walls, doors, supports, furniture, machines and
items have **zero added deterioration**. No broad Wood parent or material string
enables decay. Automatic paired roof/floor slabs are excluded even if the engine
uses `/obj/roof/wood` beneath a modern upper floor. Reviewing more designs or
profiles is future balancing work.

## Seasons and persistence

The existing actual-transition hook still increments the abandoned-debris clock
exactly as before. A separate construction clock observes that same hook and
counts only enabled persistence transitions. Repeated calls for the same season
label do not charge construction twice. Delayed terrain phases, startup climate
assignment and ordinary scheduler passes do not count as seasons. Forced admin
transitions retain the existing `advance_decay` choice: preserving decay age
adds nothing; explicitly advancing it counts once. Noncycling maps have no hourly
fallback. Transitions during save/load holds add no new construction age.

Only anchored, direct-on-turf, complete wall covers and eligible roofs accrue
wear when serviced or exported. Off-turf, unanchored or incomplete observations
rebase the runtime clock without accruing. These construction designs are normally
immobile; the sweep does not reconstruct unobserved admin relocation history.
Disabling persistence suspends damage. Previously earned debt remains payable
after re-enabling; transitions made while disabled are never charged.

Each candidate owns a durable `seasonal_construction_due` count. Its normal
`before_save()` folds unserviced transitions into debt without damaging or deleting
anything. Health and debt are saved together; roof saves explicitly include debt
because roofs otherwise use a partial field allowlist. `after_load()` rebuilds
registry membership and anchors the runtime observation to the current process.
Old saves start with zero debt and receive no retroactive aging. Runtime indexes,
observation clocks and the map's last observed season label are excluded on
export and historical import, including custom serialization of `tmp` variables.
No world metadata schema or existing save bytes are migrated by this patch.

## Scheduling, destruction and contents

A standalone low-priority process visits at most 64 registry candidates per
10-second dispatch and stops after a candidate if total tick usage reaches 20%.
A swap-removal cursor retains the remaining population for later dispatches.
Unserviced transitions accumulate, so missing one dispatch loses no age. There
are no new world scans, population copies, object timers, or per-season work
queues. Constructors and deletion hooks maintain only explicitly opted-in designs.
Existing destruction callbacks are indivisible and can exceed the tick target;
this is not a hard latency or memory guarantee.

Zero health uses `qdel()` and normal destruction hooks, including roof area,
lighting, neighboring roof support and building callbacks. It never invokes
`Destroy()` directly. Objects on the building's turf stay on that turf; ordinary
support loss can still collapse roofs and affect occupants as it does today.
If the retiring structure itself contains atoms, the terminal damage/debt debit
waits until it is empty, preserving nested items instead of recursively deleting
them. Paired slabs are excluded, so their second face cannot delete hidden storage
through this mechanic. No custom content spilling, building leveling, save import,
server restart, deployment or Gaia-cycle inclusion is part of this change.

## Evidence and remaining acceptance

`tests/seasonal_construction` projects a restricted, explicit set of production
DM bodies into Python. It checks rates, exclusions, mode toggles, forced/repeated
transitions, catch-up, repairs, existing damage, save debt, legacy rebasing,
contained-item deferral, registry disposal, batch tails and budget resumes.
Named controls demonstrate nonpersistence counting, replay and debt loss; the
contents control demonstrates the deletion attempt. These checks do not prove
native list, GC, codec, rendering, performance or connected-player behavior.

`prepare.py` prepares production sources and a synthetic 8x8x1 native fixture
without any compiler/runtime launch. It can prepare mode, replay, save-debt and
paired-slab omission controls. The fixture uses real construction, damage, qdel,
entry save/load and historical runtime-field rejection with startup disabled,
closed/refused ports and rejected clients. Packets contain source hashes and
depend on the retained checkout/assets. Preparation is not compilation or a native
pass. There is deliberately no execution mode in that tool.

Local native tests are held due to an uncertain movement launch and denied process
inventory. The existing authorization deadline is 2026-10-24 14:48:30 UTC, and this
patch does not extend it. After the parent resolves that hold and reviews source
and containment, native acceptance still needs warning-free BYOND 516.1681
compilation, the prepared fixture and controls, an independently reviewed bounded
runner with zero-listener/exit evidence, fresh-process whole-world saves for
round-v1 and round-v2, actual season-queue transitions, normal wall/roof/support
destruction, and player screenshots/reproduction steps. No native or graphical
result is claimed here. Keep balancing in draft review.
