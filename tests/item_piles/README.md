# Item piles

Headless probe for `code/game/objects/items/item_piles.dm` (identical items on a
tile with the same appearance and position collapse into one right-click menu entry, and loose piles: plain items such
as roofing and bricks that gather into one counted pile of up to 25), the
roofing piles in `code/game/objects/roof_stuff.dm` and the brick, clay block and
roof tile piles in `code/game/objects/items/clay_items.dm`.

```
bash scripts/cloud_byond_setup.sh   # once, installs the pinned compiler
python3 tests/ecology_spawning/run_linux.py . tests/item_piles/probe.dm
```

It puts 70 identical roofing items on a tile and checks that only the top one
stays clickable, that scattered cutlets retain each distinct hitbox, an item hidden by its own code is left alone, that moving
the top item away (forceMove or a raw `persistence_set_loc`) reveals the next,
that a picked-up item is always clickable, and that items with different names
stay separate. For roofing it checks piling, the pile cap, different roofing
staying apart, building using one piece, dropping onto a pile, and kiln firing
adding to a pile. For bricks it checks piling and the count in the name, fired,
unfired and cement bricks staying apart, building using one brick, the brick
bench and crates putting out piles (and non-pile items still coming out one by
one), kiln firing a pile into a pile (clay blocks still yield two each), dropping
onto a pile, the pile cap and taking several pieces at once. Exit status 0 means no failures and no runtime errors.

Not established: the right-click menu in a real client and a save/load roundtrip
of a collapsed pile.

For overlapping items, **Shift+Alt-click** an adjacent tile or an item on it.
Pick a specific object from the numbered list: an empty hand picks it up, and
a held item is used on it as in an ordinary click. Right-click still groups fully superimposed identical objects. Offsets or
other appearance differences keep objects separately clickable. This does not split a counted stack into individual choices. For unusually
large piles the chooser checks the first 100 ground items on each click.

```
python3 tests/item_piles/test_sources.py
```

The source regression checks the existing click dispatch, direct tile items
and line of sight, stale prompt choices, and pile refresh after paper bundling
or a quantity rename. It does not drive a Dream Seeker client or its popup.
