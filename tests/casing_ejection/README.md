# Casing ejection

`python3 tests/casing_ejection/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and, on a 6x4x1 world:

- fires a PKM past the per-tile cap and checks that `CASINGS_PER_TILE` spent
  casings lie on its tile, none stay in the belt or gun, and the brass can be
  handloaded and decays when abandoned;
- throws a live round onto the full tile and checks it is kept;
- checks a tank shell leaves a cannon casing of its calibre, a field shell an
  artillery casing, and mortar bombs, cannonballs and naval shells nothing.

Self-loading guns (`EJECT_CASINGS`) had ejection compiled out by an old
`DISABLE_CASINGS` define, so their fired casings stayed inside the magazine or
gun and in the abandoned-item list forever.

Negative controls, each must fail: `--negative-control no-ejection` (casings
are not dropped) and `no-tile-cap` (the per-tile cap is lifted).

`test_sources.py` is the offline check CI runs.
