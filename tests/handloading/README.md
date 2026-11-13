# Handloading and spent brass

`python3 tests/handloading/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and, on a 6x4x1 world, checks the
handloading table in `code/modules/projectiles/handloading.dm`:

- every row spawns a loaded round of its own caliber and names a real research node;
- powder is poured only up to what the casings need, and bullets only go into
  casings that already hold their powder;
- splitting and merging a charged casing stack carries whole sets, so nothing
  is lost or made;
- loading pays for exactly the ready sets, rifle brass cannot load a pistol
  cartridge, and AP rounds come out AP;
- only loose, fired brass of the stack's size is gathered from a tile; live
  rounds, heavy machine-gun brass and rounds inside a box stay.

Negative controls, each must fail: `--negative-control no-charge-carry`
(split stacks lose their charge), `bullets-without-powder` (bullets seat into
empty casings) and `loose-live-brass` (live rounds count as brass).

`python3 -m unittest tests/handloading/test_coverage.py` is the offline suite:
every modern caliber in `docs/firearm-coverage.json` must have a handloading row
or a stated reason in its `EXCLUDED` list.
