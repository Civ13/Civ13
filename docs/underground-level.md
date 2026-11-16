# Underground level: unformed rock

A dig-down map (`dig_down_underground` on its map metadata, compiled with one
level) has a cave level under its surface. The code is in
[dug_underground.dm](../code/modules/multiz/dug_underground.dm).

## Unformed rock

The level is added once the startup import settles, before the standing
open-air level, so it is always the first added level. BYOND only appends
levels, so it is physically `building_base_maxz() + 1` while it lies
logically below the surface; `multiz_level_below` and `multiz_level_above`
translate.

`world.turf` cannot change at runtime (probe 2026-11-16, 516.1688: "Cannot
write to world.turf"), so the level is grown as the world's native fill,
`/turf/sky/building`, with every constructor skipped (`building_allocating_z`).
On the cave level that fill means **unformed rock**: solid rock no one has
reached. It has no icon, lighting, registry entry or saved field, and
`/turf/sky/building/Enter` refuses everything but ghosts there. Growing an
Americas-size plane (1020 x 1020) natively took 0.44 s and 6 MB; putting it in
the cave area took 0.23 s and 8 MB.

A bedrock cell at (1, 1) marks the level, so a restored world recognises it
from its saved cells alone. `dug_underground_z()` caches the answer in
`dug_underground_live_z` while that marker stands.

## Forming on demand

Real turfs form only where play reaches:

- `dug_underground_form(T)` turns one unformed cell into the turf the
  generator gives it and lights it.
- Every `ChangeTurf` on the cave level that leaves an open (non-dense) turf
  calls `underground_opened()`, which forms the eight neighbours. So an open
  cell never touches unformed rock, and nothing needs to see or enter it.
- Breaking into a natural pocket forms the pocket too, up to 400 open cells;
  past that the pocket's far side forms as rock.

The generator `dug_underground_cell(x, y)` is deterministic: lattice noise
seeded by the map ID (md5 per lattice point), plus the surface tile straight
above (`dug_underground_rock`). A cell always forms the same way, so nothing
but formed cells needs saving. The map edge forms as bedrock.

## Saves and loads

The level saves sparse, kind `building`, around the unformed baseline: the
saver's sleeping-cell shortcut (`building_cell_asleep`) skips unformed cells
without comparing fields. A level nobody has dug saves only its marker.

The restore allocates the level the same way (constructors skipped) and
loads the formed cells on top. `restore_dug_levels()` then puts cells the
load left in the world's default area back into the cave area and lights
formed cells.

## Checks

- `python3 tests/building_levels/run.py --cave` and `--cave-first`
  (isolated fixture: allocation order, unformed and asleep cells, forming,
  entry refusal, generator).
- `python3 -B tests/underground_level/real_map.py --byond-bin <bin> --map
  maps/nomads/nomads_europe.dmm --output <fresh dir>` (full game: boot,
  dig a shaft and tunnel, save, restore, resave).
