# Outdoor bootstrap map inventory

Run `scripts/check-outdoor-bootstrap.py` with a verified Python interpreter.
It reads placed DMM grid cells, resolves inherited area climate and water salinity,
and reports coordinates of clear plain grass/dirt within two tiles of non-ice
fresh water. Unused tile definitions do not count. It does not launch the game or
change maps, saves, research, herbs or resource quantities.

The first six rows are the inventory at master `98be298dc`; the two Americas
rows were taken on 2026-11-15 with their fertile river banks.

| Map | JoinLateCiv landmarks | Small bushes | Placed seed stacks | Fresh water tiles | Clear soil within two tiles of water |
| --- | ---: | ---: | ---: | ---: | ---: |
| Continental | 24 | 1224 | 182 | 3533 | 1965 |
| Pangea | 24 | 0 | 309 | 9997 | 3630 |
| New World | 4 | 501 | 53 | 3472 | 957 |
| Mediterranean | 12 | 1149 | 159 | 3730 | 1670 |
| Gaia | 9 | 135 | 0 | 12299 | 7981 |
| Europe | 18 | 502 | 76 | 18441 | 4216 |
| Americas, north | 18 | 0 | 0 | 31937 | 18208 |
| Americas, south | 18 | 0 | 0 | 49124 | 31287 |

## Seeded maps: the Americas

The Americas maps place no bushes or seeds: `seed_the_map()` grows the wild
plants at round start from each tile's ground and climate, and a new nomad
starts on a random open tile. The report therefore also gives, per climate,
`bush_seeding_ground_by_climate` (clear ground whose `plant()` can grow a small
bush) and `farm_ground_by_climate`: clear ground a plough or digging stick
works directly, how much of it lies within two tiles of fresh water, and how
much ground beside water becomes workable through ordinary play (authored snow
cleared with a spade, flooded ground in the dry season).

| Map | Climate | Bush-seeding ground | Ploughable | Ploughable by water | Clearable by water |
| --- | --- | ---: | ---: | ---: | ---: |
| North | tundra | 4601 | 0 | 0 | 4580 |
| North | taiga | 75916 | 5389 | 690 | 17493 |
| North | temperate | 43212 | 43212 | 9329 | 0 |
| North | semiarid | 46452 | 29067 | 5406 | 0 |
| North | desert | 4792 | 1695 | 1695 | 0 |
| North | savanna | 4116 | 200 | 180 | 0 |
| North | jungle | 11753 | 1563 | 908 | 255 |
| South | tundra | 991 | 0 | 0 | 431 |
| South | taiga | 7389 | 313 | 3 | 1587 |
| South | temperate | 48987 | 48987 | 6761 | 0 |
| South | semiarid | 58168 | 35870 | 4955 | 0 |
| South | desert | 3783 | 1477 | 1477 | 0 |
| South | savanna | 91975 | 14959 | 13015 | 0 |
| South | jungle | 152558 | 7520 | 5076 | 2756 |

Dry savanna grass, jungle grass, dust and desert sand cannot be ploughed. Before
2026-11-15 the Americas' savanna and desert had no other ground, so a nomad who
started there could not farm in their own climate at all, and no desert ground
grew a seed bush. The generator now lays plain grass and dirt along savanna
rivers and lakes and dirt along desert ones (`tests/americas_maps/build.py`),
and desert dirt and dust grow sparse scrub bushes. The `americas_maps` suite
fails if any land climate on either map lacks bush ground or farm ground beside
fresh water.

Pangea has direct seed placements, including food crops, and no placed small
bushes. Its bush-foraging route is not established by the catalog test. Gaia has
placed small bushes and no direct seed stacks. Counts describe stacks, not seed
units, and exclude runtime generation. Each report includes a soil/water coordinate
witness and bush counts by climate. Ice is excluded conservatively.

The source route requires a knife on Help intent to forage a small bush, a plough
to prepare suitable soil, and a compatible seed. Global crafting includes a wooden
plough recipe; Basic Agriculture gates plough recipes. Irrigation gates shovel
channel construction. Jungle grass and jungle dirt are rejected by the plough
action, so the inventory conservatively counts only clear plain grass/dirt and
flooded dirt. It excludes all tiles with objects or mobs from clear-soil counts.

This is resource-placement evidence only. A bush anywhere in the same map or
climate does not establish access from a spawn, a safe walking route, available
tools/materials, research completion, seed/soil compatibility, planting, harvest,
seasonal survival or save/load behavior. Trees, blocked soil, other soil subtypes
and runtime terrain changes are not analyzed. Those acceptance steps remain open
under #3048 and #3049; this inventory must not mark either issue complete.
