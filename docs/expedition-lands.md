# Expedition lands

A land a crew sails to is built from its world-chart template
([world chart](world-chart.md), [plan](https://claude.ai/artifact/61LciJHKi6eKEUsYMfFgwE)).
The chart only keeps the template; the land is generated when a crew decides
to go there. This step is the generator: it turns a template into a region map.
An expedition slot compiles the map as its region map ([expedition slots](expedition-slots.md)).

```sh
python3 -m tools.procedural_maps land --template template.json --out lands/24-16
```

`--out` must not exist yet. The command writes:

| File | What it is |
| --- | --- |
| `land.dmm` | the region map, the surface alone on level 1, map **A New Land** (`/obj/map_metadata/nomads/expedition`) |
| `land.json` | the report: template, attempt, map hash, starts, supplies, timings and `slot_world` |
| `land.heights.txt`, `land.flow.txt`, `land.flood.txt` | the land's hill levels, river currents and flood reaches (below) |
| `bundle/` | the generator's seed manifest and a preview image; `--full-bundle` also keeps the typed IR and its sidecar (about 80 MB for a small land, 880 MB at a million tiles), which `verify` and `playable` read |

## From template to land

A land is built from its relief by the relief generator
([procedural maps](procedural-maps.md#relief-lands)). Its coasts, ranges,
rivers and lakes are shares of its own area, so the same template rules give a
sound land at 200 x 200 and at 700 x 700: a larger land has more rivers, lakes,
ranges and arrival spots, not the same few stretched.

- **Coasts**: every coast side of the template is open sea, with bays, headlands
  and offshore islets. The other sides are land that runs to the map edge. One
  coast side makes about a seventh of the map sea, four sides a little under
  half.
- **Land type** shapes the relief:

  | Land type | Mountains | Hills | Rivers | Else |
  | --- | --- | --- | --- | --- |
  | Coastal plain | 2% of land for each chart ridge, none without | 3-6% | 1.4-2.0% | |
  | River delta | as coastal plain | 1-3% | 2.6-3.4% | 1-3% wetland |
  | Marsh | as coastal plain | 1-3% | 1.8-2.6% | 4-8% wetland, more lakes |
  | Highlands | 8-12% | 12-18% | 1.4-2.0% | |
  | Plateau | 3-5% | 16-22% | 1.0-1.6% | smooth coast |
  | Fjord coast | 6-10% | 8-12% | 1.4-2.0% | broken coast |
  | Archipelago | 1-3% | 4-8% | 1.0-1.6% | 3 to 5 islands when tiny, 9 to 11 at 690 x 690 |
  | Volcanic isle | 7-11% | 10-14% | 1.0-1.6% | 1-2 islands, 2-3 on a large map |

- **Rivers** rise at springs and lakes, gather tributaries and run downhill to
  the sea or a lake; they cut gorges through ranges. Hollows fill into lakes
  that spill by a river. Desert and ice-sheet lands get half the rivers and a
  third of the lakes; a swamp biome always has wetland.
- **Biome** sets the generator's climate and biome mix, and then the land is
  reskinned: the surface area (which sets the in-game climate: ice, tundra,
  taiga, forest, grassland, desert, savanna, jungle), ground turfs (snow,
  desert sand, dust, jungle grass) and trees (pines, cacti and palms, jungle
  trees, or fewer trees on open land).
- **Size** sets the tiles a side. Smaller lands get more stone and supply sites
  per land tile; larger lands get more forage sites. Arrival spots are one per
  5,000 tiles of map, 6 to 48.
- **Seed**: the same template always builds the same land. A rejected candidate
  (for example too few safe arrival spots near fresh water) is retried with a
  derived seed, at most 8 times; the report lists the rejected attempts. In a
  test of 288 lands (every biome with every land type, four sizes) 287 built
  on the first attempt and one on the second.

## Hills, currents and floods

A hand-made map gets its [hill levels](terrain-height.md), river currents and
[flood reaches](river-flood.md) from three tools its author runs. A generated
land has no author, so `tools/procedural_maps/terrain_files.py` writes all
three beside the map, for the surface level:

- **Hills** follow the land's height above its sea, one level to 70 m of
  relief, from 0.5 on the beach to 15 on the highest ground. The game keeps
  water flat, so every sea, lake, river and swamp tile is level 0 and the
  ground climbs out of it one level a tile: a river high in the hills runs in
  a valley. No two neighbouring tiles differ by more than two levels.
- **Currents** and **flood reaches** come from the same builders the hand-made
  maps use (`scripts/river_flow.py`, `scripts/river_flood.py`), read from the
  land's turfs and hills, so the files are the ones the game already reads.

The host copies them to the slot world as `config/expedition_heights.txt`,
`.flow.txt` and `.flood.txt` ([slots](expedition-slots.md)), and the land's
map reads them from there. A slot without them (a free slot, or a land made
before lands had them) is flat, still and never floods. They add about 6 s to
a 690 x 690 land and well under a second to a tiny one.

## Timings and sizes

Measured in a cloud container, one run each:

| Size | Tiles | Total | Python memory |
| --- | --- | --- | --- |
| Tiny | 200 x 200 | about 2 s | 89 MB |
| Small | 300 x 300 | about 4 s | 179 MB |
| Medium (Gaia) | 500 x 350 | about 11 s | 324 MB |
| Massive, at its largest | 690 x 690 | about 41 s | 864 MB |

The host will be faster or slower; the expedition slots will measure the time
on Val's host before a crew waits on it.

A side may be 64 to 1280 tiles, and a template is refused when width x height
is more than 480,000 tiles (`MEASURED_CELLS` in `tools/procedural_maps/land.py`):
692 x 692 at most, which holds the largest massive land (690 x 690). The
generator itself runs past that (a 1132 x 920 relief land takes about 40 s),
but such a map is not a land a slot may open until a world that size has been
measured.

## One level, and its measurement

A land's map is its surface alone. The generator's second level, solid rock
under the whole land, was a boulder on every tile, and it is left out of the
map: mountains stand on the surface as rock to mine, and the land's map sets
`dig_down_underground`, so the first tunnel dug down makes a cave level where
the world's level budget allows one ([level budget](new-z-budget.md): surface
and cave together within 350,000 cells, so lands up to 175,000 tiles, every
tiny and small land and a medium one of Gaia's size). Larger lands have no
caves until a world with one is measured.

The largest land, 690 x 690, measured in an isolated world in a cloud
container (BYOND 516.1688, Linux, no players; the limit is 3,072 MB):

| | Two levels (before) | One level |
| --- | --- | --- |
| Cells and boulders under the land | 952,200 and 476,100 | 476,100 and none |
| Start to setup finished | about 2.5 min | about 70 s |
| Memory after start | 1.3 GB | 0.7 GB |
| Saving the world | 15 min, 3.4 GB, and it failed | under 3 min, 1.27 GB peak |
| Reloading the save | not reached | about 4 min, 1.3 GB peak |

No run logged a runtime error. The start times include the two start-up
changes this measurement led to (the turf registry and start-up lighting,
#5355 and #5360): before them the two-level land took over twelve minutes to
start. Not measured: a land with players and buildings on it, and Val's host.

## Ore, rare finds and game

The report's `slot_world` (ore richness, ore kinds, rare finds, game) goes to
the slot's `config/expedition_land.json`, and the land world applies it
(`code/modules/naval/land_resources.dm`):

- **Ore:** every mined wall rolls once more for a lode of one of the land's
  ore kinds: 12% of walls on a rich land, 9% good, 6% fair, 4% thin, 2% poor.
  Iron and zinc need the Classical age and coal, lead, saltpeter and sulphur
  the Medieval age, as in ordinary mining. A volcanic isle adds obsidian.
- **Rare find:** gems (4% of walls give a rough gemstone), a rich gold or
  silver vein (3%, 8 ore) or diamonds (1%).
- **Game:** the land's animals are three times as common as usual, up to
  twice their usual cap (ecology spawning).

Tests: `python3 -I -B tests/procedural_maps/run.py ...` (`test_land.py`).
