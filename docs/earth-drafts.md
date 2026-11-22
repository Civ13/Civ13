# Earth draft lands

Six generated lands that fill in the rest of the world around the two
[Americas regions](americas-regions.md): Europe, Africa, Asia, Oceania,
Antarctica and Greenland. All six have since been made into regions
([earth-continents.md](earth-continents.md)); their maps moved to
`maps/nomads/`. What follows about drafts describes how they started, and
applies to any new land drawn the same way. They are drawn the same way as the Americas maps,
from hand-placed outlines, mountain chains, rivers, lakes and climate centres,
and nothing is copied from another map.

They are **drafts**. No server loads them:

- they carry no map metadata object and have no `/obj/map_metadata` type;
- they have no region id and are in no shard group, vote list or `.dme`;
- they have no height, current or flood files;
- nothing has been measured or tried in BYOND.

They exist so the whole world can be shown in overviews and wide shots, and as
a starting point if any of them is later made into a region.

| Land | Map | Tiles | Frame (longitude east, latitude) |
| --- | --- | --- | --- |
| Europe (now a region) | `maps/nomads/nomads_earth_europe.dmm` | 1160 x 903 | -25 to 60, 72 to 31 |
| Africa (now a region) | `maps/nomads/nomads_earth_africa.dmm` | 976 x 1070 | -19 to 52, 38 to -36 |
| Asia (now a region) | `maps/nomads/nomads_earth_asia.dmm` | 1226 x 854 | 30 to 190, 78 to 0 |
| Oceania (now a region) | `maps/nomads/nomads_earth_oceania.dmm` | 1212 x 864 | 94 to 180, 9 to -48 |
| Antarctica (now a region) | `maps/nomads/nomads_earth_antarctica.dmm` | 1024 x 1024 | polar view, 36 degrees from the pole to the frame edge |
| Greenland (now a region) | `maps/nomads/nomads_earth_greenland.dmm` | 760 x 816 | -76 to -10, 84 to 58.5 |

Each is one level and no larger than the cell count the Americas regions were
measured at. Neighbouring frames overlap on purpose (the inner sea is on both
Europe and Africa, the eastern steppe on both Europe and Asia), so the same
coast is drawn slightly differently on each.

## Regenerating

Needs numpy and Pillow. Never hand-edit the maps; change the design file
(`tests/earth_maps/europe.py` and its neighbours) and run:

```
python3 -I -B tests/earth_maps/generate.py                       # all six, rewrites drafts.json
python3 -I -B tests/earth_maps/generate.py --only asia --relief asia.png
python3 -I -B tests/earth_maps/world_overview.py --dir out --scale 10
python3 scripts/ci_baseline.py unit --suite earth_maps
```

`generate.py` hands each design to `tests/americas_maps/build.py`, which is
unchanged for the Americas maps. The designs count longitude east; `lands.py`
turns them into the west-counting form that builder reads. `world_overview.py`
lays all eight lands on one longitude/latitude sheet and writes `world.json`
with each land's pixel box.

## Making a draft playable

That is new work, not a switch (Europe and Africa show the whole of it, see
[earth-continents.md](earth-continents.md)): give the land a `/obj/map_metadata/nomads`
type and put it in the design as `metadata` (and `heights`), move the map beside the other
Nomads maps, generate its height, current and flood files as
`build.write_sidecars` does for the Americas, decide its edge crossings, add
it to a region group, and measure start, save and reload memory in BYOND at the
pinned version before it is offered to players.
