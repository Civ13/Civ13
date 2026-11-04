# Animal population bounds

Per-species table for #3051 ("proof that every species' population is
bounded"). It lists every simple animal that reproduces on its own, the global
registry that caps it and any local crowding check. Source of truth is
`code/game/mob/living/simple_animal/`; registries are declared in
`code/global.dm`. `tests/wildlife_registry/test_population_caps.py` checks the
caps below and fails if a new file sets `pregnant = TRUE` without a cap.

A global cap stops new conceptions or hatching once the registry reaches the
number. Animals already pregnant still give birth, so a registry can overshoot
by at most the number of females pregnant at that moment. Death and `Destroy()`
remove the animal from its registry (#3241, #3358, #3360); revival and save/load
re-registration are outside this table.

| Species | Registry | Global cap | Local check | Breeding |
| --- | --- | --- | --- | --- |
| Chicken (hen, chick) | `chicken_count` | 50 | Egg starts hatching only with at most 5 chickens/chicks within 3 tiles | Hen lays an egg; egg hatches a chick after 400 grow steps |
| Turkey | `turkey_count` | 35 | Same egg check, at most 5 turkeys nearby | Hen lays an egg; egg hatches a turkey chick |
| Cattle (cow, bull) | `cow_count` | 30 | Conception cancelled with more than 5 cattle in 15x15; then a 300-tick pause | Cow next to a conscious bull, 600-tick pregnancy |
| Pig | `pig_count` | 30 | Same 15x15 check | Gilt next to a boar, 600 ticks |
| Wild boar | `boar_count` | 30 | Same 15x15 check | Gilt next to a boar, 600 ticks |
| Goat | `goat_count` | 35 | Same 15x15 check | Female next to a male, 600 ticks |
| Sheep | `sheep_count` | 35 | Same 15x15 check | Ewe next to a ram, 600 ticks |
| Bison | `bison_count` | 30 | Same 15x15 check | Cow next to a bull, 600 ticks |
| Deer (not dik-dik) | `deer_count` | 30 | Same 15x15 check | Doe next to a stag, 600 ticks |
| Wolf | `wolf_count` | 20 | None | She-wolf next to a male, 900 ticks |
| Bear | `bear_count` | 12 | None | Sow next to a boar, 1500 ticks |
| Frog | none | none | Lays only with at most 2 frogs within 6 tiles; egg hatches only with at most 2 within 5 tiles | Rare egg laying near water |

Wolves and bears had no global cap until this table was written; their
registries existed but only fed the admin count. Bear sows and cubs were also
never registered, because only `bear/boar/New()` added to `bear_count`. Both are
fixed alongside this document. The wolf and bear caps are lower than the
grazing animals' because they are hostile predators.

## Not breeding, listed for completeness

- Frogs are bounded by density only: each lay or hatch needs a nearly empty
  area, so their total is limited by the amount of water on the map.
- Wolf and bear caves (`code/game/objects/structures/animalspawner/`) spawn
  animals only when none of that kind is nearby, so each cave keeps at most a
  small local group. Spawned animals join the same registries and count
  toward the caps above.
- Mice, cockroaches and flies come from rotting food and do not breed.
  Mosquitoes come from standing water closets. Neither is part of husbandry.
- Dik-diks never conceive.

## Not covered

Feed costs, product rates (eggs, milk, wool) and preservation timing are the
other open parts of #3051. Aquaculture scope is a design decision for the
maintainer. No in-game or save/load measurement backs the numbers here; they
are read from source.
