# Water for crafting stations

`code/modules/1713/station_water.dm`. Part C of the flowing water plan; water
quality is in [water-quality.md](water-quality.md) and pollution downstream in
[river-foul.md](river-foul.md).

## Station tanks

Any `/obj/structure` can carry a tank by setting `water_capacity` (units it
holds) and `water_per_use` (units each use takes); `water_store` is what it
holds now and is the only thing saved. A station adopts it by calling:

- `station_water_pour(item, user)` at the top of `attackby`: an open container
  holding water pours into the tank, up to capacity. Only the water moves.
- `station_take_water(user)` when a use completes: TRUE when there was water
  (taken from the tank unless fed), otherwise it tells the user and takes
  nothing.
- `station_water_examine(user)` from `examine`: the feed, or the level.

Pumped pipe networks fill a tank like any other pipe sink (water only).

## Running water feeds

`running_water_feed(atom)` looks at the tile and its eight neighbours and
returns what feeds it, or null:

- river water with a current, above low water (stage above -1); ice never;
- a wet aqueduct piece, a fountain or aqueduct tap fed in the last two
  minutes, a filled public bath;
- a sink with water, a piped water tap holding water.

A fed station counts as full, so no timer runs. Still water lets you fill a
tank by hand but never feeds it. On a map without river flow data (round
maps) any fresh water beside the station feeds it.

## Hand recipes

`config/craft_needs.json` entries may add `"water": units` per product. The
Crafting window lists it with the other needs. It is paid when the build
completes from an open container held or at the builder's feet, and costs
nothing when the builder stands beside running water. The Crafting Atlas notes
it on the recipe. Unfired clay bricks, unfired cement bricks and paper sheets
take 10.

## Tests

`tests/station_water/station_water_probe.dm` (native) and
`tests/station_water/test_station_water.py` (source checks);
`tests/craft_needs/test_craft_needs.py` covers the JSON key.
