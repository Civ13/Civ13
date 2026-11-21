# Ship's draughts

A ship's draught is a ship drawn on paper before she is built. It is the
first part of the freeform ship designer: later parts add a drawing window,
building a draught on a slipway and launching her as a built hull.

Code: `code/modules/naval/ship_draught.dm`. Limits: `code/__defines/naval.dm`.

## What a draught holds

`/datum/ship_draught` keeps `cells`, keyed `"x,y"` on a sheet of
`SHIP_DRAUGHT_SIDE` tiles each way, bow to the top (north). Each cell is
`list(floor, piece, piece dir, upper deck)`:

- floor: `ship_draught_floors` (`w` plank floor, `s` steel floor);
- piece: `ship_draught_pieces` (tiller, steering oar, mast, rowing bench,
  killick, iron anchor, hand bilge pump, plank wall, door, window, crate, bed)
  or null;
- upper deck: TRUE when the tile carries deck on the level above.

## Checks, cost and speed

`problems()` makes the same checks a tiller makes when she is commissioned:
floors joined edge to edge, one helm, at most `SHIP_DRAUGHT_MAX_TILES` tiles of
hull and `SHIP_DRAUGHT_MAX_DECK` tiles of deck in all. `buildable()` is TRUE
when there are none.

`costs()` adds up the hand recipe of every floor and piece; a tile of upper
deck costs a floor. `tests/ship_draught` holds those costs to
`config/crafting/material_recipes_global.txt`.

`load()`, `mass()`, `sail_step()`, `oar_step()`, `best_step()` and
`wants_ballast()` use the figures afloat: each piece weighs its `hull_load()`
(the probe checks every piece), burden and ballast are hull_load.dm's, and
pushes are `CRAFT_SAIL_THRUST` (a mast on a reach) and `CRAFT_OAR_THRUST` (a
manned bench). The estimate is for an empty ship; cargo, crew and bilge water
make her slower.

## Codes and the sheet

`to_code()` and `ship_draught_from_code()` read and write
`C13SHIP/1/<name>/<x,y,floor,piece,dir,upper>;...` through `design_codes.dm`.
Coordinates start at 0; `-` is no piece.

`/obj/item/ship_draught` keeps its draught as `draught_code` (one saved text
var). Use it in hand to copy its code or paste one in; examine shows the
summary.

## Drawing her lines

At a commissioned tiller, "Draw her lines" turns a blank sheet of paper in
hand into her draught (`ship_draught_survey()`): each hull tile with its floor
(steel plating or planks), the first piece standing on it, its facing turned
bow up, and whether it has deck above. Other tillers aboard are left off.
A tile whose only cover is a wall is drawn as a plank floor with a plank wall.

Probe: `tests/naval_carrier/draught_probe.dm`
(`python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/draught_probe.dm`).
