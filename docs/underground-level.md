# Underground level: unformed rock

Every map compiled with one level has a cave level under its surface
(`dig_down_underground`, TRUE by default on the map metadata). The code is in
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
from its saved cells alone. `underground_levels()` caches the underground
levels in `underground_live_levels` while those markers stand.

## Deeper levels

Every map with an underground has four levels under its surface
(`underground_depth`, 4 by default): the cave and three deeper ones. A deeper
level is one more plane of unformed rock, added the first time someone digs
down from the deepest one (shovel or ant Dig, "Down" on an underground level;
each level down takes another 100 deciseconds of digging). It is appended
like the cave and carries the same bedrock marker. A level is only ever added
under the deepest one, so the added levels' z order is their depth order, and
a restore, which recreates levels in z order, keeps it: `underground_levels()`
lists them shallowest first, `underground_depth_of(z)` gives a level's depth
and `underground_z_at(depth)` the reverse. Maps compiled with their own cave
(Gaia, Desert, Jungle, Barren, Moon) count it as depth 1 and add three.

`multiz_column()` orders every level as a ladder climbs them: the deepest
underground level first, then the compiled levels, then the open-air levels
in the order they were added; `multiz_level_below`/`above` step through it.
The practice level is left out.

Each depth forms from its own seed (`pocket2`, `vein2`, ...), and only the
cave straight under the surface feels lakes, rivers and shallows overhead.
Deeper levels take only the sea floor (seabed rock that cannot be dug) and
lava (hot rock) from the surface, and their open cells never breach.

Every deeper level saves sparse around unformed rock like the cave (an
untouched one is a header), and none of them is charged cells: `free_planes`
leaves every added underground plane out, `ground_planes` counts them with the
compiled levels so they never use up a roof level, and a restore, which cannot
see its underground before the cells load, counts every one the map may add.
`BUILDING_EXTRA_LEVELS` is 15: ten open-air levels and four underground ones
over a single-level map. Tools needed to go deeper are later work.

## What each depth holds

Every depth has its own ore table (`underground_ores.dm`). Its factor
multiplies an ore's chance in `continent_ore_factor`, together with the land's
own rate, so every era gate and continent rate still applies: depth makes an
ore richer where it is already found, never earlier. The surface and the cave
keep the ordinary table (factor 1). Factors for depths 2, 3 and 4:

| Ore | 2 | 3 | 4 |
| --- | --- | --- | --- |
| copper, tin, iron, calamine | 1.5 | 1.25 | 1 |
| lead | 1.5 | 1.5 | 1.25 |
| coal | 2 | 1.5 | 1 |
| saltpetre | 1.25 | 2 | 1.5 |
| sulphur | 1.25 | 2 | 2.5 |
| silver, gold (and their lodes) | 1.5 | 2.5 | 3 |
| diamond | 1.5 | 2.5 | 4 |
| uranium, rough gemstones | 1.5 | 2 | 3 |
| nickel | 1.5 | 2 | 2 |
| cobalt, chromite | 1.25 | 1.5 | 2 |
| obsidian, cinnabar | 1 | 1.5 | 2 |
| bauxite | 0.5 | 0.25 | 0.25 |
| flint | 0.5 | 0 | 0 |

So the second level is the iron, copper, tin and coal level, the third the
silver, gold, gems, sulphur and saltpetre level, and the fourth the richest
precious veins, diamonds, uranium and alloy ores. Bauxite is weathered surface
rock and flint is chalk, so they thin out below the cave. Obsidian on a deeper
level also counts a volcano on the land straight above, not only one on the
level above it.

## Every map

Maps with no ground to dig under opt out with `dig_down_underground = FALSE`:
the open sea, orbit, the tutorial region, the TDM barracks, Battleships and
the Extraction survival instances. Maps compiled with more than one level keep
their authored tunnels and get no generated level.

The cave is admitted first at boot on any surface up to
`DUG_UNFORMED_MEASURED_CELLS` (1,050,000 cells): an unformed plane costs about
14 bytes a cell until dug, so it does not count against the full-level cell
budgets. That admits the Americas (1132 x 920 and 848 x 1224); their standing
open-air level then follows at `z 3` (`building_admitted` in
building_admission.dm). Added later than first, the cave falls back to the
ordinary cell budgets. The unformed cave plane is also left out of the
total-cell ceiling (`free_planes` in world_z_budget.dm), once the cave exists
or while a restore cannot see it yet. Measured 2026-11-16 on 516.1688 with
North America (`real_map.py --map maps/nomads/nomads_americas_north.dmm`):
cave and standing level ready 7 s after the round started, save 159 s with a
write peak of 1352 MiB, reload 352 s with a peak of 1657 MiB (1526 MB with the
standing level alone), the cave saved in 39 KB.
With the cave and all four open-air levels (`--storeys 4`, z 6): save 181 s
at a 1416 MiB peak, reload 536 s at a 2053 MiB peak. Every map now allows
four open-air levels (`building_levels` defaults to 4; orbit and the tutorial
region opt out); on the Americas the standing rule in building_admission.dm
admits all of them, about 130 MiB of reload peak per empty plane. South
America with all of them: save 209 s at 1619 MiB, reload 617 s at 2238 MiB.

Falling, holes and explosions that reach an unformed cell form it before they
act on it (`/turf/sky/building/ex_act`).

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

## Water above

`underground_above(surface)` reads the surface tile over a cell:

| Above | Forms as | When opened |
| --- | --- | --- |
| Deep saltwater (sea) | `/turf/wall/rockwall` (cannot be dug) | - |
| Deep fresh water, or water on a river reach | wet rock, `/turf/floor/dirt/underground/wet` | breach: pours like a tunnel mouth while the water above stays |
| Shallows, swamp, coast water | wet earth, `/turf/floor/dirt/underground/mud` | seeps 0.3 deep (`MUD_SEEP`); bailing or a pump keeps it back |
| Lava | hot rock, `/turf/floor/dirt/underground/hot` | never: it cannot be dug and burns whoever touches it |

No natural pockets form under water or lava. Breaches
(`tunnel_breaches`, [flood_cellars.dm](../code/modules/1713/flood_cellars.dm))
feed the existing tunnel water: roof-high a few tiles a minute, drowning
included. Packing the breached cell with earth stops it, and the water soaks
away. Breaches are not saved; `restore_dug_levels()` finds them again with
`underground_breach_scan()`. Tunnel water needs the map's river flood file,
so a map without one has no flooding. Digging up under water or lava, and
down onto hot rock, is refused with a message that names the reason.

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

## Admin view

Admin > Debug > **Level Report** lists every level: ground, the cave (added or
compiled), each deeper underground level by depth, open air and practice rooms, with the number of formed cells and
how many of them are open. It walks each plane, so it takes a few seconds on
the Americas.

## Checks

- `python3 tests/building_levels/run.py --cave` and `--cave-first`
  (isolated fixture: allocation order, unformed and asleep cells, forming,
  entry refusal, generator, the three deeper levels and their admission).
- `python3 -B tests/underground_level/real_map.py --byond-bin <bin> --map
  maps/nomads/nomads_europe.dmm --output <fresh dir>` (full game: boot,
  dig a shaft and tunnel, save, restore, resave; `--storeys N` also grows N
  open-air levels and `--deep N` digs down to depth N before the save; the
  map may be one with a compiled cave, such as Gaia).
- `python3 tests/ecology_spawning/run_linux.py . tests/river_flow/cellar_probe.dm`
  (breach flooding, packing it, wet-earth seepage).
- `python3 -m unittest tests/gaia_host/test_underground_migration.py`
  (host action: refusals, backup, validation gate, swap).
- `python3 -B tests/underground_level/migration.py --byond-bin <bin> --old-rev
  <commit before this change> --map maps/nomads/nomads_desert.dmm --output
  <fresh dir>` (an old build seeds a body, item, crate and ladder on the old
  level and saves; the current build migrates, validates and restores it).
