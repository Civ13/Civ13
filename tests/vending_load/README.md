# Vending machines across a world save/load

`python3 tests/vending_load/run.py --byond-bin <BYOND bin>` compiles the production
game with normal startup disabled and runs Save_World, ClearMap and Load_World on
a 6x4x1 world with a stocked rifle rack and a vendor that builds its own products.

A load constructs saved `/datum/data/vending_product` records without arguments;
the record constructor must not create an item from a null path, the record's
listing image is rebuilt after load, and a loaded vendor must not build its
inventory a second time.

`--negative-control argless-product` removes the constructor guard and must fail
with the import error Gaia hit on 2026-11-05.
