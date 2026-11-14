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
| `land.dmm` | the region map, two levels (underground z1, surface z2), map **A New Land** (`/obj/map_metadata/nomads/expedition`) |
| `land.json` | the report: template, attempt, map hash, starts, supplies, timings and `slot_world` |
| `bundle/` | the generator bundle with a preview image |

## From template to land

- **Land type** picks the layout. Archipelago (3 to 5 islands) and volcanic
  isle (2 islands) use the oceanic generator; every other type is a surface
  land with open sea on the template's first coast side. Highlands, plateau
  and fjord coast always get a ridge; marsh and swamp get wetland.
- **Biome** sets the generator's climate and biome mix, and then the land is
  reskinned: the surface area (which sets the in-game climate: ice, tundra,
  taiga, forest, grassland, desert, savanna, jungle), ground turfs (snow,
  desert sand, dust, jungle grass) and trees (pines, cacti and palms, jungle
  trees, or fewer trees on open land).
- **Size** sets the tiles a side. Smaller lands get more stone and supply sites
  per land tile; larger lands get more forage sites.
- **Seed**: the same template always builds the same land. A rejected candidate
  (for example too much water) is retried with a derived seed, at most 8 times;
  the report lists the rejected attempts.

## Timings

Measured in a cloud container, one run each:

| Size | Tiles | Total |
| --- | --- | --- |
| Tiny | about 200 x 200 | about 11 s |
| Small | about 300 x 300 | about 29 s |

Every biome built on its first attempt. The host will be faster or slower; the
expedition slots will measure the time on Val's host before a crew waits on it.

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

## Not placed yet

- A surface land's sea strip is narrow (a few percent of the map); the ship
  arrives on the open-sea side.

Tests: `python3 -I -B tests/procedural_maps/run.py ...` (`test_land.py`).
