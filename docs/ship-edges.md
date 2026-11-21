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
- Letters reserved: `N` crow's nest, `J` bowsprit and jib, `F` figurehead
  (ship edges); `L` ladder and `Z` stairs (multi-deck, which takes
  `C13SHIP/2`).

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
- Gangplank tiles are `/obj/covers/repairedfloor/rope/boarding/gangplank`:
  boarding-line floors, so `hull_floor_in` ignores them and she never becomes
  a jetty. They are not saved.
- While a plank is out, `craft.gangplank_refusal()` stops the tiller's
  sailing orders (speeds, turns, berth, refit, leaving these waters, voyages)
  and her body is held. A broken plank brings the rest in, and a plank whose
  gangway has moved away falls in at the next check.

## Tests

`tests/naval_carrier/draught_probe.dm` ("Her sides"): draught gunwale sides
and costs, the slipway gunwale stages and markers, a launched boat with no open
side, the crossing entry, the refit refusal, `hull_rail_sides_free`, and the
gangway: plank plan, stopped-only, the hold, taking it in and a broken plank.
