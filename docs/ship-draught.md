# Ship's draughts

A ship's draught is a ship drawn on paper before she is built. It is the
heart of the freeform ship designer: players draw one in a window, build it
on a slipway and launch her as a built hull.

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

## The designer window

`code/modules/naval/ship_designer.dm`. A blank **ship's draught** is a hand
recipe (1 wood, paper & printing, Papermaking, beside the blank map). Hold it
with a pen, pencil or pigment in either hand and choose **Draw on the sheet**.

The window (1060x780, the brown and gold of Character Setup) is one page,
`ship_designer_page()`, and one block of JSON, so its palette is built from
`ship_draught_floors` and `ship_draught_pieces`:

- `PIECES`: `[key, name, turns, palette group, helm]`. The group is the
  heading a piece is drawn under (`ship_designer_groups`; a piece in none goes
  under "Other"). A helm cannot be drag-painted.
- `FLOORS`: `[key, name]`.

The sheet is a parchment view onto the 40x40 grid, bow up, with BOW, STERN,
PORT and STARBOARD on its edges and a dashed line down the middle column.
**Fit ship** shows her at up to full sprite size (32 px a tile), **Whole
sheet** all forty tiles; the wheel and the + and - buttons zoom, the middle
button drags the sheet. A click is turned into a tile from the canvas's own
rectangle and the view, never from a fixed tile size, so the drawing lands
under the pointer however the window is sized.

Tools: every floor, deck above (right-click takes it off), erase, every piece
with a facing (the arrows or R), freehand or box, a port/starboard mirror
about the middle column, undo and redo (Ctrl+Z, Ctrl+Y), clear, and the
ready-made draughts in `ship_draught_examples()` (rowing galley, sloop, steel
cutter). The tile under the pointer shows a ghost of what a click will lay,
mirrored when the mirror is on, and a line under the sheet names what is on
it. The hull is edged in ink and a deck above is hatched in gold.

Floors and pieces are drawn as pictures on the grid and on the palette; a
gold arrow marks the facing of a piece that turns. The pictures are PNGs
under `icons/ship_designer/`, made by
`python3 scripts/build_ship_designer_icons.py` (`--check` reports stale ones)
and sent to the window with `browse_rsc` as `shipd_*.png`
(`ship_designer_sprites`). Most are cut from the game's DMIs; a fitting that
stands on a floor gets a one-pixel ink outline so it reads on planks and
steel alike. The ship mast and the steering oar are plan views placed pixel
by pixel in that script, because their game sprites say nothing at one tile.
Rerun the script and add the new names to the list when a floor or piece is
added. A picture that fails to load falls back to the flat floor colour or
the piece's letter.

The window never reckons anything itself. About half a second after each
change it sends the drawing as a `C13SHIP` code in parts of 900 characters
(`ship=begin/part/end`, each part acknowledged like the painting editor); the
server parses it with `ship_draught_from_code()` and answers with
`summary_data()` as JSON (`shipStats`): the same figures as `summary_text()`,
which the **Her figures** panel lays out as size against the tile cap, decks,
cost, speed, ballast and a green or orange note on whether she can be built.
Summaries are limited to one per 0.3 s per sheet. **Save to the sheet**
stores the drawing (finished or not) on the item and answers `shipSaved`,
which clears the window's "Unsaved changes" mark. The server re-checks the
drawer is holding the sheet and a pen on every part.

## Building on the slipway

`code/modules/naval/slipway_draught.dm`. Use a drawn ship's draught on an
empty slipway post. The draught must pass `problems()` and the berth must be
open ground, trench or water with nothing solid on it, no floor already laid
and no other berth across it. Her stern row goes on the tile in front of the
post, her middle column on the post's line, and her bow runs the way the post
faces (`slipway_draught_turn()`, the inverse of `ship_draught_bow_up()`).

The post keeps the draught as `draught_code` beside the usual `design`
(her name), `pieces_done` and `paid`. `slipway_draught_plan()` makes the
piece plan: one piece per floor tile from stern to bow (plank floors, then
steel), then one per fitting, a stage per kind in `ship_draught_pieces` order.
Each piece costs its hand recipe; the deck above is not built on the slipway
and is laid by hand once she is afloat. Iron and planks pay for pieces as well
as the usual materials (`piece_material()`).

When a piece is paid for, the real floor or fitting appears on its tile with
its facing turned to the berth (`draught_place()`). Tiles still to build show
a `slipway_frame`: the cradle where the floor goes, then a faint picture of the
fitting still to stand there. Frames are rebuilt from the code after a load;
what is already built saves as ordinary objects. Several shipwrights can work
at once, each fitting the next piece in turn, and a worker keeps going while
the stack in hand pays (`add_draught_piece()`). Giving her up takes the
draught off the post and leaves what is built.

## Launching her

`launch_draught()`. Laying a draught out already needs water ahead:
`draught_landing()` finds the first slide, at most her length plus 12 tiles
along the post's facing, that puts every berth tile on water with no floor,
ship or solid thing there and no other floor alongside (she must float free).
When she is finished, the post offers the launch. The tiles she slides over
must be clear, a dry dock must be flooded, and her helm must still stand where
the draught puts it. Her floored tiles are adopted by a temporary built body
and moved in one slide (`move_to` with `slide_time`), carrying everyone and
everything aboard; her tiller then commissions her under the draught's name
with her bow along the ways. The post is cleared.
