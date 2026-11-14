# Stone Age rites: burial mounds, cairns and feasts

Code: `code/modules/1713/stone_age_rites.dm`. Art: `icons/obj/stone_age_rites.dmi` from
`tests/sprites/create_stone_age_rites.py`. Tests: `python3 tests/stone_age_rites/test_source.py`;
native probe `python3 tests/ecology_spawning/run_linux.py . tests/stone_age_rites/probe.dm`.

## Burial mounds

- Heap `MOUND_DIRT` (3) piles of dirt (`/obj/item/weapon/barrier`, dug with a shovel) onto a
  filled grave that holds someone (a body, remains or a coffin). The last pile asks who rests
  there; the grave becomes "burial mound of <name>" with the `burial_mound` sprite.
- The mound is the same grave object, so its contents and save state are unchanged.
  `initialize()` reapplies the look after a load.
- A shovel on a mound levels it first (15 s, logged); a second shovel use digs up the grave as
  before.
- Raising a mound is a deed for the totem pole (`tribal_deeds.dm`).

## Cairns

`/obj/structure/religious/cairn`: 5 stone, Ritual Worship. Like the gravestone, it asks for a
name and what it marks (`/datum/craft_product/cairn`, plus the title check in `stack.dm`).

## Feasts

- `/obj/structure/feast_mat`: 3 leather, Ritual Worship. Food (`/food/snacks`) used on it is
  laid on it; grab intent with an empty hand takes the last dish back.
- An empty hand on it calls a feast (5 s). It needs `FEAST_GUESTS` (4) conscious people within
  2 tiles, the caller included, and a dish for each.
- Each guest eats one dish's worth: nutrition goes to full, mood +10, and for 180 real minutes
  (`feast_until`, text minutes) hunger drains at half rate (an override of
  `survival_climate_food_m()`).
- Holding a feast is a deed for the host.
