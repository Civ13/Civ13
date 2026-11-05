# Zombie city extraction

A procedurally generated, zombie-infested city that players of the Gaia shard
group visit to loot and extract home. Val approved the design on 2026-11-05.

- The city is its own region world of kind `CITY` in the group, never saved,
  and generated from a new seed every cycle (about three hours).
- Players arrive by a city road gate (region travel) without moving their home
  world, and leave from rotating evacuation points at the city edge. Anyone
  still inside when the cycle ends is lost with their gear.
- Region travel carries a wider list on this route: packaged food, medicine,
  tools, ammunition and unloaded firearms, beside materials and clothing.

The generator (`zombie_city_generate`, its markers and RNG) is built separately.

## Horde (`code/modules/zombie_city/horde.dm`)

The generator calls `zombie_horde_add_block(id, lo, hi, density)` per city
block. Density `sparse`, `normal`, `dense` or `infested` sets the block's
zombie count (2, 5, 10, 18). Counts become mobs only near players:

- a zombie appears 9 to 20 tiles from a player, out of sight, at most 3 per
  3-second tick, 15 near any one player and 60 in the world;
- a zombie with no player within 20 tiles for 60 seconds folds back into its
  block count; a kill lowers the count, so cleared blocks stay cleared;
- gunfire calls `zombie_horde_noise` (20 tiles, 6 with a silencer) and idle
  zombies walk toward it for 30 seconds.

Horde zombies are never saved and their corpses are removed after five minutes.
Nothing runs until a block is registered.

## Loot (`code/modules/zombie_city/loot.dm`)

The generator calls `zombie_city_roll_loot(turf, table, tier)` with table
`residential`, `grocery`, `pharmacy`, `medical`, `hardware`, `garage`,
`police` or `military` and tier 1 to 3. Each entry needs a research age
(`map.ordinal_age`) and a minimum tier; salvage materials have no age. A tier
rolls 1-2, 2-3 or 3-4 items; guns may come with one magazine of their own type.

Evidence: `tests/zombie_city/native_probe.py` (see its README).
