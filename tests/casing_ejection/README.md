# Casing ejection and brass heaps

`python3 tests/casing_ejection/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and, on a 40x30x1 world:

- fires a PKM past the heap cap and checks its brass forms one heap of
  `CASINGS_PER_TILE` casings drawing `ITEM_HEAP_VISIBLE_MAX` extras, none stay
  in the belt or gun, and the heap can be handloaded and decays when abandoned;
- throws a live round onto the heap and checks it stays a separate round;
- picks the heap up (one casing comes away, the rest stay a heap), refuses to
  load a heap as one round, and gathers a heap into a casing stack in part and
  in full;
- checks a tank shell leaves a cannon casing of its calibre, a field shell an
  artillery casing, and mortar bombs, cannonballs and naval shells nothing;
- then measures 6000 casings over 500 tiles in two more processes (RSS never
  shrinks): `-params measure=loose`, the old one object per casing, and
  `measure=heap`. 2026-11-21, 516.1688 Linux: loose 6000 objects, 8472 KB,
  6000 abandonment entries; heap 500 objects, 280 KB, 500 entries.

Negative controls, each must fail: `--negative-control no-ejection` (casings
are not dropped), `no-tile-cap` (heaps grow past the cap) and `no-heap`
(every casing stays its own object).

Heaps are generic (`code/game/objects/items/item_heaps.dm`): a type opts in
with `heap_matches()` and `heap_copy()`. `tests/ammo_casing_load` checks a heap
keeps its count and overlays across save/load. `test_sources.py` is the
offline check CI runs.
