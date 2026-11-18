# Earth continents

Europe, Asia and Africa are generated regions drawn after the real continents, the
same way as the two [Americas regions](americas-regions.md): hand-placed
outlines, mountain chains, rivers, lakes and climate centres in
`tests/earth_maps/europe.py`, `asia.py` and `africa.py`, turned into terrain by
`tests/americas_maps/build.py`. They started as [Earth drafts](earth-drafts.md).

| Region id | Map | Type | Tiles | Frame (longitude east, latitude) |
| --- | --- | --- | --- | --- |
| `europe` | `maps/nomads/nomads_earth_europe.dmm` | `/obj/map_metadata/nomads/earth_europe` | 1160 x 903 | -25 to 60, 72 to 31 |
| `africa` | `maps/nomads/nomads_earth_africa.dmm` | `/obj/map_metadata/nomads/earth_africa` | 976 x 1070 | -19 to 52, 38 to -36 |
| `asia` | `maps/nomads/nomads_earth_asia.dmm` | `/obj/map_metadata/nomads/earth_asia` | 1226 x 854 | 30 to 190, 78 to 0 |

Europe and Asia keep their region ids `europe` and `asia` and replace the older
Nomads (Europe) and Nomads (Asia) maps.
Africa takes the place of the Desert and Jungle regions: it already holds the
Sahara and the Congo, so keeping both would put the same land in the world
twice. The older maps stay in the repository until the host has switched.

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
- `sun_latitude` 50 for Europe, 40 for Asia and 5 for Africa; wildlife and
  wild plant caps 1000/550 (Europe, Asia) and 1100/600 (Africa). Asia keeps the
  older Asia map's cinnabar belt, iron sand and clothing and languages by climate.
- Continent riches and provinces (`continent_resources.dm`, `maps/provinces/`,
  [provinces.md](provinces.md)) are keyed by these map types.

## Crossings and sea lanes

- Walking (`edge_crossings`, [edge-crossings.md](edge-crossings.md)): Europe's
  east edge, the steppe and the Urals, runs on into Asia. Africa's east edge from
  0.68 to the top (the desert peninsula and the lands north of it) runs on into
  Asia. Asia's west edge leads into Africa below 0.45 and into Europe above it. Europe and Africa are not joined on foot: their frames
  overlap across the inner sea, so a walk off one edge would not come out where
  it went in. Cross by ship or plane.
- Ships and planes (`continent_layout` in `code/modules/naval/sea_lanes.dm`):
  `africa` sits at (12, 3) with coasts W, S, E and a flight level. Earth Asia
  faces open sea E, S and N. A map may
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
3. Rebuild the other regions so their Regions panel and sea lanes list Africa.

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

The Europe run shared the machine with a first Africa run, so its times are
slower than alone. That first Africa save failed its own check while both
saved at once (the shared BYOND cache; start regions one at a time) and the
table shows Africa run again alone. No runtime
errors. The engine's long-loop warning fired once each in boot steps that
already do so on the Americas maps (floor icon refresh, map seeding, seam
marking, the save itself). All three reload peaks are under two thirds of the
limit, with the unformed cave and the standing open-air level counted; each
further open-air plane that players build adds about 130 MiB.
