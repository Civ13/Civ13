# Ecology wildlife spawning

Wild animals on Nomads maps spawn where their biome and ground suit them,
anywhere on the map, instead of at fixed map spawn points. Source:
`code/modules/ecology/ecology_spawning.dm`.

## How it runs

- `/obj/map_metadata/nomads` sets `ecology_wildlife = TRUE`; other maps keep
  their map spawners. `ecology_autostart_check()` (called by the ticker process)
  starts the spawner once a round is playing, including after a world load.
  The admin verb Debug > Toggle Ecology Spawning stops it until the next
  restart; Debug > Ecology Spawning Status prints the last cycle's census.
- After a five-minute activity warm-up, the spawner samples 6 turfs in every
  8x8 cell of every level. Each sample on natural ground in an open outdoor
  area with air and gravity adds to a `climate|ground` key. The index is
  rebuilt every 30 minutes; every spawn still checks the actual turf.
- Ground classes: grass, natural dirt, snow (winter turfs and winter dirt),
  beach sand, desert sand and shallow fresh water (base, swamp and jungle
  water). Farmland, caves, deep water, ice, salt shallows, flooded tiles and
  regolith are never wildlife ground.
- Each of the 41 species has biomes, ground classes, a density per 1000 tiles
  of matching habitat, a maximum and a herd size. Its target is
  `habitat * density * ecology_density_scale / 1000`, at least 1 when the map
  has 128 tiles of its habitat, and at most its maximum. The total is scaled
  down to `ecology_wildlife_cap` (700). Gaia comes to about 600: 70 deer, 50
  sheep, 30 reindeer and so on.
- Every 60 seconds one census of `living_mob_list` counts wild animals per
  species. Tamed, ridden, led and player-controlled animals do not count. Up
  to 30 animals spawn per cycle, round-robin across species, as herds with
  alternating sexes within 3 tiles of a site. A site must be in a cell with no
  recent player activity (heatmap pressure at most 0.05, unknown never counts)
  and more than 15 tiles from every player's body and eye.
- Map mob spawners for a species the index gives a target stay quiet while
  ecology runs, but keep their timers, so an admin toggle-off revives them.
  Spawners for creatures outside the table (skeletons, zombies, dinosaurs,
  bats, mammoths, mice) and for species with no habitat on that map keep
  working.
- Breeding caps were raised to sit above the wild targets; see
  [animal population bounds](animal-population-bounds.md).

## Distant animals rest

The mob process runs `Life()` once every four seconds instead of every
second for an animal more than 32 tiles from every player body, player eye
and LLM agent character (one level up or down counts as near). Animals that
are pulled, buckled, ridden, following someone, targeting, attacking or
player-controlled never rest, and nor do human NPCs (raiders, zombies,
soldiers). Hunger, pregnancy and wandering run at a quarter pace while
nobody is near.

## Measured cost

`tests/ecology_spawning/perf_probe.dm` places 100-900 mixed animals (12
kinds, two predators) on a 300x300 grass level and runs 40 rounds of
`Life()`, with handle_ai active. Pinned 516.1688 in a Linux cloud container,
2026-11-07:

| Animals | Every animal every second | With distant animals resting |
| --- | --- | --- |
| 100 | 5.6 ms per second | |
| 300 | 19 ms per second | |
| 600 | 39 ms per second | 18 ms (nobody near), 20 ms (one player in the middle) |
| 900 | 58 ms per second | 26 ms (nobody near), 28 ms (one player in the middle) |

About 65 microseconds per awake animal per second. Gaia's old spawn points
held roughly 200 animals at full refill (about 13 ms per second), so the new
600-animal population costs about 20 ms per second with resting. These are
isolated synthetic numbers, not a measurement on the live server.
