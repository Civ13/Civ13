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

## How gunwales behave

- Part of her hull: `hull_load()` is 0, they move with her like anything on
  deck, and shots fly over them like any railing.
- They cross the sea in her record as `"r"` entries (type and facing), not as
  cargo, so they do not count toward the crossing's cargo limit.
- People climb over a gunwale like a railing. Climbing over into open water
  asks first.

## Tests

`tests/naval_carrier/draught_probe.dm` ("Her sides"): draught gunwale sides
and costs, the slipway gunwale stages and markers, a launched boat with no open
side, the crossing entry, the refit refusal and `hull_rail_sides_free`.
