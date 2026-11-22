# Train sheets

A ship's draught (`/obj/item/ship_draught`) can carry a whole train: kind
`TRAIN` in `draught_kinds` (`code/modules/naval/draught_kinds.dm`), datum
`/datum/train_draught` in `code/modules/1713/train_draught.dm`. A rail works
(`code/modules/1713/train_works.dm`) builds it on its track and couples it up.

## The sheet

- Cars in order from the front, at most `TRAIN_DRAUGHT_MAX_CARS` (16) and
  `TRAIN_DRAUGHT_MAX_TILES` (120) tiles in all (`code/__defines/naval.dm`).
- A car is a stock kind or a drawn car. Stock kinds are every car and
  locomotive a kit builds (`train_draught_stock()`): the key is its
  `train_car_layout()` kind, and the cost is its kit's recipe in
  `config/crafting/material_recipes_global.txt`. Research is the kit's node.
- A drawn car is three tiles wide and four (four-wheel, a platform car kit's
  frame: 12 iron) or eight (bogie, a bogie flatcar kit's frame: 22 iron)
  long. It has a floor (`train_draught_floors()`), an optional roof
  (`train_draught_roofs()`), a side piece along the outer edge of each side
  tile, an end piece across each of the three tiles at its front and back
  (`train_draught_edges()`) and a fitting on each tile
  (`train_draught_fittings()`). Each part adds its cost; armor plate needs the
  armored wagon's research, and a fitting with a mapped recipe needs that
  recipe's node.
- A drawn car with insulated sides keeps an ice bunker's ice like an ice car
  (`train_car_insulated()` in `train_stock.dm`).

A drawn car's kind string is its whole layout, so a built car keeps it as its
saved `car_kind`; `train_car_layout()` reads it (`train_custom_layout()`,
cached per string). Kits, the rail warehouse, saves and the transfer codec
carry it like any stock kind:

    c:<length>:<floor>:<roof>:<front>:<back>:<section>,...:<name>

`roof` is a roof key or `.`; `front` and `back` are three edge keys (left,
middle, right); each section is five keys from the front: the left and right
side edges, then the fittings on the left, middle (rail) and right tiles. `.`
is none. The name uses `_` for spaces and leaves out `/ ; , : _`.

Design code: `C13TRAIN/1/<name>/<car>;<car>;...` (`DESIGN_CODE_TRAIN_MAX`).

## Checks

Kind `train_sheet` (`train_draught_checks.dm`, framework in
[design-checks.md](design-checks.md)); cells are car numbers from the front.
Errors: no cars, too many cars, too many tiles. Warnings: no locomotive, a
tender not next to a steam engine, a main-line steam engine without a tender
next to it, a drawn car with no way in, a drawn car blocked down its middle,
cold lockers with no ice bunker. Notes: the track length the works needs,
several engines, electric engines, a long train with no brake van or brake
wheel, an ice bunker without insulated sides, seats under no roof, a galley
stove or sink. The part book covers every stock kind, `custom`, the eraser
`x` and `floor_`, `roof_`, `edge_` and `fit_` plus each table key.

## The rail works

`/obj/structure/rail_works` (30 iron, Rail & Steam). Build it facing the track
with one tile between it and the rails. Its stock takes iron, steel, wood,
glass and cloth (1500 each, 400 cloth). Using a train sheet on it refuses a
sheet whose checks fail, research the builder lacks and missing stock, then
asks which way along the track the train should head. It refuses track that
is not straight and clear for the whole train: the front car stands on the
rail tile in front of the works and the rest runs back behind it, with a
clear tile either side all along. After the work it assembles each car from
a kit in order, furnished, couples each to the one in front
(`join_trains()`), and spends the stock only once every car stands.

"Draw the train on the track", with a blank sheet of paper in hand, draws the
train standing on the track in front of the works (or up to six tiles along
it) onto a new sheet (`train_draught_survey()`). One-tile wagons and engines
are left off.

## The window

`code/modules/1713/train_designer.dm`: "Draw a train on the sheet" on a blank
draught, or "Draw on the sheet" on a train sheet.

Tests: `tests/train_draught/probe.dm` (native),
`tests/train_draught/test_train_sheet.py`.
