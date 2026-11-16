# Stone Age storage

Four containers open from 5000 BC, before Cooperage brings the wood crate and
chest. Each opens a real storage window (click it with an empty hand) instead
of sweeping up its tile like a crate. Code: `code/modules/1713/stone_age_storage.dm`.

| Container | Research | Recipe | Slots | Largest item | Food keeps |
| --- | --- | --- | --- | --- | --- |
| Woven basket | Weaving | 3 rope, 6 leaves, 4 bamboo or 4 planks | 7 | Normal | Like any container |
| Clay storage jar | Pottery & Cookware | 3 clay, then fired in a kiln or oven | 6 | Small | Twice as long |
| Hewn log chest | Basic Furniture | 6 logs | 10 | Large | Like any container |
| Storage pit | Primitive Construction | Pit lining (4 leaves or 2 leather), dug with a shovel or digging stick | 14 | Normal | 1.5 times as long |

- Put things in by clicking the container with them, or open the window and
  drag them in. Take them out from the window.
- Dump Out (right-click, or Alt-click) tips everything onto the floor after a
  short wait. A container that is destroyed spills what it held.
- The jar does not burn. The pit is fixed in place; filling it in with a
  shovel removes it and spills its contents.
- A fired jar is too big for the oven and is set down on an open tile beside it.
- Food keeping: stored food reads `food_decay_step` from the container that owns
  its holder (`storage_food_decay_step()`), so the rate is set per container.

`/obj/structure/storage_container` is the base the storage overhaul builds on
(new storage window, timed transfers, searching, crates moved onto it).
Probe: `tests/stone_age_storage`.
