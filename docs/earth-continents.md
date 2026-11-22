# Earth continents

All seven Earth lands are generated regions drawn after the real continents, the
same way as the two [Americas regions](americas-regions.md): hand-placed
outlines, mountain chains, rivers, lakes and climate centres in
`tests/earth_maps/europe.py`, `asia.py`, `africa.py`, `oceania.py`,
`greenland.py` and `antarctica.py`, turned into terrain by
`tests/americas_maps/build.py`. They started as [Earth drafts](earth-drafts.md).

| Region id | Map | Type | Tiles | Frame (longitude east, latitude) |
| --- | --- | --- | --- | --- |
| `europe` | `maps/nomads/nomads_earth_europe.dmm` | `/obj/map_metadata/nomads/earth_europe` | 846 x 572 | -10 to 52, 72 to 46 |
| `mediterranean` | `maps/nomads/nomads_earth_mediterranean.dmm` | `/obj/map_metadata/nomads/earth_mediterranean` | 1280 x 396 | -10 to 52, 46 to 31 |
| `africa` | `maps/nomads/nomads_earth_africa.dmm` | `/obj/map_metadata/nomads/earth_africa` | 976 x 969 | -19 to 52, 31 to -36 |
| `asia` | `maps/nomads/nomads_earth_asia.dmm` | `/obj/map_metadata/nomads/earth_asia` | 1057 x 854 | 52 to 190, 78 to 0 |
| `oceania` | `maps/nomads/nomads_earth_oceania.dmm` | `/obj/map_metadata/nomads/earth_oceania` | 1212 x 728 | 94 to 180, 0 to -48 |
| `greenland` | `maps/nomads/nomads_earth_greenland.dmm` | `/obj/map_metadata/nomads/earth_greenland` | 760 x 816 | -76 to -10, 84 to 58.5 |
| `antarctica` | `maps/nomads/nomads_earth_antarctica.dmm` | `/obj/map_metadata/nomads/earth_antarctica` | 1024 x 1024 | polar view, 36 degrees from the pole |

No two frames overlap: each piece of the Earth is on one map only
(`tests/earth_maps` checks it). The Mediterranean (`mediterranean.py`) is drawn
from the Europe design with its own frame: the inner sea with Gibraltar, the
Bosporus and the Suez isthmus inside it, from Iberia to the Caspian. Iceland is
on the Greenland map.

Europe and Asia keep their region ids `europe` and `asia` and replace the older
Nomads (Europe) and Nomads (Asia) maps.
Africa takes the place of the Desert and Jungle regions: it already holds the
Sahara and the Congo, so keeping both would put the same land in the world
twice. Oceania, Greenland and Antarctica are new lands with the sea all round:
no walk leads to them, only ships and planes. The older maps stay in the
repository until the host has switched.

## What each map has

- One surface level; mountains are surface rock. Like every single-level map
  they get the unformed underground at boot (`dug_underground.dm`), and
  `mountain_seams` keeps mined-out mountain floor giving stone and ore.
- `building_levels = 10` with `building_level_standing`: the standing open-air
  level aircraft fly on, and storeys above it as roofs go up.
- `new_player_start_z = 1`: a new nomad starts on a random safe outdoor tile
  (`nomads_start.dm`); the `JoinLateCiv` marks (18 in Europe, 22 in Africa) are
  the arrival spots for travellers.
- Height, current and flood files under `maps/heights/nomads_earth_*`, written
  by the generator with the map (water is level 0, summits reach level 15).
- Crops follow climate and season (`farming.dm`, `farmers_almanac.dm`,
  `wild.dm`), and new characters take their origin from the climate they start
  in (`origins.dm`: the Europe and Africa tables).
- `sun_latitude` 50 for Europe, 38 for the Mediterranean, 40 for Asia and 5
  for Africa; wildlife and wild plant caps 570/315 (Europe), 600/350
  (Mediterranean), 860/475 (Asia), 1000/545 (Africa) and 420/250 (Oceania). Asia keeps the
  older Asia map's cinnabar belt, iron sand and clothing and languages by climate.
- The ice lands are hard country. Greenland's farmable ground is mostly snow
  on the tundra coasts, cleared with a spade. Antarctica grows nothing near
  fresh water, because all of it is frozen; only its fringe seeds forage, so food
  comes by sea and from the hunt. Oceania's land is the flattest of the six
  (its highest level is 11.5).
- `sun_latitude` -25 for Oceania, 72 for Greenland and -78 for Antarctica:
  polar day and night. New characters on Greenland are Inuit; Oceania and
  Antarctica have no origin table yet.
- Continent riches and provinces (`continent_resources.dm`, `maps/provinces/`,
  [provinces.md](provinces.md)) are keyed by these map types.

## Crossings and sea lanes

- Land links ([world-links.md](world-links.md), kind `both`: walked where dry,
  sailed where water): Europe's south edge runs into the Mediterranean, whose
  south edge runs into Africa. Asia's west edge leads into Africa (to 0.3974),
  the Mediterranean (to 0.5897) and Europe (to 0.9231). Asia's south edge from
  0.3043 to 0.9275 (the Malay lands and the great islands) runs into Oceania.
  The Mediterranean's west edge sails to the Atlantic past Gibraltar.
- Ships and planes (`continent_layout` in `code/modules/naval/sea_lanes.dm`):
  `africa` sits at (12, 3) with coasts W, S, E and a flight level. Earth Asia
  faces open sea E, S and N. `oceania` (21, 1), `greenland` (6, 11) and
  `antarctica` (10, -5) are laid out with their sea edges and flight levels. A map may
  name its own open-sea edges with `sea_coasts`, which win over the layout's for
  landfall here: Europe's Earth map faces open sea W and N, where the older map
  faced S and W, and the layout entry for `europe` still describes the older map
  until the host switches.

## Switching the host

Changing a region's map makes it a new world: coasts, rivers and rock move
through whatever players built. `scripts/shard-group/earth_continents.example.json`
has the entries:

1. Europe and Asia: set each region's `map` to its Earth map and start it as a
   fresh world, with its old saves archived.
2. Africa: remove the `desert` and `jungle` regions and add `africa` with the
   Africa map on a free port (the Jungle's port is free once it is removed).
3. Optionally add `oceania`, `greenland` and `antarctica` on free ports, each on
   its own map. They are new lands, so nothing needs to be archived.
4. Rebuild the other regions so their Regions panel and sea lanes list the
   new lands.
5. After the Mediterranean recut (2026-11-21): Europe, Africa, Asia and Oceania
   changed frames, so each starts again as a fresh world with its old saves
   archived, and `mediterranean` is added on a free port. Gaia, Greenland,
   Antarctica and the Americas are unchanged.

Start the regions one at a time.

## Regenerating

```sh
python3 -I -B tests/earth_maps/generate.py --only europe --relief europe.png   # map + height files, rewrites drafts.json
python3 -I -B tests/earth_maps/test_earth_maps.py
```

The generator is deterministic and needs numpy and Pillow; the tests need
neither. `drafts.json` holds the digest of each map and, for a region, of its
height, current and flood files, so the four never drift apart.

## What was measured

Measured 2026-11-18 on BYOND 516.1688 (Linux DreamDaemon, cloud container)
with the whole game compiled in, Persistence mode, no players, by
`tests/zone_persistence/real_map.py --loads 1`: a fresh world settles, builds a
roof in every climate zone and saves; a second process restores that save and
saves again; a third must refuse a save with a wrong schema. The memory limit
is `PERSISTENCE_MEMORY_LIMIT_MB` (3072).

| Map | Cells | Peak, fresh world and save | Peak, reload and save again | Save | Reload (levels) |
| --- | --- | --- | --- | --- | --- |
| Europe 1160 x 903 | 1,047,480 | 1493 MiB | 1810 MiB | 125 s | 231 s |
| Africa 976 x 1070 | 1,044,320 | 1557 MiB | 1885 MiB | 159 s | 254 s |
| Asia 1226 x 854 | 1,047,004 | 1409 MiB | 1736 MiB | 115 s | 221 s (run alone) |
| Oceania 1212 x 864 | 1,047,168 | 1346 MiB | 1617 MiB | 99 s | 199 s |
| Greenland 760 x 816 | 620,160 | 835 MiB | 967 MiB | 56 s | 104 s |
| Antarctica 1024 x 1024 | 1,048,576 | 1228 MiB | 1473 MiB | 81 s | 204 s |
| Mediterranean 1280 x 396 (2026-11-21) | 506,880 | 871 MiB | 1025 MiB | 65 s | 311 s |

The Europe run shared the machine with a first Africa run, so its times are
slower than alone. That first Africa save failed its own check while both
saved at once (the shared BYOND cache; start regions one at a time) and the
table shows Africa run again alone. No runtime
errors. Greenland's first run hung at boot: berry bushes were placed by picking
grass tiles until a count set by the map's size was reached, and the ice island
has far less grass than that. The count now follows the grass and the picks are
bounded (`_map_metadata.dm`). The engine's long-loop warning fired once each in boot steps that
already do so on the Americas maps (floor icon refresh, map seeding, seam
marking, the save itself). Every reload peak is under two thirds of the
limit, with the unformed cave and the standing open-air level counted; each
further open-air plane that players build adds about 130 MiB.

The 2026-11-21 recut shrank Europe (484,000 cells), Africa (945,700), Asia
(902,700) and Oceania (882,300); each is smaller than the map measured above,
so their peaks can only fall. The Mediterranean was measured alone on the same
setup: write run 313 s, reload run 413 s, reject run 175 s, no runtime errors.
