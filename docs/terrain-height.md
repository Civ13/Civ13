# Terrain height (hills)

Optional per-tile hill levels for a map's ground. A step uphill costs extra
move delay, a step downhill saves a little. It is off unless a map names a
height file, and no map does yet; every tile then reads height 0.

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

Smooth (sub-tile) steps go through the same code, so they pay the same cost.
NPC and animal movement do not use terrain height yet.

## Tools

`scripts/terrain_heights.py`:

- `generate --map maps/nomads/nomads_gaia.dmm --z 2 --out maps/heights/nomads_gaia.txt [--seed N]`
  builds heights from the turfs: water 0, beaches at most 1, land rising
  inland, ridges near rock walls and seeded noise, with neighbouring tiles
  never more than 2 levels apart.
- `to-png` / `from-png` convert one z-level to and from a greyscale PNG (one
  pixel per tile, level x 17) so heights can be painted by hand.
- `check --heights FILE [--map FILE.dmm]` validates a file.

Admins can use **Debug > Show Terrain Heights** to label every tile in view
with its level; use it again to hide the labels.

## Tests

- `python3 -m unittest tests/terrain_height/test_terrain_height.py` (offline:
  generator, file format, movement hook).
- `python3 tests/terrain_height/run.py --byond-bin <dir>` (native: the game's
  parser, lookup and slope cost on a 12x12 fixture world).
