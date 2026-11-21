# Ocean regions

Five oceans fill the water between the lands of the earth group, so every sea
edge of every land leads somewhere: the Atlantic, the Pacific, the Indian, the
Arctic and the Southern Ocean. Each is its own world (shard kind `OCEANIC`).

| Region id | Map | Size | Notes |
| --- | --- | --- | --- |
| atlantic | `maps/nomads/nomads_ocean_atlantic.dmm` | 600 x 900 | Gaia and Greenland insets |
| pacific | `maps/nomads/nomads_ocean_pacific.dmm` | 900 x 900 | Closes the loop between Asia and the Americas |
| indian | `maps/nomads/nomads_ocean_indian.dmm` | 600 x 600 | |
| arctic | `maps/nomads/nomads_ocean_arctic.dmm` | 1000 x 300 | Pack ice along the north; west and east join |
| southern | `maps/nomads/nomads_ocean_southern.dmm` | 1200 x 300 | West and east join; Antarctica to the south |

Code: `code/game/objects/map_metadata/nomads/nomads_ocean.dm` (metadata) and
`code/modules/naval/ocean_regions.dm` (the ocean area, the breakers turf). Which stretch of which ocean edge meets which coast is in the
world links table ([world-links.md](world-links.md)): `world_sea_links`,
`world_oceans` and `world_insets` in `code/modules/persistence/world_links.dm`.

## The maps

`python3 tools/ocean_maps/generate.py` writes every ocean map from
`tools/world_links/world_links.json` (`--check` exits 1 when one is stale). An
ocean is one level of deep salt water and nothing else but:

- a small rock in the middle with the `JoinLateCiv` landing, where a traveller
  with nowhere better to stand is put down;
- pack ice along an edge the table gives `ice` (the Arctic's north), solid near
  the edge and loose floes beyond;
- breakers round each inset: an island land's waters inside the ocean.

The metadata turns off everything a land has: no dug underground
(`dig_down_underground`), no open-air levels (`building_levels = 0`), no wild
plants or land animals. Sea life keeps its own cap.

## Memory

The largest ocean, the Pacific (810,000 tiles), measured with
`python3 -B tests/zone_persistence/real_map.py --map maps/nomads/nomads_ocean_pacific.dmm --loads 1 --settle 30`
on BYOND 516.1688: startup 182 s at 851 MiB, save 69 s, write-run peak 986 MiB.
That is about two thirds of a land region's load peak (1350-1560 MiB in
[earth-continents.md](earth-continents.md)), since an ocean has one level and
almost no objects. The harness's roof check has nothing to build on at sea, so
its reload run was not reached; the smaller oceans were not measured.

## Insets

Gaia and Greenland have sea on every side, so their edges cannot face one ocean
edge. Each has an inset in the Atlantic: a box of breakers whose four sides lead
to that land's four edges. Ship crossings into and out of insets come with the
ship edge crossing work.

## Not yet

These maps are not in any live group until the host step that adds the seas.
Ships crossing edges, sites near ships (islets, reefs, wrecks) and straits
come in later PRs of the ocean regions plan.
