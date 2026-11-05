# Ammunition across a world save/load

`python3 tests/ammo_casing_load/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and runs Save_World, ClearMap and
Load_World on a 6x4x1 world with a filled magazine, a loose loaded round, a
spent casing, an AP round, a fire arrow and two rounds written in the older
save shape.

Projectiles are never saved (`should_save = 0`), so a casing's `BB` reference
restored as null and every loaded round came back spent (Gaia, 2026-11-05).
Saves now record `saved_bullet_type` and the import rebuilds the bullet; older
saves wrote a `BB` field only while a round was loaded, so its presence alone
marks the round as live.

`--negative-control no-import-rebuild` removes the casing import hook and must
fail.
