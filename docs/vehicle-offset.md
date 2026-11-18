# Vehicle offsets

Vehicles are moving to pixel positions the way free-moving players do. The
plan is in five phases. The shared core is `code/modules/craft/vehicle_offset.dm`
(Phase 0); motorcycles, boats, bicycles and rafts drive with it
(`vehicle_offset_ride.dm`, Phase 1), and so do carriages, player-built
hulls under way (`vehicle_offset_hull.dm`) and frame vehicles
(`vehicle_offset_frame.dm`, Phase 2).

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

## Bicycles, rafts and carriages (Phase 1b)

- Bicycles and running bikes keep their own pedal loop. While someone is near
  it ticks every server tick at `vehicle_offset_speed(vehicle_m_delay)`; the
  bicycle's `do_move()` still runs once per tile (when the offset passes half a
  tile), so stamina, load, ground and hills are paid and set the pace exactly
  as before. Braking or stopping pedalling stops it where it is. Pedal
  airships fly and stay on whole tiles until the aircraft phase.
- Rafts and dugout canoes are paddled by key: while the driver holds a
  direction key for the way they face, the raft moves by pixels that way
  (`offset_paddling`); let go and it drifts to a stop within about half a
  tile. Before, each key press moved one tile. A dugout is quicker with a
  paddle in hand, as before. With nobody near, a key press is one tile step.
- Carriages roll by pixels the way they face, with the driver, the seats, the
  team in harness and a hand cart hitched behind all on one offset
  (`vehicle_offset_aboard()`). The carriage's `do_move()` still runs once per
  tile (load, team, ground, hills, running into people). Before the rig starts
  to overlap the tiles ahead, the carriage's and its team lane's cells must be
  open ground with no structures (`/datum/vehicle_offset/single/carriage`). A
  turn squares it on its tile first. Reining in stops it where it is.
- Hand carts pulled by hand already follow a free-moving puller by pixels
  (living.dm); one hitched to a carriage rides its offset.
- Riders carried by any vehicle make no footstep sounds
  (`carried_by_vehicle()`); the engine loop is the vehicle's sound.

## Cars, trucks, buses and tanks (Phase 2)

- `/obj/structure/vehicleparts/axis/movementloop()` is overridden in
  `vehicle_offset_frame.dm`; `axis.dm` keeps the tile loop and is called
  through `..()` whenever pixels are off. Aircraft, the axes of one-object
  boats (`offset_drive = FALSE`), towing rigs (`tow_out`, `tow_in`) and
  vehicles with a cargo trailer hitched stay on whole tiles.
- While a player is within 12 tiles plus its `maxdist`, and no save is
  running, each tick moves `vehicle_offset_speed(vehicle_m_delay + 1)`
  pixels the way it faces (or backs). The frames are the body; the wheels,
  seats, engine, cargo and crew from `add_transporting(FALSE)` ride on them
  (`vehicle_offset_sync()`), with walkers judged by the deck as drawn, as on
  built hulls.
- Starting to overlap the tiles ahead runs `do_vehicle_check()` once (crashes,
  mines, running people over, deep water, grace walls); a refusal is the tile
  loop's stop, roof riders thrown off at speed. Half a tile on, `do_move()`
  makes the tile step with `offset_committing` set: it moves only what the
  offset carries and skips its glide. The load then sets the pace for the next
  tile, as before.
- Out of gear it coasts on, slowing, to the next square and stops there with
  nobody carried. With the engine cut while coasting it stops square at the
  next tile edge. A turn (`do_matrix()`) squares it first and swings round on
  whole tiles.

## Frame ships

`vehicle_offset_ship.dm` sails workshop-built ships (`axis/ship`, submarines
included) the same way. `ships/axis.dm`'s `movementloop()` asks
`ship_offset_movementloop()` first and keeps its tile loop for when nobody is
near. Under sail `check_sails()` sets her gear and pace before she gets under
way. Each time she starts to overlap the water ahead, `can_cover()` runs
`vehicle_offset_tile_ahead()` (load, `check_sails()`, sails set and whole)
and then `do_vehicle_check()`; she stops as on whole tiles, nobody thrown
off. After each tile step `vehicle_offset_stepped()` checks her degaussing
coil and naval mines. A turn ordered while she is between squares is held
(`offset_turn`, `vehicle_offset_hold()` caps her pace at the next square)
and made once she is square, so she never jumps back to her tile before
coming about. A davit hoist and a submarine's dive or surfacing square her
first, since those level changes move whole tiles.

Turns of every frame vehicle are drawn by `glide_turn()`: before the moves
`glide_turn_hold()` sets everything that would glide to move at once, then
each thing is drawn where it was and slides to its new place.

## Walking on a moving deck

- `settle()` runs at the start of every pulse. Each carried entry is
  `list(own x, own y, drawn x, drawn y)`; the last two are where `draw()` last
  put the thing, in absolute pixels. Anything that has moved since (a person
  walking, a crate shoved) keeps where it went, and its own offset is taken
  again from where it stands. Seated riders and cargo cost one comparison.
- A walker stays filed under the body tile beneath its centre as the body is
  drawn (`file_on_deck()`, a direct `loc` write like `human_subtile_anchor()`),
  so someone at the bow is never filed onto the open tile ahead while the body
  overlaps it. Someone whose centre leaves every body tile has stepped off:
  `drop()` keeps them where they are drawn and `vehicle_offset_refile()` files
  them by their own centre again.
- `vehicle_offset_riders` maps everything carried to its offset. A carried
  person's step offset can reach -32 (deck offset -16 plus their own -16), so
  `human_subtile_shape()` accepts down to -32 for riders, and
  `vehicle_offset_drawn()` gives a free-moving person the offset to own
  (`human_subtile_offset_owned`) so they can walk by pixels. Someone with free
  movement off walks whole tiles, back onto their tile, and is carried on from
  there.
- A turf's contents include anything that overlaps it by pixels. Code that
  asks what stands on a tile while a vehicle may be offset checks `loc`.

## Built hulls under way

`vehicle_offset_hull.dm` sails player-built hulls (`craft_body/built`) by
pixels. `start_sailing()` runs `craft.offset_tick()` every
`offset_period()` (her tile interval / 32, a pixel a pulse: 4.7 ds at slow
ahead). Each tick `settle()`s walkers, `sync()`s the carried set with
`body.aboard()` (her planks are the footprint) and pulses along her heading.
Starting to overlap the water ahead (`can_cover()`) asks `can_move_to()` and
marks the path; half a tile on, `commit()` runs her `move_to()` with no glide
and her drives pay for the tile (`sail_paid()`). A refusal is the usual all
stop (`sail_refused()`). With nobody within 12 tiles plus her length, or during
a save, she squares on her tiles and hops a whole tile per interval as before.
A turn holds her where she is while it is marked, then squares her before she
comes about; all stop and anchoring square her too. `plan()` only counts a
floor filed on a tile as in the way, since her own overlapping planks are
listed there too.

## Cost (native probe, BYOND 516.1688, cloud container)

`python3 tests/vehicle_offset/run.py --byond-bin <BYOND bin>` drives a crate,
a motorcycle with a rider, a 2x3 frame car with a passenger and a carriage, and
times the pixel writes of a pulse:

| Load | Things carried | ms per pulse |
| --- | --- | --- |
| Carriage | 1 | 0.003 |
| 2x3 car with a passenger | 14 | 0.02 |
| Hull-sized load | 1000 | 1.7 |

The whole-tile step (`do_move`) still runs once per tile and costs what it did.
