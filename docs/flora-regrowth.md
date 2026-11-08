# Wild plants and tree regrowth

Nomads maps (Gaia, the Persistence map and every other `/obj/map_metadata/nomads`
map) regrow flora on their own. Source: `code/modules/ecology/flora_regrowth.dm`.
Other maps keep `flora_regrowth = FALSE`.

## Wild plants

- A few ripe crops grow on natural outdoor grass, dirt and desert sand: herbs,
  mushrooms, wheat, oat, barley, rice, potato, carrot, cabbage, turnip, parsnip,
  beans, tomato, corn, pumpkin, zucchini, red pepper, celery, parsley, grapes,
  watermelon, agave, juniper, flax and cotton. Each species only grows in the
  biomes and seasons its farmed crop accepts (read from the real plant type).
- The target is `wild_plant_density` (2.5) per 1000 tiles of natural outdoor
  ground, capped by `wild_plant_cap` (250). The ground share comes from 600
  random turf samples every 30 minutes. Up to 4 plants grow per minute.
- A site must be empty, outdoor and more than 12 tiles from every player's body
  and eye, with no player construction, roof, crop or ploughed field within 3
  tiles. Wild bushes and trees do not count as construction.
- Wild plants do not grow, need water or use soil. Harvest them like a farmed
  crop (knife, scythe, hatchet or bayonet) for produce and two seeds (herbs give
  medicinal herbs, flax and cotton give fibre).
- Out of season (for example in winter) up to 8 unseen wild plants wither per
  minute.

## Tree regrowth

- Chopping a broadleaf, pine, palm or jungle tree (medpine, acacia, cherry) to
  zero health leaves a regrowing stump that remembers the tree. Trees lost to
  fire, shells, admin deletion or a world load leave no stump.
- Outside winter, each stump has a `100 / stump_regrowth_minutes` percent chance
  per minute (default 240 minutes on average) to grow back into the same tree,
  when its tile is still outdoor, unroofed, holds nothing built, dense or living,
  and no player is within 12 tiles.
- Dig a stump out with a shovel (5 seconds) or chop it to keep the land clear.
- Map tree spawners still refill forests within 7 tiles of each spawner, as
  before. Stump regrowth covers the rest of the map.

## Persistence

Wild plants are ordinary farming plants with `wild = TRUE`; farming plants save
every changed field, so the flag, stage and name restore. Stumps are wild
objects with an allowlist save; `regrow_type` is added through
`get_saved_vars()`. Both registries (`wild_plant_list`, `regrowing_stump_list`)
are runtime lists refilled by `make_wild()`, `New()` and `after_load()`. The
worker and the map policy fields are runtime only. The worker pauses during a
world save.

## Cost

One loop wakes per minute: one `prob()` per stump, at most 48 site checks
(each two `range(3)` scans), and 600 turf samples every half hour. Nothing scans
the world. Debug > Ecology Spawning Status prints the flora report too.

## Tests

`python3 tests/ecology_spawning/run_linux.py . tests/flora_regrowth/probe.dm`
(see `tests/flora_regrowth/README.md`).
