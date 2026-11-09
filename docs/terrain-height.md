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

### NPC sight

NPCs use a single-ray version of the same rule (`los_terrain_ray_blocked`):
one height sample per tile along the line from the NPC's eye to the target's
top, skipping the NPC's neighbours and the target's tile. It costs about
0.03 ms and agrees with the player sweep on about 98% of random pairs on Gaia.
`FindTarget` skips targets it hides, ranged human NPCs treat a hidden target as
out of sight (they move up, peek or suppress its last position instead of
firing), `ai_check_los` counts a ridge as cover and blocks peeks and raid
sightings over it, and nomad raiders do not fire over a crest. NPCs do not see
over walls from high ground; `view()` still decides walls for them.

### Gunfire

Bullets follow the same heights (`code/modules/projectiles/projectile_heights.dm`).
When a shot is first moved, `height_plan` draws a straight line from the
muzzle (the firer's ground plus 1.4 standing, 0.4 lying or prone) to the aim
point (the target's ground plus the clicked height on a mob, see Bullet drop,
or the firer's muzzle height above a clicked tile). For every tile it enters, `height_enter`
compares the line with the ground:

- Ground above the line stops the shot there: a ridge between shooter and
  target takes the bullet, and a shot fired downhill that misses lands in the
  ground beyond the target.
- Under the open sky, people, cover, walls and trees are passed over only when
  the line is above their top (the `los_target_top` values) by at least a
  standing body's height. A level shot over flat ground never is, so cover and
  bystanders work there as before; height advantage is what takes them away.
- Over a roofed tile the line either passes above the roof (ground plus 3) and
  skips the tile with everything under it, or keeps the ordinary rules.

#### Bullet drop

The line is really an arc: `height_at(d)` adds `drop_rate * d * (zero - d)`,
so the shot rises a little above the aim line, crosses it again at the
weapon's zero range and falls below it beyond. Zero and rate by class:

| Class | Zero (tiles) | Drop at twice the zero |
| --- | --- | --- |
| Rifle (default) | 12 | 1.5 levels at 24 tiles |
| Pistol | 7 | 1.5 levels at 14 tiles |
| Shotgun pellets, musket balls | 6 | 1.5 levels at 12 tiles |
| Musket pistol balls | 5 | 1.25 levels at 10 tiles |
| Arrows and bolts | 5 | 1.5 levels at 10 tiles |

The aim height comes from where the target was clicked (`p_y`): the bottom
of a standing mob's sprite is its feet, the top 0.85 of its height, and the
default mid-body. A mob lying down is aimed at 0.25 wherever it is clicked.
Holding over (clicking higher) reaches past the zero; a shot held too high
passes over the aimed-at mob (`height_misses`). A tile has depth, so across
the target's tile the arc covers half its slope either side of its centre
(`height_span`): when the ground takes the arc inside a tile, what stands
there can still be hit first, and a steep shot down from high ground
forgives more drop than a flat one. Drop applies only where the shot has a
height plan, so maps without a height file keep straight shots.

Shrapnel, shells, aircraft guns and redirected shots keep the flat rules. The
work is two height lookups and a square root per tile, about 0.008 ms against
0.001 ms without heights, and maps without a height file skip it entirely.

#### Lobbed arrows

Bows (not crossbows or slings) have two firing arcs, switched by alt-clicking
the bow in hand, the **Toggle Firing Arc** verb, and shown on examine. Direct
is the shot above: straight at the target, with arrow drop on hill maps
(sighted in at 5 tiles). Lobbed (`code/modules/projectiles/projectile_lob.dm`)
sends the arrow up a high arc that comes down on the clicked tile:

- The landing tile scatters around the aim point with a standard deviation of
  `0.25 + 0.08 * distance + |dispersion| / 25` tiles, so moving or a long
  lob lands less precisely.
- The arc rises `3 + 0.5 * distance` levels above the straight line from the
  bow (ground plus 1.4) to the landing point (ground plus 0.5). On the way it
  passes over people, cover, walls, trees and roofs; only ground above the
  arc stops it ("strikes the hillside"). Without a height file nothing stops
  it before it lands.
- On the landing tile it hits the aimed-at person with 70% chance (others
  standing there 42%), striking from above (head, chest and arms most often).
  A roofed tile takes it on the roof and a wall stops it; otherwise it sticks
  in the ground.
- Flight takes `0.3 + 0.06 * distance` seconds instead of a fraction of one,
  so a moving target can walk out from under it.
- It cannot be lobbed from under a roof. In flight the arrow sprite grows and
  rises toward the top of the arc.

Admins can use **Debug > Show Terrain Heights** to label every tile in view
with its level; use it again to hide the labels.

## Tests

- `python3 -m unittest tests/terrain_height/test_terrain_height.py` (offline:
  generator, file format, baked sprites, Gaia's file, movement and shading hooks).
- `python3 tests/los_terrain/run.py --byond-bin <dir>` (native: line of sight
  over hills on Gaia's heights against a Python reference, sweep cost, cache
  clearing on grading, and NPC sight rays against a reference and the sweep).
- `python3 tests/gunfire_heights/run.py --byond-bin <dir>` (native: real
  projectiles on a 16x8 hill world: ridge, hilltop over a wall, roof, people
  below the line, uphill to a crest, bullet drop with and without hold-over,
  a cliff shot forgiving drop, flat-ground controls and cost;
  NPC sight over the ridge; `--negative-control ridge|cover|margin|npc|drop|span|holdover` must fail).
- `python3 tests/bow_lob/run.py --byond-bin <dir>` (native: lobbed arrows on
  a 16x6 world: over a wall to a target the direct shot cannot reach, over a
  bystander, into a ridge, onto a roof, scatter growing with distance, flight
  time and the bow's toggle; `--negative-control arc|ridge|roof|scatter` must fail).
- `python3 tests/terrain_height/run.py --byond-bin <dir>` (native: the game's
  parser, lookup, slope cost and shading on a 12x12 fixture world, and the
  game's corner lights against the tool's).
