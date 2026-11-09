# Terrain height (hills)

Optional per-tile hill levels for a map's ground. A step uphill costs extra
move delay, a step downhill saves a little, and slopes are shaded so players
can see them. It is off unless a map names a height file; every tile then
reads height 0. Gaia's surface (z 2) uses `maps/heights/nomads_gaia.txt`.

This is separate from [geographic elevation](elevation.md) (metres per
rectangle, used for climate). Native z-levels still model caves, floors and
buildings; terrain height only shapes the ground within one z-level.

## Height files

`/obj/map_metadata` has `terrain_height_file`, a project-relative path such as
`maps/heights/nomads_gaia.txt`. The file is plain ASCII:

```
civ13-terrain-heights 1
size 500 350
z 2
<350 rows, north row first, 500 characters each>
```

Each character is a level from `0`-`9` then `a`-`f` (0 to 15). Several `z`
blocks may follow; z-levels without a block are flat. The size must match the
world. Any error (wrong header, size, row length, character or a repeated z)
leaves the whole map flat and logs the reason with `log_debug`.

The file is read once, on the first lookup, and kept as row strings (about one
byte per tile). Heights are map data, not world state: they are not saved, and
`terrain_height_file` and the cache are excluded from map metadata persistence.

## Movement

`client/Move` adds `terrain_slope_delay(from, to, step_delay)` after the
movement-intent costs, for living mobs walking between turfs (not when
buckled). For the level difference between the two tiles, capped at 4:

- uphill: +1 decisecond per level (a walking step is about 2.9);
- downhill: -0.5 per level, never more than a quarter of the step's delay.

Held movement rounds each step up to whole server ticks (0.4 ds), so on a walk
one level up is about 22% slower and one level down about 22% faster.

Built ground is laid level: a step onto, off or across a built floor (any
`/turf/floor` except grass, dirt, snow, beach, rocky, gravel, mined floor,
trench and lava) or a built wall has no slope cost, and those turfs are not
shaded (`terrain_smoothed()`). Building or removing a floor updates the
shading through `ChangeTurf`.

Smooth (sub-tile) steps go through the same code, so they pay the same cost.
NPC and animal movement do not use terrain height yet.

## Shading

Each tile corner gets a light level from -2 (shadow) to 2 (lit), computed from
the heights around it, with light from the north-west (`light_rows`). A tile
shows the sprite for its four corner levels, blended across the tile, so
neighbouring tiles join without seams; flat tiles (all corners 0) and water
show nothing. The 624 sprites in `icons/turf/terrain_shade.dmi` are made by
`scripts/terrain_heights.py bake-shading`; the tool's `corner_lights` and the
game's `light_rows` use the same maths, and the native test compares them.

The sprites are shared objects in the turf's `vis_contents`, on layer 2.005
(above the ground, below decals and objects), with `mouse_opacity = 0`, so
they are never clicked and never saved. The ticker places them once per round
(`terrain_shading_check`), and `ChangeTurf` puts them back on replaced turfs,
including turfs rebuilt by a save load.

Tuning: `RELIEF`, `LIGHT_STEP`, `DARK_ALPHA` and `LIGHT_ALPHA` at the top of the
shading section of the tool (and `TERRAIN_RELIEF`/`TERRAIN_LIGHT_STEP` in the
game for the first two). Re-bake after changing the alphas.

## Tools

`scripts/terrain_heights.py`:

- `generate --map maps/nomads/nomads_gaia.dmm --z 2 --out maps/heights/nomads_gaia.txt [--seed N]`
  builds heights from the turfs: water 0, beaches at most 1, rounded hills from
  smooth seeded noise on land that rises gently inland, and ridges near rock
  walls, with neighbouring tiles never more than 2 levels apart.
- `to-png` / `from-png` convert one z-level to and from a greyscale PNG (one
  pixel per tile, level x 17) so heights can be painted by hand.
- `check --heights FILE [--map FILE.dmm]` validates a file.
- `bake-shading [--out icons/turf/terrain_shade.dmi]` writes the shading sprites.

Admins can use **Debug > Show Terrain Heights** to label every tile in view
with its level; use it again to hide the labels.

## Tests

- `python3 -m unittest tests/terrain_height/test_terrain_height.py` (offline:
  generator, file format, baked sprites, Gaia's file, movement and shading hooks).
- `python3 tests/terrain_height/run.py --byond-bin <dir>` (native: the game's
  parser, lookup, slope cost and shading on a 12x12 fixture world, and the
  game's corner lights against the tool's).
