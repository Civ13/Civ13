# Provinces

Each continent is cut into provinces that follow the land: coasts, big
rivers, lakes, mountain ranges and narrow straits. Provinces are the units
factions will hold on a continent (the continent control plan: recruitment
stations work only in a province the faction holds, plus stake, ranks and
sieges). This first step only adds the provinces themselves. Nothing in play
uses them yet; admins see them under Admin > Land Status.

## Files

`maps/provinces/<map>.txt`, beside `maps/heights/<map>.txt`. The game finds it
from the map's `terrain_height_file` (`code/modules/provinces/provinces.dm`),
so a map with no height file, or no province file, has no provinces.
Expedition lands have none.

```
civ13-provinces 1
size WIDTH HEIGHT
z Z
province 1 North Coast
province 2 West Riverlands
...
<HEIGHT rows, north row first, WIDTH characters each>
```

`z` is the surface level the file was cut from. Every level of the map uses
the same rows, so a cave or an upper floor belongs to the province under it.
`.` is open sea in no province (more than 8 tiles from land); the other
characters are province ids, `1`-`9` then `a`-`z`. A bad file is ignored with
a debug log, leaving the land without provinces.

## Making them

```
python3 scripts/provinces.py --map maps/nomads/nomads_gaia.dmm --z 2 \
    --heights maps/heights/nomads_gaia.txt --flow maps/heights/nomads_gaia.flow.txt \
    --out maps/provinces/nomads_gaia.txt --render gaia.png
```

| Map | Surface z |
| --- | --- |
| nomads_gaia, nomads_desert, nomads_jungle | 2 |
| nomads_americas_north, nomads_americas_south, nomads_europe, nomads_asia | 1 |

How the tool works:

1. Land is every non-water tile; rock walls count as land.
2. The number of provinces is one per 12,000 land tiles, between 4 and 12
   (`--count` overrides it). Starting points are shared out between
   landmasses by size; pieces too small for a province of their own get none.
3. Provinces grow outward from their starting points over a cost map:
   ground 1 per tile plus 1.5 per level climbed, rock walls 6, rivers and
   lakes 30, the sea 40. Borders settle where the cost is high, so on rivers,
   lakes, ranges and straits.
4. Six rounds move each starting point to the middle of its province to even
   out sizes. A province under 30% of the planned size merges into the
   neighbour it shares the longest border with.
5. Names are a compass part of the land plus the best-fitting terrain word
   not yet used there (Highlands, Hills, Riverlands, Lakelands, Coast, Sands,
   Jungle, Snowfields, Marshes, Lowlands, Plains).

The output is deterministic. Review the render before committing, and rerun
after changing a map's land, water, heights or rivers. Names and border
characters may be edited by hand; rerunning the tool overwrites them.

## Checks

`python3 tests/provinces/test_source.py` (offline suite `provinces`): every
continent's file parses, matches its map, puts every land tile in a province
and has 4-12 unique names; the generator puts a border on a river; the DM
reader expects the same format.
