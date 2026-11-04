# Husbandry feed and products

Source audit for #3051's "adequate feed costs" item. This page records how farm
animals get hungry, what feeds them and what they produce, so balance changes
can start from the actual numbers. Population caps are in
[animal-population-bounds.md](animal-population-bounds.md). Life ticks run
about once every 2 seconds. Times below assume that rate and are
approximate.

## Hunger

Code: `code/game/mob/living/simple_animal/simple_animal.dm` (`Life()`, `feed()`)
and `simple_ai.dm` (`check_food()`).

- Every animal starts at `simplehunger = 1000`. An animal with any diet flag
  (herbivore, granivore, carnivore, predatory carnivore, scavenger) loses 1
  per tick. A full animal reaches 0 after about 33 minutes.
- At 0 it takes a tenth of its max health as damage and hunger resets to 60, so
  an unfed animal takes damage roughly every 2 minutes until it dies.
- Animals look for food when idle with hunger under 220, and always under 180.
- Ploughing with cattle costs 65 hunger per tile. Draft animals pay
  `animal_draft_hunger_cost()` per step.

| Food | Who eats it | Hunger gained |
| --- | --- | --- |
| Grass turf (grazing, reduces `grassamt` until the turf turns to dirt) | Herbivores | 550 |
| Loose wheat within 2 tiles | Herbivores | 550 |
| Hand-fed wheat, oat, barley or rice | Herbivores | 550; refused above 800 |
| Seeds on the ground or hand-fed | Granivores | 500; hand-fed refused above 800 unless it refills an egg |
| Growing crop plant (destroys the plant) | Granivores | 400 |
| Corpses, meat and other food | Carnivores and scavengers | 400 |

Animals of medium size and larger leave dung when they eat.

## Diets by species

| Species | Diet flags | Notes |
| --- | --- | --- |
| Cattle, bison, goats, sheep, camels, deer | Herbivore | Graze grass, so a pasture needs regrowing grass or grain feed |
| Pigs and wild boars | Granivore, carnivore (boars also hunt) | Eat seeds, crops and meat; cannot be fed grain by hand |
| Chickens and turkeys | Granivore | Seed feeding also refills eggs |
| Wolves and bears | Carnivore, predatory | Hunt and scavenge |

## Products

| Product | Source | Rate |
| --- | --- | --- |
| Milk | Cow, bison cow | 5% chance per tick to add 5-10 units; udder holds 50 (about 4-5 minutes to fill) |
| Milk | Pig and boar gilt | Same as cows |
| Milk | Goat | 5% per tick, 3-5 units |
| Milk | Ewe | 2% per tick, 3-5 units |
| Wool | Sheep, both sexes | One stack per shearing (15 s with shears), regrows after 8 minutes |
| Eggs | Hen, turkey hen | One egg every 120 ticks (about 4 minutes) while `eggsleft > 0`; each bird starts with 5 |
| Eggs (refill) | Hand-feeding seeds | +1 egg per seed fed, up to `maxeggs` (5) |
| Meat, hide, bone | Butchering | Per-type `meat_amount`; see [animal-harvesting.md](animal-harvesting.md) |

## Fixed since this audit

- Hens could never be refilled once they had laid all their eggs. The refill
  check was `eggsleft != FALSE`, and `eggsleft` is 0 (FALSE) for exactly those
  hens, so each hen gave 5 eggs for life. Egg layers now carry
  `lays_eggs = TRUE` and seed feeding refills them up to 5.
- Hand-feeding grain only accepted wheat. `istype(O, GRAIN)` expanded to
  `istype(O, /wheat||/oat||/barley||/rice)`, and `||` returns the first path,
  so oat, barley and rice were silently ignored. Each grain is now checked.
- Bison had no diet flag, so they never got hungry. They now graze like
  cattle, and bison cows are milked through the same `try_milk()` as cows.
- `tests/animal_registry/test_feeding_contract.py` covers all three.

## Open balance questions

These are left for the maintainer. They change how farming feels, not just
correctness:

- Grazing turns grass into dirt with no regrowth cost to the herd owner beyond
  moving animals; whether pastures need managing depends on grass regrowth.
- Milk and egg rates do not depend on how well fed the animal is.
- Hunger only reaches 0 after about half an hour, so feed is cheap compared with
  what the animals produce.

No in-game measurement backs these rates; they are read from source.
