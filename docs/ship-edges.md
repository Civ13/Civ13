# Ship edges: gunwales and closed sides

A boat or ship has a defined edge. Every side of a deck tile that is not
joined to another deck tile is open until something closes it:

- a gunwale (wood) or bulwark (steel) along it, or any other built railing
  or railing gate;
- a wall, window or door standing on that tile, which closes all of its sides.

Code: `code/modules/naval/hull_sides.dm`.

## Who needs closed sides

- Small craft (up to `HULL_SMALL_MAX_TILES`, 12 tiles) are left open.
- A boat or ship is not commissioned from her tiller, or refitted, while any
  side is open. `hull_sides_refusal(deck)` gives the reason and marks the open
  sides on deck for a few seconds (`/obj/effect/vessel_path/open_side`).
- A hull already afloat keeps sailing with open sides until it is refitted.
  The tiller's status counts them.
- `tiller.commission()` itself does not check: the slipway, the sea crossing
  and the probes call it directly. Only the player paths (the commission menu
  and Refit) refuse.

## Fitting gunwales

- Craft them like railings (railings group): a wooden gunwale costs 2 soft
  wood (Primitive Construction), a steel bulwark 2 steel (Steelmaking).
- At the tiller, "Rail her sides" fits one on every open side from the stack
  in hand, 2 a side, about a second each: gunwales from wood on plank deck,
  bulwarks from steel on steel deck (`hull_gunwale_for`).
- Slipway schooners and freighters come off the ways railed for nothing
  (`hull_rail_sides_free`).
- A ship's draught with more than 12 tiles gets gunwales on every open side
  as drawn (`/datum/ship_draught/proc/gunwale_sides`). They are in her cost
  and the slipway builds them as the last stages, after her fittings.

## On the draught and in the designer

- Gunwales are not drawn: `gunwale_sides()` puts one on every open side of a
  draught of more than 12 tiles. The design code is unchanged (`C13SHIP/1`).
- Piece `Y` is a gangway (4 wood). Draw it on an edge tile facing out over
  the side; it closes that side instead of a gunwale, and `problems()` refuses
  one that faces her own deck. On the slipway it is built with her fittings.
  "Draw her lines" draws a wooden or steel gangway as `Y`.
- The designer window draws her gunwale rim in gold inside the hull outline
  (gaps where a wall, door, window or gangway closes the side) and lists the
  gunwale count under "Sides" in her figures (`summary_data()["gunwales"]`).
  The palette shows the gangway under "Sides".
- Ship edges pieces: `Y` gangway, `N` crow's nest mast, `J` bowsprit,
  `F` figurehead.

## How gunwales behave

- Part of her hull: `hull_load()` is 0, they move with her like anything on
  deck, and shots fly over them like any railing.
- They cross the sea in her record as `"r"` entries (type and facing), not as
  cargo, so they do not count toward the crossing's cargo limit.
- People climb over a gunwale like a railing. Climbing over into open water
  asks first.

## Gangways and the gangplank

Code: `code/modules/naval/hull_gangway.dm`.

- A wooden gangway (4 soft wood) or steel gangway (4 steel) is a gate in her
  gunwale: it closes her side like a railing and opens like any railing gate.
- Alt-click it (or use its "Run out or take in the gangplank" verb) to run a
  plank across up to 3 tiles of open water to a pier, the shore or another
  ship (`hull_gangplank_plan`). She must be stopped. A ship lying right
  alongside needs no plank.
- A gangway on her upper deck (on open air, `building_open_turf()`) runs the
  plank over open air instead, to a quay or pier floor on that level, so she
  can be boarded from a level up. The gangway's ship is found with
  `craft_holding()`, which knows her decks above and her hold.
- Gangplank tiles are `/obj/covers/repairedfloor/rope/boarding/gangplank`:
  boarding-line floors, so `hull_floor_in` ignores them and she never becomes
  a jetty. They are not saved.
- While a plank is out, `craft.gangplank_refusal()` stops the tiller's
  sailing orders (speeds, turns, berth, refit, leaving these waters, voyages)
  and her body is held. A broken plank brings the rest in, and a plank whose
  gangway has moved away falls in at the next check.

## Going aloft and the crow's nest

Code: `code/modules/naval/hull_masts.dm`, hooked from the mast's
`attack_hand`, `attackby` and `examine` in `hull_rigging.dm`.

- Grab intent with a free hand on a mast (or its "Climb the Mast" verb) climbs
  it in 4 seconds (`hull_wait`, so a hull under way does not spoil it). The
  shared tree climbing code does the rest: `climbed_tree` is the mast, the
  climber is posed at the masthead, `los_up_tree` gives the raised eye, and a
  movement key, grabbing again or Climb Down comes down; a stun or the mast
  going is a fall.
- Someone aloft adds to her lookout (`craft.aloft_reach()`, added in
  `lookout_range()` and `sights()`): 4 tiles from a bare masthead, 8 from a
  crow's nest. Look into Distance reaches 8 or 11 tiles.
- A crow's nest is fitted with 8 wood used on the mast (`fit_crows_nest`). On
  a draught it is piece `N` (`/obj/structure/vehicleparts/movement/sail/crows_nest`,
  23 wood), which drives her like a mast (`mast_count()`).
- The crow's nest gives the view boost on every map. A platform on the level
  above, where a world has one, is not built.
- A nest fitted by hand to a plain mast is not kept across a sea crossing; a
  drawn `N` mast is.

## Her bow: bowsprit, jib and figurehead

Code: `code/modules/naval/hull_bow.dm`.

- A bowsprit (10 wood, vehicle parts, Wagons & Ships) is a sail subtype: rig
  a sail on it for a jib, set, reefed and furled like any sail. Its drive
  (`/datum/craft_drive/fitted/sail/jib`) has half a mast's thrust and is ready
  only while no deck of hers lies ahead of it along her heading. It is not
  climbed and takes no crow's nest.
- A figurehead (6 wood, vehicle parts) is cosmetic. The first click with an
  empty hand carves it as one of `figurehead_carvings`.
- Draught pieces `J` (bowsprit) and `F` (figurehead, turns).
  `sail_push()` counts a jib as half a mast; the design check
  `/datum/design_check/ship/bowsprits` warns of a bowsprit with deck ahead of
  it on the sheet.

## Grapnels thrown by hand

Code: `code/modules/naval/hull_grapnel.dm`, joining `craft_grapple.dm`.

- A grapnel (3 iron, vehicle parts, Iron Smithing) is thrown by clicking
  another ship's deck or rail within 5 tiles while standing on her deck. After
  a 1.5 s swing it catches 60 times in 100; a miss is hauled back.
- A catch throws her lines as from the helm (`order_grapple(other, TRUE)`,
  which skips the helm's coiling cooldown), or holds on the lines already
  joining the two ships, from either side.
- Several hooks hold harder: `craft_grapple.cut_time()` is 5 s plus 3 s for
  every hook, for cutting at the helm or at a line. The thrower still casts
  off at once.
- The hooks ride in `craft_grapple.hooks` and drop on `home` (her deck tile the
  lines run from) when the lines part. Like the lines, nothing is saved.

## Sprites

`tests/sprites/create_ship_edges.py` draws them all (`--check` verifies the
committed sheets, `--preview <png>` writes a review sheet):

- `icons/obj/ship_edges.dmi`: `gunwale` and `bulwark` with their `_gate` and
  `_gate_open` gangway states (the `railing_style` of each type, four
  directions like `railings_built.dmi`), the uncarved `figurehead` and
  `figurehead_bear`, `_wolf`, `_goose`, `_monkey`, `_serpent`, `_ram` and
  `_face` (four directions), and the `grapnel`.
- `icons/mob/items/lefthand_ship_edges.dmi` and `righthand_ship_edges.dmi`:
  the held `grapnel`.
- `icons/obj/vehicles/ship_bowsprit.dmi`: the mast's `sail0`, `sail1` and
  `sail2` as a bare spar, a furled jib and a set jib. The dir is the way the
  spar points. The cell is 96x96 with her own tile in the middle, and the
  type's `pixel_x` and `pixel_y` of -32 centre it, so the spar stands 28
  pixels out over the next tile in every direction. A turning hull turns
  her dir and does not touch a structure's pixel offsets (only loose items
  are swung, in `/obj/item/craft_turned`).
- `icons/obj/vehicles/ship_mast_nest.dmi`: the mast's three states with a
  crow's nest at the masthead. The mast's `update_icon()` picks this file
  while `crows_nest` is set.

## Tests

`tests/naval_carrier/draught_probe.dm` ("Her sides"): draught gunwale sides
and costs, the slipway gunwale stages and markers, a launched boat with no open
side, the crossing entry, the refit refusal, `hull_rail_sides_free`, and the
gangway: plank plan, stopped-only, the hold, taking it in and a broken plank.

`tests/naval_carrier/chart_probe.dm` ("Grapnels thrown by hand"): refusals,
hooks adding to the lines from both ships, the cut time, hooks coming back
when the lines part, and a hook throwing lines during the helm's cooldown.
