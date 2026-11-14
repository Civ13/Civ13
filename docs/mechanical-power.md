# Mechanical power

`code/modules/1713/mechanical_power.dm`, sprites
`icons/obj/mechanical_power.dmi` (drawn by
`tests/sprites/create_mechanical_power.py`), suite `tests/mechanical_power`.

## The drive

A prime mover (`/obj/structure/workshop_machine/mover`) drives the fastened
workshop machines and hoists within one tile of it. There is no network, no
process and no list of movers: a machine calls `driven_time(base)` when it
starts a step, which asks `mechanical_drive_factor(src)` for the lowest time
share among the turning movers next to it. A mover answers from what stands
around it at that moment and updates its own icon when asked or examined.

Driven today: potter's wheel, mason's saw, cement mixer, shear legs and the
treadwheel crane. A step never takes less than half a second.

| Mover | Cost | Research | Turns when | Step time |
| --- | --- | --- | --- | --- |
| Treadwheel | 12 wood, shaft, 2 bearings | Stone Masonry | a standing, unrestrained person is on its tile | 65% |
| Horse gin | 10 wood, gear, shaft, bearing | Resource Processing | a living horse or head of cattle is within one tile | 50% |
| Mill wheel | 14 wood, gear, shaft, 2 bearings | Watermills | a tile within one of it has a river current (not still water or ice) | 40% |
| Windmill | 16 wood, gear, shaft, 2 bearings | Watermills | it stands in an outside area and `map.windspeedvar` is at least 1 | 70% light, 50% moderate, 40% strong or gale |

The parts are the standard `/obj/item/machine_part` items in any material,
paid as whole items through `config/craft_needs.json`. They are consumed by
the recipe; movers keep no part slots or wear (the alternate-materials work
owns that design).

Movers are workshop machines: wrench to fasten, hammer on harm intent to
dismantle, and too heavy for a ladder. The treadwheel is not dense so that a
person can stand in it.

## Trip hammer

`/obj/structure/workshop_machine/trip_hammer`: 10 wood plus 6 iron and a
shaft, Watermills. It does nothing by hand. `/obj/structure/anvil` asks
`forge_time(base)` at both forging waits in `blacksmithing.dm`: when a
fastened trip hammer within one tile has a turning prime mover next to it
(`striking()`), the job takes half the time, never less than a second. The
hammer plays its striking loop once when a job starts. Costs, recipes and
research checks at the anvil are unchanged.

A rolling mill was planned beside it and is not built: the game has no plate,
sheet or rail stock for it to roll.
