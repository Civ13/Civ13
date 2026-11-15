# Canals and pound locks

Code: `code/modules/1713/canals.dm` (with hooks in `trench.dm`, `aqueducts.dm`
and the boat movement checks). Art: `icons/obj/canal_lock.dmi` from
`tests/sprites/create_canal_lock.py`. Probe: `tests/canals/probe.dm`.

A canal is a dug trench that floods from water beside it (trench.dm). Flooding
now keeps to gravity: a trench floods only from water standing at least as high
as its own ground (`canal_can_flood`, terrain heights from
`terrain_height_at`). On maps without height data everything is level and
nothing changes.

Canal water stands at its tile's ground height. Where a canal steps, a boat
can't pass from one level to the other (`canal_step_blocked`): rafts, dugouts,
small boats, modular boats and ships all check it. Natural rivers and the sea
are not affected; the rule applies only where one of the two tiles is a canal.

**Pound lock** (12 stone, Wagons & Ships): built on a flooded canal tile at the
step. It faces the higher side. Its chamber stands at the lower or the higher
level; boats move between the chamber and the side it matches. Working it by
hand (10 s) fills or empties the chamber to the other level. A flight of locks
climbs several levels.

An aqueduct channel beside a dry trench floods it when the channel's water
stands at least as high as the trench's ground, so a summit pound can be fed
from higher ground.
