# Vending machines across a world save/load

`python3 tests/vending_load/run.py --byond-bin <BYOND bin>` compiles the production
game with normal startup disabled and runs Save_World, ClearMap and Load_World on
a 6x4x1 world with a stocked rifle rack and a vendor that builds its own products.

A load constructs saved `/datum/data/vending_product` records without arguments;
the record constructor must not create an item from a null path, the record's
listing image is rebuilt after load, and a loaded vendor must not build its
inventory a second time. The rack takes an ordinary held stack of five planks,
refuses a held item that can't be released, then returns the actual five-plank
stack after load. A second Take with the original row key leaves the next item
alone. An apparel rack credits the exact rolled-sleeve uniform when returned.

`--negative-control argless-product` removes the constructor guard and must fail
with the import error Gaia hit on 2026-11-05.

A market stall in the same world lists a single item and a stack through
`add_product`, holds an unpaid purchase until money is deposited, and keeps its
listings, prices and stocked item across the save/load.
`--negative-control pending-payment` stops the stall remembering the waiting
purchase and must fail.
