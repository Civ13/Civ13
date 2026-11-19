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

## Stations that use water

| Station | Tank | Per use |
| --- | --- | --- |
| Potter's wheel (`clay_lime_fire.dm`) | 150 | 10 per ware |
| Brick mould bench (`clay_lime_fire.dm`) | 100 | 20 per batch of 8 |
| Retting trough | 90 | 30 per batch |
| Quench tub beside an anvil (`quench_tub.dm`) | 60 | 10 per forged iron or steel piece |
| Wash basin / washstand (`wash_places.dm`) | 30 / 50 | 5 per wash |
| Tub or shower, Persistence maps only (`bathing.dm`) | 100 (big 200) | a tubful |

The wheel and bench check for water before each piece and take it when the
piece is done, so a dry tank stops the run with a message. Retting in a water
tile stays free. The grindstone, kilns, furnaces, looms and the mill stay dry.

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

## Quench tub

A quench tub (8 soft wood, Iron Smithing) anchored within a tile of an anvil
quenches each iron or steel piece forged there (`finish_forged_piece()`): it
takes 10 water and raises the piece's `crafting_quality` to 1.2 (Excellent,
and `update_force()` gives it the matching force). A dry tub, or one below 10,
is passed over and forging works as before. Other metals, molds and
blackpowder parts are not quenched. Steel Japanese blades are clay-hardened
first when the smith can (docs/tatara.md); the same hook runs both.

## Wash basins and washstands

A fired clay wash basin (3 clay at the wheel or by hand, set down from the
hand) or a wooden washstand (6 soft wood, Hygiene) holds water like any
station. On help intent, clicking it with a hand targeted washes the hands;
any other target washes that part (`body_washing.dm`). Each wash takes 5.
With water in it, it is "a place to wash" for home comfort.
