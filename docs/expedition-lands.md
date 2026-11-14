# Expedition lands

A land a crew sails to is built from its world-chart template
([world chart](world-chart.md), [plan](https://claude.ai/artifact/61LciJHKi6eKEUsYMfFgwE)).
The chart only keeps the template; the land is generated when a crew decides
to go there. This step is the generator: it turns a template into a region map.
Nothing loads the map in game yet; the expedition slots come next.

```sh
python3 -m tools.procedural_maps land --template template.json --out lands/24-16
```

`--out` must not exist yet. The command writes:

| File | What it is |
| --- | --- |
| `land.dmm` | the region map, two levels (underground z1, surface z2) |
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

## Not placed yet

- The template's ore kinds, rare finds and game animals are in the report's
  `slot_world` for the slot world to apply on load; the map only has the
  generator's generic stone and supply sites.
- A surface land's sea strip is narrow (a few percent of the map); the ship
  arrives on the open-sea side.

Tests: `python3 -I -B tests/procedural_maps/run.py ...` (`test_land.py`).
