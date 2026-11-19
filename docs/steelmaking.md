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

## Crucible steel

Research **Crucible Steel** (`crucible_steel`, Industrial, era 2, needs Iron
Smithing; it also opens the steel-faced anvil). Code:
`code/modules/1713/crucible_steel.dm`.

An unfired crucible (1 clay) fires into `/obj/item/weapon/steel_crucible`.
Pack it with 2 wrought iron and 1 charcoal and seal it in hand (3 s). A
kiln takes up to 4 sealed crucibles (`accept_crucible`) and burns 2 more
fuel per crucible each firing (`crucible_fuel`). After each kiln firing
(`fire_crucibles`) a crucible only gains heat if the firing started under
a bellows blast; after 3 blown firings it either cracks (25% for Crafting
1.0, 5% to 40% by skill) and the melt is lost, or breaks open on 1 fine
steel. Crucibles come out of the kiln after every firing.

## Industrial works

Code: `code/modules/1713/steel_works.dm`. Every works is a
`/obj/structure/steel_works`: load its charge metal and fuel, then light it
by hand or with a flame (automation starts it once the charge is full). The
firing runs on an `addtimer` loop with `burn_left` saved. Empty gives back
exactly what went in (`loaded`). Fuel units: charcoal 2, coke 3, coal 3
where allowed.

| Works | Node | Charge | Fuel | Time | Out |
| --- | --- | --- | --- | --- | --- |
| Coke bank (15 clay) | Blast Furnaces & Coke | 5-20 coal | its own coal | 5 min | 0.6 coke per coal |
| Finery forge (15 iron) | Blast Furnaces & Coke | pig iron | charcoal, coke; 2 + 1 per pig | 90 s | 1 wrought iron per 2 pig |
| Cementation furnace (30 stone) | Blast Furnaces & Coke | 5-30 wrought iron | charcoal; 6 + 2 per bar | 15 min | blister steel, 15% uneven bars stay iron (less with skill) |
| Puddling furnace (30 stone) | Blast Furnaces & Coke | 2-10 pig iron | coal, coke, charcoal | 3 min | 0.8 wrought iron per pig if stirred, half if not |
| Bessemer converter (40 iron) | Steelmaking | 5-15 pig iron | coke; 3 + 0.5 per pig | 2 min blow | tipped in the window after the flame drops: 0.9 steel; early: 0.9 pig iron; late or never: 0.8 wrought iron |
| Open hearth (50 stone) | Open Hearth Steel | 5-40 pig iron or steel | coal, coke, charcoal; 6 + 1 per unit | 10 min | fine steel: 0.9 per pig, scrap steel back whole |
| Electric arc furnace (40 steel) | Alloys | 5-40 steel, pig iron or wrought iron | none; 200 power | 4 min powered | 0.95 fine steel per unit; pauses without power |

Puddling: an empty hand during the firing stirs for 5 s; success is 60%
plus 80% per Crafting point above 1 (30% to 95%). Bessemer: the flame drops
between 75 and 105 s into the blow; the tipping window is 10 s times the
firer's Crafting coefficient (0.5 to 2).

Research: **Blast Furnaces & Coke** (`blast_furnaces`, Industrial era 3,
needs Iron Smithing and Watermills) now teaches the blast furnace, which
needs a water wheel or windmill within reach (`mechanical_drive_factor < 1`,
`firing_refusal()`). Steelmaking needs Blast Furnaces & Coke. **Open Hearth
Steel** (`open_hearth`, era 5) needs Steelmaking and Factories.

Pig iron no longer hammers into steel on an anvil; the mapped industrial
furnace (`/obj/structure/machinery/factory`) melts iron ore into pig iron.
Coke burns in kilns, factory furnaces and bloomeries as well.
