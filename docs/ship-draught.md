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
  killick, iron anchor, hand bilge pump, plank wall, door, window, crate, bed,
  steam bilge pump, sump pump, steam engine, wooden cannon, cannon, torpedo
  tube, steel window, steel door, ladder) or null. Every piece is something a built
  hull takes aboard and works afloat; a row's `fires` flag marks a gun and
  `drive = "engine"` an engine;
- upper deck: TRUE when the tile carries deck on the level above (the same
  tiles as deck `1` below).

### Decks off her main deck

Her other decks are in `decks`: level text = `list("x,y" = list(piece, dir))`.
`ship_draught_decks` is the table of them: `-1` her hold (steel hold floor, 1
steel a tile), `1` the deck above and `2` a second deck above (plank floor, 2
wood a tile). A hold tile and a deck-above tile stand over a hull tile; a
second-deck tile stands over a deck-above tile (`ship_draught_support()`).
`set_deck(level, x, y, state)` lays or takes up a tile; taking one up takes up
the decks above it there, and `clear()` takes up every deck on a hull tile.
`set_deck_piece()` stands only pieces marked `decks` (walls, doors, windows,
crates, beds, pumps, deck pillars, ladders); masts, helms, benches, anchors, gangways, guns
and engines stand only on her main deck.

The ladder (`X`) is the foot of a stood-up wooden ladder: it goes on the lower
deck under a clear tile of the deck above, where its head stands
(`ladder_leads()`). The deck checks (`/datum/design_check/ship/decks`) refuse a
ladder that leads nowhere and a part of her hold with no ladder up out of it,
and note a part of a deck above that no ladder reaches (stairs or a ladder can
be stood up afloat) and a second deck above (a ship afloat carries one deck
above hers, so it is drawn for later). Findings name the deck they are on.
`piece_count()` counts every deck, so a pump in the hold is her pump.

A deck above is a roof over her hull, so like any roof it must be carried: a
deck pillar (`S`, a roof support) holds deck within 3 tiles of it and a plank
wall the tiles beside it (`carries`, `unsupported_deck_tiles()`); the deck check
refuses a tile of deck above that nothing carries.

## Checks, cost and speed

`problems()` makes the same checks a tiller makes when she is commissioned:
floors joined edge to edge, one helm, at most `SHIP_DRAUGHT_MAX_TILES` tiles of
hull and `SHIP_DRAUGHT_MAX_DECK` tiles of deck in all. `buildable()` is TRUE
when there are none. These are the errors of her design checks
(`check_design()`, [design-checks.md](design-checks.md)), which also warn of
what she can be built with but will not work well: no drive, no pump, no or
too small an anchor, ballast, guns pointing across her deck, fittings crew
cannot reach.

`costs()` adds up the hand recipe of every floor and piece; a tile of another
deck costs its floor, what stands on it costs its recipe, and each side in `gunwale_sides()` costs a gunwale (2 wood,
or 2 steel for a bulwark on steel floor; boats and ships only, see
[ship-edges.md](ship-edges.md)). `tests/ship_draught` holds those costs to
`config/crafting/material_recipes_global.txt`.

`load()`, `mass()`, `sail_step()`, `oar_step()`, `best_step()` and
`wants_ballast()` use the figures afloat: each piece weighs its `hull_load()`
(the probe checks every piece), burden and ballast are hull_load.dm's, and
pushes are `CRAFT_SAIL_THRUST` (a mast on a reach), `CRAFT_OAR_THRUST` (a
manned bench) and an engine's `maxpower` with every fire lit (`engine_push()`,
`engine_step()`). The estimate is for an empty ship; cargo, crew and bilge water
make her slower.

## Codes and the sheet

`to_code()` and `ship_draught_from_code()` read and write
`C13SHIP/1/<name>/<x,y,floor,piece,dir,upper>;...` through `design_codes.dm`.
Coordinates start at 0; `-` is no piece. A draught with a hold, a second deck
above or anything standing on a deck above writes `C13SHIP/2`: the same tiles,
then `/` and `<level,x,y,piece,dir>;...` for every tile off her main deck,
level by level in the order of her hull tiles. `design_code_fields()` takes the
version to read.

`/obj/item/ship_draught` keeps its draught as `draught_code` (one saved text
var). Use it in hand to copy its code or paste one in; examine shows the
summary.

## Drawing her lines

At a commissioned tiller, "Draw her lines" turns a blank sheet of paper in
hand into her draught (`ship_draught_survey()`): each hull tile with its floor
(steel plating or planks), the first piece standing on it, its facing turned
bow up, her deck above and hold (`upper_deck_cell()`, `lower_deck_cell()`) with
any piece that may stand there, ladders included. Other tillers aboard are left off.
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

The **Deck** buttons over the sheet switch between her hold, main deck, deck
above and second deck above (`levels()`, `lv`). Off the main deck the palette
holds the deck's own tile, erase and the pieces allowed there; the rest of her
shows as a flat wash inside a dashed line (`wash()`), a deck above casts a
shadow, and a gold ring marks the head of each ladder from the deck below. The
key beside the buttons (`deckKey()`) names those marks. A check's tiles light up on their own deck, and pinning one
switches to it.

Tools: every floor, deck above (right-click takes it off), erase, every piece
with a facing (the arrows or R), freehand or box, a port/starboard mirror
about the middle column, undo and redo (Ctrl+Z, Ctrl+Y), clear, and the
ready-made draughts in `ship_draught_examples()` (rowing galley, sloop, steel
cutter, and a merchantman with a hold and a deck above). The tile under the pointer shows a ghost of what a click will lay,
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
steel), then one per fitting, a stage per kind in `ship_draught_pieces` order, then
one per gunwale (wooden gunwales, then steel bulwarks) on a boat or ship.
Each piece costs its hand recipe. Her other decks come last
(`draught_place_deck()`): hold floors dug into the level below the berth
(`hull_hold_lay()`), the deck above as a wooden roof over each hull tile with
its floor on the level above, linked as a building pair, then what stands on
those decks kind by kind, then ladders (foot and head, joined). A second deck
above is drawn for later and not built. `draught_decks_refusal()` refuses a
berth with no rock or deep water under her hold or no open air over her deck
above. At the launch the whole hull slides with her hold and deck above, which
`move_to()` carries like any built hull's (the rock under the berth closes
behind her hold). Iron and planks pay for pieces as well
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

## Kinds of sheet

A ship's draught can carry more than one kind of plan. `draught_kinds`
(`code/modules/naval/draught_kinds.dm`) lists each kind by its design code
prefix with the proc that reads its code and the sheet proc that keeps it:
`SHIP` (`ship_draught_from_code`, `take`) and `SUB`
(`sub_draught_from_code`, `take_sub`). Pasting a code onto a sheet
(`paste_any_code()`) goes through the table, so a later planner (a spaceship,
a rocket, a satellite, a station) is one more row with its own datum and
window. `S.draught()` still returns only a ship, so the slipway never sees a
submarine; it refuses a submarine sheet by name.

## Submarine sheets

`code/modules/naval/sub_draught.dm` and the window in `sub_designer.dm`.
`/datum/sub_draught` keeps `length` (`SUB_DRAUGHT_MIN_LENGTH` to
`SUB_DRAUGHT_MAX_LENGTH`, 4 to 7: the longest boat turns in
`VEHICLE_MAX_TURNING_SQUARE`) and `cells` keyed `"col,row"` like
`submarine_layouts`: column 1 is starboard, row 1 the bow, three columns
(`SUB_DRAUGHT_BEAM`). Each cell is `list(frame, fitting, bow-side wall)`:

- frame: `sub_draught_frames` (`h` pressure hull, `x` lock-out hatch, only in
  side sections between the bow and stern rows);
- fitting: `sub_draught_fittings` (wheel, ballast and periscope station,
  battery bank, air bank, locker, berth) or null; none on the stern row;
- wall: `sub_draught_walls` (`b` bulkhead, `d` watertight door) across the
  section's bow side, or null.

The builder never draws the parts every boat has: the glass bow on row 1, the
hull down both sides (open at a hatch), and the stern row as the engine room
(the outer sections sealed tanks, the diesel and its tank in the middle).
`wall_code()` writes a section's walls in the `set_hull_walls()` format and
`layout()` gives the whole boat as a `submarine_layouts` entry.

`problems()`: one wheel, one station, at least one lock-out hatch, and no
bulkhead right across her without a door. `costs()` is her sections
(`SUB_DRAUGHT_SECTION_STEEL` each), `sub_draught_fixed_cost` (the controls and
the stern fuel tank) and her fittings' hand recipes; `tests/ship_draught`
holds all of them to the recipe file.

Codes: `C13SUB/1/<name>/<length>/<col,row,frame,fitting,wall>;...` with every
section listed and `-` for none. `sub_draught_examples()` are the pen's Scout
and Explorer read from `submarine_layouts`. "Draw her lines" at a boat's
ballast and periscope station reads each hull section's `hull_tile`
(`<class>_<col>_<row>`), walls and fittings back into a sheet
(`sub_draught_survey()`).

The window (`open_sub_designer()`) is a 3-column grid, bow to the top and
starboard on the right, talking to a `/datum/sub_designer` per drawer. Every
change is sent as a code; the server answers with `summary_text()`, and Save
keeps it on the sheet. A fitting is drawn on the grid and on the palette as
its game sprite: PNGs under `icons/sub_designer/`, cut from the game's DMIs by
`python3 scripts/build_sub_designer_icons.py` (`--check` reports stale ones)
and sent with `browse_rsc` as `subd_fit_<key>.png` (`sub_designer_sprites`);
a fitting with no picture shows as its letter. Tests:
`tests/submarine/sheet.dm` in the submarine probe.

### Assembling a submarine from her sheet

Using a sheet on loose submarine controls clips it to them (`sheet_code` on
the axis, saved; refused when the sheet has problems or the boat is already
assembled). `assembly_refusal()` then wants a hull 3 wide and exactly as long
as the sheet, and `assemble()` shapes the sections from `D.layout()` instead of
`submarine_layouts`. Fittings are whatever the crew stood on the sections; the
sheet shows where they go. `hull_layout()` reads `sheet_code` first, so her
turning square (`hull_square()`) and later reshaping follow her plan.

Art: every length has a hull drawn for it by `scripts/draw_submarine_hull.py`,
and `submarine_art_tile()` gives each section its tile row for row: the
Coaster's for 4 rows, the Scout's for 5, the Cruiser's for 6 and the
Explorer's for 7. The Coaster and Cruiser have plain sides; a lock-out hatch
is the `sub_hatch_<column>_deck` and `_roof` states laid over whichever side
section the sheet made a hatch (`hatch_art()`). A 6-row boat still handles as
an Explorer (`hull_class`). A boat built from a sheet is drawn from her sheet
by "Draw her lines", not from her art tiles.

Banks: `battery_capacity()` and `air_capacity()` are half a bank in her hull
plus one bank (`SUB_BATTERY_MAX`, `SUB_AIR_BANK_MAX`) for each battery or air
bank standing in her sections (`fitting_count()`), so the pen's boats with one
of each keep their old figures. Assembly trims a charge above her capacity.
