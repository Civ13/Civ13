# Dug wells

`code/modules/1713/dug_wells.dm`. Players dig their own wells instead of
needing a natural puddle to build one over. Nothing ticks: a dug well works
out its water when someone uses or examines it.

## Digging

A shovel's dig menu has **Well**. The first spit makes a waterhole
(`/obj/structure/sink/puddle/waterhole`, `dug_depth` 1); choosing Well again on
the tile, or using the shovel on the hole, digs a spit deeper or fills it in.
Each spit takes 15 seconds plus 5 for each spit already dug (faster with a
better shovel and more strength), leaves one dirt pile, and tells the digger
what the earth at the bottom is like: dry, damp (water a few spits down), wet
(one more spit) or seeping.

A well cannot be dug on built floors, in water, in a drain, cesspit or latrine,
at a tunnel entrance, or where a puddle or well already is.

## The water table

`well_water_table(turf)` is the depth to water in spits:

    1 + 0.5 x (terrain height - river stage of the tile's reach)

plus 2 in desert, 1 in semiarid and 0.5 in savanna areas, less 0.5 in jungle,
never under 0.5; 0 under floodwater. A dug well adds 1 while its `dry` flag is
set (dry season, heat wave event) and 1 under a heat weather system. The
standing water is `dug_depth` less that. Without a height file the land counts
as level 0.

On Gaia about 60% of the land is under level 2, 87% under level 8 and almost
all under level 14, which are the limits of the three kinds of well.

## Linings

| | Deepest | Made with | Notes |
| --- | --- | --- | --- |
| Waterhole | 2 spits | shovel | A puddle: muddy water (the puddle illness rolls), half the recharge |
| Timber-lined well | 5 | 4 wood, Primitive Construction | `/obj/structure/sink/well/timber` |
| Stone well | 8 | the stone, sandstone and marble well recipes | The existing well types |

Well recipes need a puddle or a dug hole on the builder's tile
(`well_build_site()`), and a lining may replace another kind on a dug well
(`well_relining()`). The new well takes over the hole in
`/obj/structure/sink/well/on_runtime_spawn()`: depth, water, the dry flag and,
from a well, the foul flag. A well over a natural puddle has `dug_depth` 0 and
is a spring as before: 750 units, refilled by the old loop.

## Water

A dug well holds 150 units for each level of standing water (at most 750) and
gains 100 a minute per level, counting at most 3 levels; a waterhole gains
half. `dug_settle()` adds what has seeped in since the last use. Water more
than 2 spits down cannot be drunk from the hands and takes longer to draw into
a container. A drink from the hands takes 10 units.

Dug wells are wells and waterholes are puddles to the rest of the game, so
waste and sewage nearby, floodwater and soap work on them unchanged.

## Fittings

`/obj/structure/well_fitting` is built standing on any lined well (a craft
guard refuses it elsewhere) and stays on the well's tile as its own object;
clicks on it go to the well, a newer fitting replaces the older, and it is
deleted with the well.

| | Made with | Draw |
| --- | --- | --- |
| Windlass and pail | 4 wood and 2 rope, Cooperage & Containers | 2 seconds |
| Cast iron hand pump | 6 iron, Iron Tools | 1 second |

With a fitting, one drawing fills the whole container (`draw_into()`, with the
same foul-water rule as the sink code) and water at any depth can be drunk
from the hands.

## Tests

- `python3 tests/ecology_spawning/run_linux.py . tests/river_flow/wells_probe.dm` (native).
- `tests/river_flow/test_flood.py` `DugWellsTest` (wiring, recipe, art states).
- `python3 tests/sprites/create_wells.py --check`.
