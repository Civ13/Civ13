# Steelmaking

Realistic steel by era, from the plan Val approved on 2026-11-19
(Claude Doc "Realistic steelmaking plan"). Steel is made either by adding
carbon to iron (bloom, carburizing, crucible) or by burning it out of pig
iron (finery, puddling, Bessemer, open hearth). Medieval steel is a trickle;
industrial steel is bulk but needs big plant.

Code: `code/modules/1713/steel_grades.dm`; checks: `tests/steelmaking/`.

## Grades

Steel stacks come in three grades. Each is its own stack type
(`stacktype = type`), so every recipe that takes steel takes any grade but
stacks of different grades never merge.

| Grade | Path | Forged quality | Source |
| --- | --- | --- | --- |
| Blister steel | `/obj/item/stack/material/steel/blister` | x0.9 | Steely bloom, carburizing |
| Steel | `/obj/item/stack/material/steel` | x1.0 | Recycling, industrial routes |
| Fine steel | `/obj/item/stack/material/steel/fine` | x1.1 | Folded tamahagane, crucible |

`forge_stack_recipe` passes each forged piece to `apply_stock_grade()`,
which multiplies its `crafting_quality` and records `forged_grade`. The
quench tub then hardens it to `QUENCHED_QUALITY * forged_grade` (blister
1.08, steel 1.2, fine 1.32).

## Bloomery fuel

Bloomeries and blast furnaces burn from `bloomery_fuel_rates`: a charcoal is
2 fuel, a log, plank or bamboo 1, a branch 0.5. Raw coal is refused (its
sulphur ruins iron; it can be coked later), and leaves and dung no longer
smelt. A firing costs `firing_fuel_cost()`: 2 to bring it to heat plus 1 per
ore (half per iron sand), so ten ore take six charcoal. Hand lighting and
automation both check `has_firing_fuel()`. Kilns and lime kilns keep their
flat firing and old fuel table.

## Steely bloom

A bloomery firing started under a bellows blast (`blown_firing`) leaves each
unit of its sponge iron steely with a 10% chance
(`/obj/item/stack/ore/iron_sponge/steely`). On any anvil that works iron it
sorts 1:1 into blister steel.

## Carburizing pot

`/obj/structure/carburizing_pot` (`code/modules/1713/carburizing.dm`), 8
clay, Iron Smithing. Pack up to 10 wrought iron bars and up to 3 iron tools
(`/obj/item/weapon/material` of iron) with charcoal: one per bar and per tool
plus 4 to hold the heat. An empty hand seals it (5 s) and fires it for ten
minutes on an `addtimer` loop with `burn_left` saved. Each bar has an
uneven chance (20% for Crafting 1.0, down to 5% for skilled smiths) of
staying iron; the rest come out as blister steel. Packed tools are
case-hardened: quality x1.15, capped at 1.25. The pot cracks one firing in
five; a hammer unpacks a cold pot, or breaks up an empty one.

On an anvil that works steel, blister steel offers a fold: every 2 bars
weld and draw out into 1 plain steel (shear steel), or it can be forged as
it is.
