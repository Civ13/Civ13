# Vehicle sheets

A ship's draught (`/obj/item/ship_draught`) can carry a land vehicle or a plane
instead of a ship or a submarine: kind `CAR` in `draught_kinds`
(`code/modules/naval/draught_kinds.dm`), datum `/datum/vehicle_draught` in
`code/modules/craft/vehicle_draught.dm`.

## The sheet

- Axis: `car` (light axis, 800), `heavy` (heavy axis, 2500) or `plane`
  (airframe controls, 800; a twin's wings bear 1400).
- Size: land vehicles 2 to 5 tiles each way (`VEHICLE_DRAUGHT_MIN`/`MAX`);
  planes 3 wide and 3 to 5 long, or 5 wide and 4 long, as the airframe
  assembly allows (`aircraft_assembly.dm`).
- Engine: one of the engine maker's kinds (`vehicle_draught_engines`) and a
  size in cc within its limits. Its power is `initial(maxpower) * cc / 1000`.
- Tiles `"col,row"` (column 1 the vehicle's left, row 1 its front): a frame
  (`s` steel, `w` wood, `a` airframe section), a mover under it (`W` wheel, `K`
  track) and one part on it (`E` engine, `Y M T X` fuel tanks, `D` driver's or
  pilot's seat, `G L C` crew seats, `U` turret with tank cannon and gunner's
  seat, `H` cargo hold).
- Weight is reckoned the way `frame/total_weight()` weighs an assembled
  vehicle: 5, plus the axis, plus 10 and each object's `w_class * 2` on each
  frame, plus 40 for each seated crewman. Fitted wheels lie inside their
  frames and weigh nothing.

Design code: `C13CAR/1/<name>/<axis>/<engine>/<cc>/<width>/<length>/<col,row,frame,mover,part>;...`
with `-` for none (`DESIGN_CODE_CAR_MAX`).

## Checks

Kind `vehicle_sheet` (`vehicle_draught_checks.dm`, framework in
[design-checks.md](design-checks.md)): errors for an unfilled rectangle, no
engine, no fuel tank, no driver's seat, a bare corner, a weight the axis or
engine cannot move, a turret on a plane; warnings for extra engines, tanks or
seats, wheels off the corners, a pilot out of the wing row, tracks on a plane,
a crew that would stall it, a turret on wood; notes for fuel, mixed wheels and
tracks, a turret with no loader and cargo capacity. The part book covers every
axis, frame, mover, part and engine key plus the eraser.

## Building and drawing

- Using a vehicle sheet on a loose axis of the sheet's kind clips its code to
  the axis (`vehicle_sheet_code`, saved). The axis's survey report then
  compares the frames laid around it with the sheet in each facing whose
  rectangle matches and lists what the best one still lacks; "Assemble it"
  offers that facing first. "Unclip the sheet" removes it.
- "Draw its lines" at an assembled land vehicle's or plane's axis, with a
  blank sheet of paper in hand, draws it on a new sheet
  (`vehicle_draught_survey()`).

## In a workshop

`code/modules/craft/vehicle_sheet_works.dm`: using a vehicle sheet on a press
builds it from the press's stock. The automobile workshop takes `car` and
`heavy` sheets and the aircraft hangar `plane` sheets (`sheet_axes()`); the
shipyard office, submarine pen, rover bay and private workshop take none.

- The press refuses a sheet whose `vehicle_sheet` checks report an error, one
  of another axis (naming the right press), one it lacks research for
  (Mechanized Warfare for a turret or tracks, Aviation & Rocketry for a
  twin's wings), a piece-by-piece project in the bay, a bay that is not
  clear, or stock it lacks (`sheet_refusal()`).
- Cost (`sheet_costs()`): the sheet's `costs()`, with the corner wheels taken
  from the wheel stock in place of their steel, no cost for movers off the
  corners (they are not made), and 10 cable. A sheet press holds up to 1000
  steel (`stock_cap()`); every press holds at least enough for its dearest
  model.
- It needs the `max(width, length)` square northeast of the press clear and
  builds the vehicle front to the north, its front left corner on the
  square's north-west tile, then assembles it as a hand builder would
  (`assemble()`), with empty tanks and a key. It draws 20 power for the
  usual assembly time.

The aircraft hangar also builds the UH-1 helicopter (`"Helicopter"`, Rocketry,
a 7x7 square) from `aircraft_huey_layout`.

Test: `tests/vehicle_papers/sheet_works_probe.dm`.

## The window

`code/modules/craft/vehicle_designer.dm`: "Draw a vehicle on the sheet" on a
blank draught, or "Draw on the sheet" on a vehicle sheet. The page is
`vehicle_designer_page()` with its data at `@@DATA@@` (contract in the file
header); every change is sent as a code and answered with `carStats`,
`carChecks` and `carStatus`.

Tests: `tests/vehicle_papers/sheet_probe.dm`, `tests/vehicle_papers/sheet_works_probe.dm`, `tests/ship_draught/test_design_checks.py`.
