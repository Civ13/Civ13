# Outdoor bootstrap map inventory

Run `scripts/check-outdoor-bootstrap.py` with a verified Python interpreter.
It reads placed DMM grid cells, resolves inherited area climate and water salinity,
and reports coordinates of clear plain grass/dirt within two tiles of non-ice
fresh water. Unused tile definitions do not count. It does not launch the game or
change maps, saves, research, herbs or resource quantities.

Inventory at master `98be298dc`:

| Map | JoinLateCiv landmarks | Small bushes | Placed seed stacks | Fresh water tiles | Clear soil within two tiles of water |
| --- | ---: | ---: | ---: | ---: | ---: |
| Continental | 24 | 1224 | 182 | 3533 | 1965 |
| Pangea | 24 | 0 | 309 | 9997 | 3630 |
| New World | 4 | 501 | 53 | 3472 | 957 |
| Mediterranean | 12 | 1149 | 159 | 3730 | 1670 |
| Gaia | 9 | 135 | 0 | 12299 | 7981 |
| Europe | 18 | 502 | 76 | 18441 | 4216 |

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
