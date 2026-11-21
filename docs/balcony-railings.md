# Balcony railings

Railings that players build along the edge of a floor: balconies, roof
terraces, wall walks and the sides of a stairwell. Code:
`code/game/objects/structures/railing_built.dm`. Probe:
`tests/balcony_railings/run.py`. Art: `icons/obj/railings_built.dmi`, drawn by
`tests/sprites/create_built_railings.py`.

## Kinds

| Railing | Built from | Research | Health |
| --- | --- | --- | --- |
| wooden railing | 2 finished planks | Primitive Construction | 100 |
| stone balustrade | 3 stone | Stone Masonry | 300 |
| sandstone balustrade | 3 sandstone | Stone Masonry | 250 |
| brick railing | 1 pile of fired bricks (use the bricks in hand, pick Brick Railing) | bricks already need Brickmaking | 300 |
| wrought iron railing | 2 iron | Iron Smithing | 250 |
| steel pipe railing | 2 steel | Steelmaking | 350 |
| glass balustrade | 3 glass | Modern Construction | 80 |

Recipes are in the "railings" group of `config/crafting/material_recipes_global.txt`
and stay open-ended (era cap 8).

## Rules

- A railing is an `/obj/structure/railing` subtype, an `ON_BORDER` edge. It is
  built on the floor tile the builder stands on, along the side they face
  (`O.set_dir(user.dir)` in `produce_recipe`). It must stand on the floor, not
  on the open air beyond, or it would fall.
- `railing_build_refusal()` allows one railing (or parapet or other border
  barrier) along each side of a tile; two railings on one tile make a corner.
  `produce_recipe` asks it before and after the build wait.
- Nobody walks across a railing (`CheckExit`/`CanPass` of the base type);
  climbing over and grab-throwing over keep the base behaviour.
- Thrown items and projectiles pass (`PASSTABLE`). `railing_cover_verdict()`,
  asked by `directional_cover_verdict()`, lets every shot over except that a
  stone, sandstone or brick balustrade stops 30% of shots coming in across it
  when someone on its tile is lying down.
- A hammer takes a railing apart in 3 s and gives back the cheapest recipe's
  cost (`crafted_refund_units`); a brick railing gives back its bricks. A
  wrench does nothing to a built railing. Broken railings give nothing.
- Built railings are building parts for impacts (`structure_impact_part`,
  material by kind) and fall with their floor (`falls_with_floor()`, asked by
  `building_floor_lost()`).
- Map-placed `/obj/structure/railing` and `/steel` keep their old look and
  neighbour overlays; the built kinds draw one whole piece per side.
