# Stack outputs on an occupied tile

`new /obj/item/stack/X(loc)` merges its default single item into a matching pile
on that tile and deletes itself before the caller sets `amount`, so finishing
ingots on an anvil next to an existing pile added one ingot and lost the rest.
`spawn_stack(path, loc, amount)` in `code/game/objects/items/stacks/stack_spawn.dm`
makes the stack with its full amount, tops up matching piles, and keeps any
overflow in the new stack. Anvil ingots, arrowheads, pig/sponge iron smithing and
the furnace outputs use it.

Run:

    py -3 -B -m unittest discover -s tests/stack_spawn -p "test_*.py" -v
    py -3 tests/stack_spawn/run.py --byond-bin <BYOND bin> --output <empty dir>

`run.py` compiles the production helper with `New` and `merge` copied from
`stack.dm` and checks merging, overflow, a full pile, a different metal,
non-stacking types and a control showing the old pattern loses items.
