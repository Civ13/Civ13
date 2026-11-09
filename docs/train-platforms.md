# Walkable platform cars

Code: `code/modules/1713/train_platforms.dm`, wartime cars in
`code/modules/1713/train_warfare.dm` and the rail warehouse in
`code/modules/1713/rail_warehouse.dm`. Sprites: `icons/obj/vehicles/train_platforms.dmi`
and `icons/obj/vehicles/railway_gun.dmi`.
Tests: `tests/train_platforms` (source contracts plus a native fixture).

## Shape

A platform car is three tiles wide and `TRAIN_CAR_LENGTH` (4) tiles long. Each
of its four segments is an `/obj/structure/trains/platform` on one rail tile,
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
| armored | armored wagon | automatic_weapons | armor plate with firing doors, four machine guns |
| flak | flak car | automatic_weapons | low armor, two autocannons, ammunition crates |

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

Wrecked and braced cars also stop their train (see below).

## Wartime cars

Explosions damage platform segments (`ex_act`, 450/220/80 by severity, 40% on
armored layouts). A segment at zero health is wrecked: it shows a wreck overlay
and its train cannot move. A welding tool repairs 300 health per pass and the
car is back on the rails at half health.

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

A unit is a platform car (its four segments) or a one-tile train object
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
