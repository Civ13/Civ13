# Building site: cement mixer, concrete and the pile driver

`code/modules/1713/building_site.dm`, sprites `icons/obj/building_site.dmi`
(drawn by `tests/sprites/create_building_site.py`), suite `tests/building_site`.

## Concrete is mixed, not dug

`/material/concrete` now has a stack, the concrete block
(`/obj/item/stack/material/concrete`). In `material_recipes_global.txt` the
concrete floor (1), concrete roof builder (1), concrete pillar (2) and
concrete bridge span (6) are built from concrete blocks; they used to be
shaped from raw clay. The other recipe files are untouched. Cement bricks keep
their clay and quicklime route at the brick mould bench.

## Cement mixer

8 iron, Reinforced Concrete. A hand-cranked drum on a cart.

- Use quicklime, sand or stone blocks on it to load the drum (20 of each).
- Crank it with an empty hand. Every 4 seconds, 1 quicklime, 2 sand and 2
  stone turn out 4 concrete blocks beside the mixer; it keeps turning until
  the drum runs short or the worker steps away.
- The batch is only paid for after the wait re-checks the worker, the drum
  and the research. Mixing is refused during saves.
- Wrench to unfasten, hammer on harm intent to dismantle; the charge in the
  drum drops out. As a workshop machine it needs a hoist to change levels.

## Pile driver and timber piers

Pile driver: 14 wood, Imperial Architecture. Timber pier span: 8 wood,
Imperial Architecture.

- The timber pier span is a `/obj/item/weapon/bridge_span` subtype, so it is
  laid, checked and taken apart by the same code as the steel and concrete
  spans in `code/modules/1713/bridges.dm`: water only, from firm footing, and roads or railway track can go on the deck.
- It is refused on `/turf/floor/beach/water/deep` (Val, 2026-11-14): deep
  water stays for steel and concrete spans.
- Its `build_span()` then asks `pile_driver_for(T)` for a fastened, idle pile
  driver within 2 tiles of the water tile, standing on the shore, in the
  shallows or on a deck. Without one the span is refused. The driver shows its
  hammer loop and is busy while the span goes down.
- The deck (`/obj/covers/bridge/timber`) is weaker than steel or concrete
  (200 health). Taking it apart with a hammer returns the span.
- To carry a pier further out, unfasten the driver, pull it onto the new deck
  and fasten it again.
