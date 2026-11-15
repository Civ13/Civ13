# Vehicle offsets

Vehicles are moving to pixel positions the way free-moving players do. The
plan is in five phases; this file describes the shared core
(`code/modules/craft/vehicle_offset.dm`, Phase 0). No vehicle uses it yet.

## How it works

- A `/datum/vehicle_offset` holds one shared offset (`ox`, `oy`, -16 to 15 px)
  for a whole vehicle and the things it carries (`carry()`, `drop()`).
- `pulse()` adds the speed (pixels per tick, `vehicle_offset_speed(ds per
  tile)`) and writes `step_x`/`step_y` directly on everything carried. No
  `Move()`, no turf events. Fractions of a pixel carry to the next pulse.
- Starting to overlap the next tile asks `can_cover(dir)`. Passing half a tile
  runs `commit(dir)`, the vehicle's own whole-tile step, and wraps the offset
  back by a tile, so everything stays filed under the tile under its centre.
- `/datum/vehicle_offset/axis` commits with the frame vehicle's `do_move()`
  (only the way it faces or backs). `/datum/vehicle_offset/single` commits
  with a one-object vehicle's `do_move(dir)`.
- `snap()` drops the offset without changing tiles. `vehicle_offset_snap_all()`
  is for the save path; nothing in the datum is saved.
- `watched()` says whether a player is within 12 tiles (rechecked every two
  seconds), for running whole tiles only when nobody can see the pixels.

## Cost (native probe, BYOND 516.1688, cloud container)

`python3 tests/vehicle_offset/run.py --byond-bin <BYOND bin>` drives a crate,
a motorcycle with a rider, a 2x3 frame car with a passenger and a carriage, and
times the pixel writes of a pulse:

| Load | Things carried | ms per pulse |
| --- | --- | --- |
| Carriage | 1 | 0.003 |
| 2x3 car with a passenger | 14 | 0.02 |
| Hull-sized load | 1000 | 1.5 |

The whole-tile step (`do_move`) still runs once per tile and costs what it did.
