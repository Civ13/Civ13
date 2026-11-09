# Terrain height (hills)

Optional per-tile hill levels for a map's ground. A step uphill costs extra
move delay, a step downhill saves a little, and slopes are shaded so players
can see them. It is off unless a map names a height file; every tile then
reads height 0. Gaia's surface (z 2) uses `maps/heights/nomads_gaia.txt`, designed from its terrain by the tool's
`design` command with `maps/heights/nomads_gaia.design.json`. The Nomads
maps of the other earth regions, Europe (z 1), Jungle (z 2), Desert (z 2) and
Asia (z 1), have their own `maps/heights/nomads_<map>.txt` and
`.design.json` made the same way.

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

Steep steps (3 or more levels in one tile, `TERRAIN_STEEP_LEVELS`) are felt as
well as paid for. `terrain_climb_effects` runs for humans after the slope
cost: scrambling up spends 0.5 stamina per level (half of that onto tamped
earth, scaled by the share of a tile moved, never below 0), and either
direction prints a short notice, at most one per 10 seconds per player.
`terrain_step_levels(from, to)` is the shared signed, capped level change
that both procs use; it is 0 across built ground or without a height file.

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

## Floor covers and tamped earth

Built ground is level: `/turf/floor` subtypes other than natural ground,
built walls, and any floor or road cover (`/obj/covers` that is not a cover
wall) on a natural tile. `terrain_smoothed()` covers all three, so these tiles
have no slope cost and no shading. Covers refresh their tile's shading when
they are laid (`updateturf`) and removed (`Destroy`).

The stone rammer (`code/modules/1713/road_tamping.dm`, crafted from 2 stone
with no research) packs bare dirt into `/turf/floor/tamped_earth` in about
3 seconds (faster with strength). Tamped earth is packed, not levelled: it
keeps its height and shading, but a step uphill onto it costs half
(`terrain_packed()`, `TERRAIN_PACKED_UPHILL_SHARE`); downhill is unchanged.
Grass must be cleared with a shovel first, and snow, covers or crops block it.
Tamped earth never turns to mud, and a shovel breaks it back into plain dirt.

Grading changes the heights themselves, one level at a time. A shovel on
disarm intent cuts a dirt or tamped-earth tile down a level (about 10 seconds,
faster with strength), leaves loose dirt and drops a dirt pile
(`/obj/item/weapon/barrier`). The rammer on a tile with a dirt pile on it
packs the pile in, raises the tile a level and leaves tamped earth. A tile
moves at most `TERRAIN_GRADE_LIMIT` (2) levels from the file's height and
stays within 0-15; snow, covers, crops, dense objects or water within one tile
block it. The change is `turf.terrain_grade` (saved only when non-zero,
carried across `ChangeTurf`, re-applied by `after_load`). `set_level` patches
the height rows and recomputes the corner lights around the tile
(`light_char`, the same maths as `light_rows`); the original file rows stay in
`base_rows_by_z`.

## Tools

`scripts/terrain_heights.py`:

- `generate --map maps/nomads/nomads_gaia.dmm --z 2 --out maps/heights/nomads_gaia.txt [--seed N]`
  builds gentle heights from the turfs: water 0, beaches at most 1, rounded
  hills from smooth seeded noise on land that rises gently inland, and ridges
  near rock walls, with neighbouring tiles never more than 2 levels apart.
- `design --map maps/nomads/nomads_gaia.dmm --z 2 --spec maps/heights/nomads_gaia.design.json --out maps/heights/nomads_gaia.txt`
  builds heights that read the terrain, and is how Gaia's file is made. Rock
  walls, bare rock floors and lava are highland plateaus (level 8 at the edge,
  rising to 13, lava at 15). The land around a highland climbs steeply (3
  levels per tile) where the range is within 12 tiles of the sea and gently
  (1 per tile) inland. The coast is a low plain with rolling hills behind it;
  rocky shores that are already 4 or higher stay up as sea cliffs, and sandy
  beaches stay at most 1. Narrow arms of the sea are rivers: their valleys are
  low, but a bank that is already high stays as a gorge wall. Desert lakes get
  crater rims (level 4-5 right at the water), other lakes get gentle basins.
  Marshes stay flat. The JSON spec adds hand-placed features in game
  coordinates: `ridges` (a polyline, `height`, `width`, a steep and a gentle
  side), `passes` (rectangles where highland approaches are gentle), `scarps`
  (steep, with an optional `grade`), `craters` (lakes that get rims) and
  `flat` rectangles (optionally with a `height`). The ground around every
  spawn landmark is levelled, and each authored building or ruin (plating and
  built wall turfs) sits on one level; natural rock walls are highland, built
  walls are not. Any tuning value in `DESIGN_DEFAULTS` can be
  overridden in the spec. Walkable neighbours never differ by more than 4
  levels, the most the game counts for one step.
- `to-png` / `from-png` convert one z-level to and from a greyscale PNG (one
  pixel per tile, level x 17) so heights can be painted by hand.
- `check --heights FILE [--map FILE.dmm]` validates a file.
- `bake-shading [--out icons/turf/terrain_shade.dmi]` writes the shading sprites.

## Line of sight

Ground between a player's eye and a target hides the target when it rises
above the sight line (`code/modules/visibility/los_terrain.dm`). Ridges hide
what lies behind them, the top of a plateau above eye level is hidden from
below, and a player on high ground sees further down the far slope. Hidden
tiles are drawn black by the geometric visibility presenter and refuse hover
and examine, like tiles behind a wall.

- The eye is 1.5 levels above the ground standing and 0.5 lying, resting or
  prone. A target shows when its top does: bare ground 0.25 above its level,
  items 0.5, dense objects 1, people 1.5 (0.5 lying), walls 3 and trees 5. So
  a person's head or a tree shows over a crest before the ground under it.
- The answer for one eye position is a ring sweep outward from the eye: each
  cell's sight-line floor comes from the two cells of the previous ring that
  the ray passes between, interpolated (like XDraw), so a whole view costs one
  pass instead of one ray per target. Hidden ground with at most two hidden
  neighbours is shown, which removes specks from one-level dips.
- Heights only change by grading, so the answer is cached per eye position
  (tile, half-tile offset, posture, view radius; 96 entries) and shared by all
  players. Grading (`terrain_heights/set_level`) clears the cache and refreshes
  nearby viewers. Flat ground and levels without heights skip all of it.
- The eye follows the player's pixel offset in half-tile steps, both for this
  and for walls and trees, so a walker's view refreshes twice per tile instead
  of once. These extra steps pause while `world.cpu` is above 85 and resume
  below 60. Hover and examine use the exact offset.

A fresh answer for a 19x19 field costs about 2.3 ms on the pinned DreamDaemon
(`tests/los_terrain/run.py`); cached lookups are a list read. NPC sight and
gunfire do not use heights yet.

### Seeing over walls and trees

From high ground a viewer sees over lower blockers. Each blocker cell gets an
absolute top (its ground plus 3 for walls, doors and other opaque things, 5 for
trees), and a blocker that the 2D rule says is in the way is skipped when the
sight line from the eye to the target's top passes above it, measured at the
blocker's centre (`los_height_clears`). Inside roofed areas (`AREA_INSIDE`)
nothing is seen over walls: a roofed target or blocker keeps the flat rule.
Ground right behind a wall stays hidden; the further behind it, the more shows.

BYOND hides everything behind an opaque atom for the client whatever our
geometry says, so this needs the `SEE_TURFS|SEE_OBJS|SEE_MOBS` sight flags
(`mob.los_height_sight`). A viewer gets them only while its last published
snapshot has a blocker whose top is below the eye (`see_over`), and only
after that publication has masked every atom it cannot see. Every path that
leaves the presentation unpublished (retired context, failed capture or
publish, world reconstruction, ineligible body) drops them first.
`handle_vision` keeps them across its sight reset, and they are left out of the
presentation policy key. Because `viewers()` follows these flags,
`visible_message` checks the height rule (`los_height_message_hidden`) for such
a viewer. Remaining exposure while the flags are on: an atom created behind a
wall without moving is unmasked until the next refresh or the 1-second audit,
and `view()`-based checks for that viewer reach past walls (clicks on hidden
atoms still act on their tile).

Admins can use **Debug > Show Terrain Heights** to label every tile in view
with its level; use it again to hide the labels.

## Tests

- `python3 -m unittest tests/terrain_height/test_terrain_height.py` (offline:
  generator, file format, baked sprites, Gaia's file, movement and shading hooks).
- `python3 tests/los_terrain/run.py --byond-bin <dir>` (native: line of sight
  over hills on Gaia's heights against a Python reference, sweep cost, and
  cache clearing on grading).
- `python3 tests/terrain_height/run.py --byond-bin <dir>` (native: the game's
  parser, lookup, slope cost and shading on a 12x12 fixture world, and the
  game's corner lights against the tool's).
