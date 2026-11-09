# Piece-by-piece projects

Code: `code/modules/1713/piece_projects.dm` (plans) with
`code/modules/naval/slipway.dm` (ships) and
`code/modules/1713/machinery/modular_vehicles/vehicle_projects.dm` (cars and
planes). Tests: `tests/naval_carrier/slipway_probe.dm` and
`tests/vehicle_projects/probe.dm`.

## Plans

A `/datum/piece_plan` is a list of stages. Each stage has a number of pieces,
a material cost per piece, the part of the vehicle it builds and a name for
one piece. `next_piece()`, `still_needed()`, `stage_progress()` and
`progress_text()` take the number of pieces done and what has been paid
towards the next piece; `piece_pay()` takes what a held stack can pay. A
holder keeps only three plain vars (the plan's name, pieces done and paid),
so a half-built project saves without any save code.

Ship designs (`/datum/slipway_design`) are piece plans with the berth looks;
see [slipway.md](slipway.md).

## Cars and planes

The automobile workshop and the aircraft hangar (`piece_projects` TRUE; the
shipyard, submarine pen, rover bay and extraction workshop keep only the
one-go assembly) offer "Start a MODEL piece by piece" for every model. The
plan is made from the press's own `costs(model)`, so it costs exactly what a
one-go assembly does:

| Stage | Pieces | Cost per piece |
| --- | --- | --- |
| Chassis / Airframe | 2 | a fifth of the steel |
| Wheels / Landing gear | 4 | 1 wheel |
| Engine | 1 | the rest of the steel, all the cable |
| Bodywork / Skin | 2 | a fifth of the steel |
| Windows / Canopy | 1 | all the glass |
| Seats | 1 | all the cloth |

Stacks are paid by hitting the press or any part of the vehicle in the bay;
wheels are dragged onto either. A piece takes 3 seconds of work and needs no
power. Anyone may work on it; the project needs the press's research.

The bay shows `/obj/structure/vehicle_project_part` objects, one per cell of
the vehicle (never saved, rebuilt by `update_project_frames()` after every
piece and in `after_load()`): an assembly jig, then the bare chassis or
airframe floor, then the finished body seen from outside, with the wheels,
engine and tank, seats and plates as they are fitted. Each stage covers the
vehicle from the back row to the front. The cells and parts come from the
same layout the press assembles (`project_layout()`: the premade car's
`tocreate` or the light plane's layout).

When the last piece is fitted the press offers "Roll out". Roll-out clears
the jig, draws 20 power like an ordinary assembly, credits the plan's
materials to the stock and runs `complete_assembly()`, so the car gets its
keys and the plane its empty tank exactly as in one go. If the assembly
fails the materials are taken back off the stock and the jig returns.
Abandoning loses everything fitted so far, as at the slipway.
