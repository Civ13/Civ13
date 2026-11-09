# Slipway shipbuilding

Code: `code/modules/naval/slipway.dm`, on top of the turf-built vessels in
`code/modules/naval/vessel.dm`. Test: `tests/naval_carrier/slipway_probe.dm`
(run with `tests/resource_extraction/run.ps1 -Probe tests/naval_carrier/slipway_probe.dm`).

Ships are built piece by piece on the shore and launched into the water, the
way platform cars are assembled on the track and rolling stock is stored in
the rail warehouse.

## The slipway post and the berth

`/obj/structure/slipway` is crafted from 20 soft wood (vehicle parts, Wagons &
Ships research). It faces the water: the berth is the ground in front of it,
the ship's stern at the post and her bow towards the water. A wrench turns an
empty post. The berth tiles must be floor (sand, grass, a dug trench or water),
with no solid object on them and no other berth or ship across them.

A keel is only laid when the ship could float somewhere ahead: sliding along
the post's facing by up to her length plus `SLIPWAY_RUN` (12) tiles, her whole
footprint (and her hold, on the level below) must be open deep water. A berth
that already lies in deep water launches in place.

## Designs, stages and pieces

`/datum/slipway_design` lists the vessel type, research node and the stages.
Each stage has a number of pieces with a material cost per piece and the part
of the ship it builds (`keel`, `frames`, `hull`, `deck`, `below`, `fittings`).

| Design | Research | Size | Pieces | Materials |
| --- | --- | --- | --- | --- |
| sailing schooner | wagons_ships | 14 x 5, one deck | 16 | 180 wood, 20 cloth, 4 rope |
| motor freighter | combustion | 20 x 7, deck + hold | 20 | 214 steel, 20 cable, 10 glass |

Players hit the post or any part of the hull with a material stack. After
`SLIPWAY_PIECE_TIME` the stack pays what the next piece still needs; a piece is
fitted as soon as it is fully paid, and the rest of the stack is kept. Any
number of players can work on the same ship.

## What the berth shows

`/obj/structure/slipway_frame` objects (one per surface cell, never saved,
rebuilt by `update_frames()` after every piece and in `after_load()`) show the
project: a faint cradle under unbuilt cells, the keel timber on the centre
line, the ribs, then the finished hull (outer cells) and deck (inner cells) in
the final turf's look, and the masts, wheel and other fittings as overlays.
Each stage covers the ship from stern to bow, a share per piece. Stages that
build below decks (the freighter's hold and engine) do not change the berth.

The post saves `design`, `pieces_done` and `paid`; nothing else is needed.

## Launch

When the last piece is fitted the post offers the launch. A berth in a dug
trench (a dry dock) must be flooded first. Every tile the ship slides over on
the way must be clear of walls and solid objects. The launch removes the
frames and places the vessel with `/datum/vessel/place()` at the first slide
that floats; everyone and every loose object standing on the hull goes with
her, to the same place on the deck. She floats anchored, all stop, with empty
bunkers, and the berth is free for the next keel.

## The ships

- **Sailing schooner** (`/datum/vessel/schooner`): one wooden deck, two masts
  (`/obj/structure/vessel_mast`) and the wheel at the stern. `fuel_burn()` is
  zero, so she sails without fuel, and `top_speed` is half ahead.
- **Motor freighter** (`/datum/vessel/freighter`): a steel deck with a
  wheelhouse at the stern and a ladder down to the hold. Below the waterline
  are the cargo hold and, behind a bulkhead with a blast door, the engine room
  with the bunker filling point (400 units of diesel or petroleum). Two flooded
  compartments sink her.

Both use the vessel helm, chart, anchor, hops and saved state like the carrier.
