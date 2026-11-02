# Showcase rooms

Six furnished room templates in `maps/zones/showcase/` stage one gameplay
station each, stocked with starter materials and a guide note on a table:

| Room | Stations | Starter stock |
| --- | --- | --- |
| `smithy` | bloomery, anvil, grindstone, armor repair workbench | iron ore, coal, wood, iron, hammer, wrench, pickaxe, shovel, water barrel |
| `kitchen` | wood stove, cutting board, kitchen sink, drying rack | meat, vegetable crate, flour, cooking pot, knife, rolling pin, plates |
| `tavern` | beer/ale/wine/rum barrels, alcohol distiller, wood stove | beer mugs on the bar, candlelit tables, bookcase |
| `workshop` | primitive saw mill, loom, tanning rack | logs, planks, sharpened flint, cotton, wet hides, rope, cloth, saw, chisel |
| `farm_shed` | flour mill, compost bin, drying rack | wheat/potato/carrot/cabbage seeds, hoe, plough, scythe, shovel, bucket, wheat |
| `infirmary` | three beds, roller bed, sink, laboratory distiller | surgery kit, first-aid kit, bandages, splints, herbs |

Each room is 11x9 tiles with walls, one wooden door at the middle of the south
wall, anchored lanterns in the north corners and a central roof support.

## Placing a room

Admins with spawn rights use **Debug > Load Showcase Room**. Stand where the
door should be: the room loads directly north of you. The verb removes
structures, items, floor/wall covers and roofs already in that footprint,
moves living mobs there onto your tile, then loads the template. It can add a
wooden roof over every non-wall tile, which makes the room a roofed indoor
area. Templates carry no areas, so the room otherwise keeps the area of the
ground it is placed on. Loading changes the turfs under the footprint and is
not undone automatically.

## Adding a room

Keep templates single z-level, area-free, with LF line endings, letter-only
keys and one model per line (the runtime reader in
`code/modules/dmm_suite/reader.dm` does not read TGM). Keep the door at
column `width / 2` (rounded down) of the bottom row and every floor tile within
two tiles of a wall or three of a roof support so the optional roof stays up.
Add the room name to `EXPECTED_ROOMS` and run:

```sh
python3 -B -m unittest tests/showcase_rooms/test_templates.py -v
```

The test checks parsing, declared type paths, the wall/door layout, roof
support coverage, lighting and the guide note. To have the compiler check type
paths as well, include the templates in a scratch copy of `civ13.dme` and
compile it; delete the copy afterwards.
