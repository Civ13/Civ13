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

## Compiled underground levels

Gaia, Desert, Jungle, Barren and the Moon compile their underground as z 1
(`underground_compiled_z` on the map metadata). That level is now one key,
`/turf/sky/building/unformed` in the map's own cave area (the control room in
`/area/caribbean/admin` and the map metadata object keep their cells): the same unformed
rock, as a compiled subtype with no constructor work and no lighting
(`lighting_never`). `underground_level_z()` returns the compiled level when a
map has one and the dug level otherwise, so forming, entry refusal and the
sea layer's rock checks treat both alike. Anything that does arrive on an
unformed cell (not during a save) forms it as dirt first.

The compiled level saves as kind `ground`; its baseline is the unformed
subtype, so only formed cells are written.

## Migrating old saves

Saves from before this change still hold the old filled cave level. The host
action `shard_group.py migrate-underground --region ID`
(`scripts/windows/host/migrate-underground.bat ID`,
[underground_migration.py](../scripts/shard-group/underground_migration.py))
turns one stopped region over:

1. Save and stop the region, then Update it to the latest master.
2. The action refuses unless the region is stopped or cold, idle, built and
   has a completed save. It backs the save up to
   `<state_dir>/underground-migration/<UTC time>` (never pruned).
3. It boots a private copy (`<group root>/.migration/<ID>`) with
   `-params migrate_underground=1`
   ([underground_migration.dm](../code/modules/multiz/underground_migration.dm)):
   the restored world (control room and map metadata left alone) moves people, loose objects and crates on the old level
   to the nearest clear surface tile above (15-tile search), deletes the rest
   and any ladder above it, resets every cell to unformed rock, saves and
   writes `underground_migration.json`.
4. It boots the copy again with `-params validate_save=1` and requires a full
   validation record that matches the migrated files.
5. Only then does it swap the migrated save, with its `validated.json`, into
   the region and print the report. On any failure the region keeps its old
   save. Start the region afterwards as usual.

## Checks

- `python3 tests/building_levels/run.py --cave` and `--cave-first`
  (isolated fixture: allocation order, unformed and asleep cells, forming,
  entry refusal, generator).
- `python3 -B tests/underground_level/real_map.py --byond-bin <bin> --map
  maps/nomads/nomads_europe.dmm --output <fresh dir>` (full game: boot,
  dig a shaft and tunnel, save, restore, resave).
- `python3 -m unittest tests/gaia_host/test_underground_migration.py`
  (host action: refusals, backup, validation gate, swap).
- `python3 -B tests/underground_level/migration.py --byond-bin <bin> --old-rev
  <commit before this change> --map maps/nomads/nomads_desert.dmm --output
  <fresh dir>` (an old build seeds a body, item, crate and ladder on the old
  level and saves; the current build migrates, validates and restores it).
