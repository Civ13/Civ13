# Walkable platform cars

Code: `code/modules/1713/train_platforms.dm`, wartime cars in
`code/modules/1713/train_warfare.dm` and the rail warehouse in
`code/modules/1713/rail_warehouse.dm`. Sprites: `icons/obj/vehicles/train_platforms.dmi`
and `icons/obj/vehicles/railway_gun.dmi`.
Tests: `tests/train_platforms` (source contracts plus a native fixture).

## Art

Both sheets are drawn by `tests/sprites/create_trains.py` (helpers in
`tests/sprites/trainkit.py`); change the art there and rerun it rather than
editing the sheets by hand. `--check` verifies the committed sheets and
`--preview <dir>` writes whole trains composed the way the game lays the tiles
out. Everything is seen from straight above and lit from the upper left in
every direction. `l`, `c` and `r` in a state name are the tile left of the
heading, the rail tile and the tile right of it.

- `end_f*` / `end_b*`: the headstock with buffers and coupling on a car's
  first and last segment. `apply_layout()` adds them as overlays that follow
  their tile's own direction. `outrigger` is added either side of a braced
  gun car's end segments by `update_car_overlays()`.
- `loco_tender_<1-4><l|c|r>`: the walkable tender, cut like the locomotive
  bodies. `icons/obj/vehicles/rail_water.dmi` (64 x 64, from the same script)
  holds `water_tower` and `water_crane`, each turned four ways
  ([trains.md](trains.md#tenders-and-water-stops)).
- `coupler_<f|b>_<free|linked|broken|none>` and `coupling_item`: the coupling
  at a car's front or rear end in each condition, and the spare. They turn
  with the car ([trains.md](trains.md#couplings)).
- `knuckle_<f|b>_<free|linked|broken>` and `knuckle_item`: the same for an
  automatic coupler ([trains.md](trains.md#shunting)).
- `ash_pit`, `ash_pit_ash`, `ash_pit_full` and `fire_rake`: the ash pit
  between the rails, turned along its track, and the fireman's rake
  ([trains.md](trains.md#servicing)).
- `brake_shoes`: a spare set of brake shoes
  ([trains.md](trains.md#servicing)). `rail_water.dmi` also holds
  `coal_stage_empty`, `coal_stage`, `coal_stage_full`, `sand_bin_empty` and
  `sand_bin`: the coaling stage and the sand bin
  ([trains.md](trains.md#the-depot)).
- `plough_item`: a snowplough on the ground. `train_plough.dmi` (96 x 96,
  from the same script) holds `plough_f` and `plough_b`, the plough on a
  car's front or rear end ([trains.md](trains.md#snow)).
- `brake_wheel` and `brake_wheel_on`: the brake wheel of a brake van, wound
  off and on ([trains.md](trains.md#brakes)).
- `edge_plank`, `edge_freight_door[_open]`, `edge_side`, `edge_drop_door[_open]`
  and the `boards` deck: the boxcar's boarded sides and sliding doors, the
  open wagon's plank sides and drop doors, and the worn floor of goods stock.
- `roof_<coach|steel|armor|boxcar>_<f|m|b><l|c|r>`: roofs for the enclosed cars
  (front row, middle rows, back row), each with a flat walkway down the rail
  tile. Not displayed yet: showing them belongs to the train roof riding work.
- `loco_<steam|diesel|armored>_<1-4><l|c|r>` and `roof_loco_<variant>_<l|c|r>`:
  3x4 locomotive bodies and their cab roofs (steam and armoured cab on
  segment 3, diesel cab on segment 1), used by the heavy locomotives
  ([trains.md](trains.md#heavy-locomotives)).
- `loco_mainline_<1-6><l|c|r>` and `roof_loco_mainline_<l|c|r>`: the 3x6
  main-line engine, cab on segment 6 with the driver's stand, firebox door
  and fireman's injector drawn in it
  ([trains.md](trains.md#cab-stations-and-the-main-line-engine)).

## Shape

A platform car is three tiles wide and as long as its kind has segments
(`train_car_length()`): `TRAIN_CAR_LENGTH` (4) for the early four-wheel stock,
`TRAIN_LONG_CAR_LENGTH` (8) for bogie stock. Each
of its segments is an `/obj/structure/trains/platform` on one rail tile,
hitched to the next exactly like the one-tile wagons, so a car bends round
curves instead of needing straight track. Segments are not dense: players walk
on the centre tile and on a deck tile either side of the track.

When a segment moves it carries everything standing on its three tiles (people,
furniture, crates, guns) to the matching tiles of its new position, and turns
furniture with it on a curve. Track, cables, flora, floor covers, effects and
other trains are never picked up. Before the first platform segment of a train
moves, `train_platform_plan_from()` assigns every load on every segment's tiles
to that segment (a side tile that is another wagon's centre belongs to that
wagon), so on a tight curve, where one car's new tiles are another's old ones,
cargo never changes cars or moves twice.

## Parts

Deck tiles and walls, windows, railings and doors are `/obj/structure/train_part`
objects owned by a segment. They have `should_save = FALSE` and are rebuilt by
`apply_layout()` on spawn and in `after_load()`, from the segment's saved
`car_kind`, `seg_index` and `open_doors` bit field. Edges are `ON_BORDER`
objects, so they block walking across one tile edge only. Civilian walls do not
stop bullets; armor plate stops bullets fired from outside the car but lets the
crew fire out (`train_part/edge/stops_projectile()`).

Car kinds are defined in `train_car_layout()`: per segment, the fittings put
down when a furnished kit is assembled and the edges (side, which edge, style).

| Kind | Name | Research | Fittings |
| --- | --- | --- | --- |
| flatbed | platform car | rail_steam | open plank deck, railings at the ends |
| coach | passenger coach | rail_steam | six seats, windows, side and end doors |
| sleeper | sleeper car | assembly_line | three compartments a side, bed and sliding door each |
| dining | dining car | assembly_line | stove, sink, fridge, counter, two booths |
| storage | storage car | assembly_line | cabinets and large crates behind compartment doors |
| railgun | railway gun car | field_artillery | railway gun on the centre, outrigger lever, shell rack |
| armored | armored wagon | automatic_weapons | armor plate with firing doors; emplaced machine guns are forged separately |
| flak | flak car | automatic_weapons | low armor, ammunition crates; autocannons are forged separately |
| long_flatbed | bogie flatcar | rail_steam | 8 tiles: open plank deck, railings at the ends |
| open_wagon | open wagon | rail_steam | 8 tiles: plank sides all round, drop doors in the middle of each side |
| boxcar | boxcar | rail_steam | 8 tiles: boarded sides and roof, sliding doors in the middle of each side, closed ends |
| bogie_coach | bogie coach | assembly_line | 8 tiles: a vestibule each end, twelve seats, windows |
| brake_van | brake van | rail_steam | a veranda, then a cabin with a brake wheel and a seat; weighs 4 ([trains.md](trains.md#brakes)) |

An 8-tile car weighs 4 empty, twice a four-wheel car. The rail warehouse and
the inter-region railway take cars of either length.

## Kits, assembly and dismantling

Each car is crafted as a `/obj/structure/train_car_kit` (trains section). Set it
on straight track, face the way the car should face (towards the locomotive)
and use a hammer: the kit tile and the three tiles behind it need straight rail
along that direction and a clear tile either side. The front segment couples to
the car or locomotive ahead with the usual Hitch verb; inner segments refuse it.

A crowbar on an uncoupled, stopped car with nothing on its deck packs it into an
unfurnished kit (`furnished = FALSE`): its fittings had to be removed first, so a
rebuilt car comes without free furniture.

## Clearance

`process_rail_movement()` (trains.dm) calls `train_consist_obstacle()` before the
leading wagon moves. The walk predicts every car's next tile and heading and
stops the train when a deck tile would hit a dense turf, a dense object or
another train, and when the leading wagon would drive onto another train's
deck. People beside the track are not hit by a deck; they end up standing on it.
Platform segments then move with `persistence_set_loc()` rather than turf
entry, so their own walls never block them.

Wrecked and braced cars also stop their train (see below). At speed a blocked
step is a crash ([trains.md](trains.md#crashes)).

## Wartime cars

Explosions damage platform segments (`ex_act`, 450/220/80 by severity, 40% on
armored layouts). A segment at zero health is wrecked: it shows a wreck overlay
and its train cannot move. A welding tool repairs 300 health per pass and the
car is back on the rails at half health. A crash derails the leading cars into
the same state at 40% health, so one pass per section re-rails them.

The railway gun (`/obj/structure/cannon/modern/railway`) only fires while its car
is braced. The outrigger lever braces every segment of the car once it has stood
still for `TRAIN_BRACE_SETTLE`; a braced car blocks the train until the lever is
raised again.

The armored locomotive (`/obj/structure/trains/locomotive/coal/armored`, field
artillery research) ignores bullets and loses health to explosions instead of
being destroyed. At zero health its boiler is holed and it will not start until
welded back above half health.

## Rail warehouse

A drive-through store for rolling stock (`/obj/structure/rail_warehouse`, rail
steam research). The office post is built facing the track with one tile
between them; the straight track running past it, `RAIL_WAREHOUSE_REACH` (6)
tiles either way of the centre line, is the bay. Players build the walls and
roof around it however they like; the track carries on through both ends.

A unit is a platform car (all its segments) or a one-tile train object
(locomotive, tender, wagon). The post puts away units with nothing hitched
behind them, so a train standing in the bay is unloaded from the back, one
car at a time or all at once. A unit must be wholly inside the bay, stopped,
with nobody aboard and, for a railway gun car, its outriggers raised.

Storing moves the unit and everything its tiles carry into
`/obj/structure/rail_stored_unit` and `/obj/structure/rail_stored_tile` holders
inside the post (segment and side per tile). Nothing stored is on the map, and
world saves carry it as nested contents of the post. A stored platform segment
keeps no deck parts (`apply_layout()` stops when its loc is not a turf).

Taking a unit out rolls it onto the bay track behind the rear of the train in
the bay, facing the same way, and couples it; furniture turns with it if the
car faces another way than when it was stored. In an empty bay it rolls to the
far end it faces. The tiles it needs (and the deck tiles either side for a
platform car) must be straight bay track and clear.

## Riding on the roof

Coaches, sleepers, dining, storage and armored cars have a roof (`"roof"` in
`train_car_layout()`); flatbeds and gun cars stay open. Their segment and side
deck parts are deck surfaces for `vehicle_decks.dm`: climb up from beside the
car, walk along the roof and across couplings to the next car, and jump off
the side. A rider is carried like any other cargo, and `train_deck_clearance()`
knocks riders off under a building roof. Roof pictures (`roof_<kind>_<row><col>`
in `train_platforms.dmi`) are shown by `process_train_roofs()` to everyone
except those inside that car, and only once the art exists.
