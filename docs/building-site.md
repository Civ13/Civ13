# Building site: cement mixer and concrete

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
