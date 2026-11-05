# Zombie city extraction

A procedurally generated, zombie-infested city that players of the Gaia shard
group visit to loot and extract home. Val approved the design on 2026-11-05.

- The city runs as a resetting raid world: a `RAID` region with
  `reset_minutes` (default plan 180) in the group, which never saves
  (`docs/persistence-raids.md`). Each boot generates a new city.
- Players arrive through any gate leading to the raid region and land at the
  city's insertion points. They leave from evacuation points at the city edge.
  Anyone still inside at the collapse is lost with their gear, and their home
  goes back to where they came from.
- Region travel carries packaged food, medicine, tools, magazines and unloaded
  guns besides materials and clothing (#3783). Wounds travel too.

The generator (`zombie_city_generate`, its markers and RNG) is built separately.

## Horde (`code/modules/zombie_city/horde.dm`)

The generator calls `zombie_horde_add_block(id, lo, hi, density)` per city
block. Density `sparse`, `normal`, `dense` or `infested` sets the block's
zombie count (2, 5, 10, 18). Counts become mobs only near players:

- a zombie appears 9 to 20 tiles from a player, out of sight, at most 3 per
  3-second tick, 15 near any one player and 60 in the world;
- a zombie with no player within 20 tiles for 60 seconds folds back into its
  block count; a kill lowers the count, so cleared blocks stay cleared. A
  player one floor up or down still counts as near, so climbing to an upper
  floor does not make the chase vanish (zombies stay on the ground floor and
  do not spawn while nobody is on it);
- gunfire calls `zombie_horde_noise` (20 tiles, 6 with a silencer) and idle
  zombies walk toward it for 30 seconds;
- a zombie notices people within 7 tiles in line of sight, day or night
  (`hearers`, so darkness doesn't hide anyone, but walls do). Otherwise it
  shambles toward the nearest living person within 15 tiles.

Horde zombies are never saved and their corpses are removed after five minutes.
Nothing runs until a block is registered.

## Loot (`code/modules/zombie_city/loot.dm`)

The generator calls `zombie_city_roll_loot(turf, table, tier)` with table
`residential`, `grocery`, `pharmacy`, `medical`, `hardware`, `garage`,
`police` or `military` and tier 1 to 3. Each entry needs a research age
(`map.ordinal_age`) and a minimum tier; salvage materials have no age. A tier
rolls 1-2, 2-3 or 3-4 items; guns may come with one magazine of their own type.

Evidence: `tests/zombie_city/horde_probe.py` (see its README).

## City world (`code/modules/zombie_city/world.dm`)

- At round start, a map whose metadata declares `zombie_city = TRUE` calls the
  generator: `zombie_city_generate(seed, 1, 0)`, looked up by name, with
  a random seed from 1 to 16777215. The seed is written to the game log and world log.
- The generator calls `zombie_city_add_insertion(turf)` and
  `zombie_city_add_evacuation(turf, ordinal)`. Until it does, the hook reads
  the returned layout's `entries` and `exits`.
- Arrivals land at an insertion point with nobody within 3 tiles.
- Evacuation points (`/obj/structure/region_gate/raid_exit/zombie_city`) open
  two at a time, in ordinal order, moving on every 20 minutes. Leaving takes
  a 30-second wait at an open one, and hurt raiders may leave.
