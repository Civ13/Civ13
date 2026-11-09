# Walkable platform cars

Code: `code/modules/1713/train_platforms.dm`. Sprites: `icons/obj/vehicles/train_platforms.dmi`.
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
other trains are never picked up. A segment moves before the cars behind it,
so nothing is carried twice; `train_platform_carried` guards the overlapping
tiles of a tight curve.

## Parts

Deck tiles and walls, windows, railings and doors are `/obj/structure/train_part`
objects owned by a segment. They have `should_save = FALSE` and are rebuilt by
`apply_layout()` on spawn and in `after_load()`, from the segment's saved
`car_kind`, `seg_index` and `open_doors` bit field. Edges are `ON_BORDER`
objects, so they block walking across one tile edge only. Civilian walls do not
stop bullets.

Car kinds are defined in `train_car_layout()`: per segment, the fittings put
down when a furnished kit is assembled and the edges (side, which edge, style).

| Kind | Name | Research | Fittings |
| --- | --- | --- | --- |
| flatbed | platform car | rail_steam | open plank deck, railings at the ends |
| coach | passenger coach | rail_steam | six seats, windows, side and end doors |
| sleeper | sleeper car | assembly_line | three compartments a side, bed and sliding door each |
| dining | dining car | assembly_line | stove, sink, fridge, counter, two booths |
| storage | storage car | assembly_line | cabinets and large crates behind compartment doors |

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
