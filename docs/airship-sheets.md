# Airship sheets

A ship's draught (`/obj/item/ship_draught`) can carry a crewed airship
(`code/modules/naval/air_hull.dm`): kind `AIR` in `draught_kinds`
(`code/modules/naval/draught_kinds.dm`), datum `/datum/air_draught` in
`code/modules/naval/air_draught.dm`.

## The sheet

- Size: 2 to 12 tiles each way (`AIR_DRAUGHT_MIN`/`MAX`), with at most 60 deck
  tiles (`AIR_DRAUGHT_MAX_DECK`, the helm's survey limit).
- Engine: one of the engine maker's kinds (`vehicle_draught_engines`) and a
  size in cc; every engine drawn on her is that engine.
- Crew: how many people she is drawn to carry, 0 to 60. Each weighs 1.
- Tiles `"col,row"` (column 1 her port side, row 1 her bow): a deck (`p`
  airship planks, `a` aluminium frame, `s` steel frame), a gas cell over it
  (`c` cloth, `r` rubberised, `k` goldbeater's skin) and one part on it (`W`
  helm, `E` engine, `Y M T X` fuel tanks, `B` bomb hatch). A tile with no deck
  is open air.
- Weight is the decks' `air_weight` plus the crew; lift is the cells'
  `max_lift` full of hydrogen. Tables are procs (`air_draught_decks()` and
  so on), not global lists: the world's global initialiser is at BYOND's size
  limit for one procedure.

Design code: `C13AIR/1/<name>/<engine>/<cc>/<crew>/<width>/<length>/<col,row,deck,cell,part>;...`
with only deck tiles written and `-` for no cell or part (`DESIGN_CODE_AIR_MAX`).

## Checks

Kind `air_sheet` (`air_draught_checks.dm`, framework in
[design-checks.md](design-checks.md)): errors for no deck, too many deck tiles,
a deck in pieces, no helm, no gas cells, a deck too heavy to lift and a crew
too heavy to lift; warnings for extra helms, a thin lift margin, engines
without tanks, tanks without engines and engines too weak for half ahead;
notes for empty cells, slow ahead only, full ahead, fuel, wooden decks under
engines and bomb hatches. The part book covers every deck, cell, part and
engine key plus the eraser.

## The airship yard

`code/modules/naval/airship_yard.dm`: `/obj/structure/car_workshop/airship_yard`
(Lighter-than-Air Flight, 40 wood, production). Its stock also takes plastic
or rubber sheets (`plastic`) and sausage casings (`casings`). Using an airship
sheet on it refuses a sheet whose checks fail, research it lacks (Powered
Flight for metal decks and bomb hatches, the Combustion Engine for engines and
tanks), ground that is not clear and level under every deck tile northeast of
the yard, and missing stock. Otherwise, after the usual assembly time and 20
power, it lays her bow to the north (sheet tile `(col, row)` on
`(x + col, y + length - row + 1)`), hangs her cells empty, sets up the first
helm facing north, makes each engine at the sheet's size and connects it to
the nearest unused tank, commissions her under the sheet's name and holds her
in place.

## Drawing her lines

"Draw her lines" at a commissioned airship's helm, with a blank sheet of paper
in hand, draws her on a new sheet bow to the helm's facing
(`air_draught_survey()`).

## The window

`code/modules/naval/air_designer.dm`: "Draw an airship on the sheet" on a blank
draught, or "Draw on the sheet" on an airship sheet.

Tests: `tests/airship_sheets/probe.dm`, `tests/ship_draught/test_design_checks.py`.
