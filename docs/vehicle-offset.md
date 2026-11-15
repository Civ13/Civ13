# Vehicle offsets

Vehicles are moving to pixel positions the way free-moving players do. The
plan is in five phases. The shared core is `code/modules/craft/vehicle_offset.dm`
(Phase 0); motorcycles and boats drive with it (`vehicle_offset_ride.dm`,
Phase 1).

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
- `snap()` drops the offset without changing tiles. Nothing in the datum is
  saved.
- `watched()` says whether a player is within 12 tiles (rechecked every two
  seconds), for running whole tiles only when nobody can see the pixels.

## Motorcycles and boats (Phase 1)

- `/obj/structure/vehicle/movementloop()` is overridden in
  `vehicle_offset_ride.dm`; `transports.dm` keeps the tile loop and is called
  through `..()` whenever pixels are off.
- Vehicles with `offset_drive` (motorcycles, boats) roll by pixels while
  `vehicle_offset_drives()`: a driver, a player within 12 tiles and no save
  running. Each tick moves `vehicle_offset_speed(vehicle_m_delay + 1)` pixels
  in the driver's direction; the vehicle's `do_vehicle_check()` (water,
  crashes, grace walls) runs when it starts to overlap the tile ahead.
- Turning keeps the sideways offset. Out of gear it coasts to a stop within
  about half a tile (`offset_coast`). Riders in `ontop` sit at the vehicle's
  offset and step off where it is drawn.
- With nobody near, `vehicle_offset_release()` squares it on its tile and the
  tile loop takes over. A save in progress counts as nobody near, so the next
  tick squares every pixel-driving vehicle; the offsets are runtime vars
  either way. `vehicle_offset_snap_all()` squares them all at once.

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
