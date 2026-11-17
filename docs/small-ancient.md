# Clay tablets, board games and the ice house

Code: `code/modules/1713/small_ancient.dm`. Art: `icons/obj/small_ancient.dmi`
from `tests/sprites/create_small_ancient.py`. Probe: `tests/small_ancient/probe.dm`.

- **Clay tablet** (1 clay, Pottery & Cookware) and **reed stylus** (1 wood):
  a tablet is paper that won't burn. Write on it with the stylus or any pen.
  Fired in an oven or kiln it stays the same tablet with its writing, but
  bakes hard and can't be written on again.
- **Senet board** (3 wood, Basic Furniture) and **chess set** (4 wood, Fine
  Arts & Leisure): use one with another player beside the board. After 20 s
  one of you wins and both get +5 mood.
- **Ice house** (10 wood, Cooperage & Containers): a closet. Each snow pile
  packed in gives an hour of cold and each block of cut ice three hours, up to
  twenty; it melts a minute a minute while the air is above freezing, and a
  minute every four minutes on the underground level or in the caves. While
  cold, food inside decays at the freezer rate (`food_decay` in `food.dm`).
- **Block of ice**: a pick, hatchet or chisel on an open ice hole
  (`ice_fishing.dm`) cuts a block from its edge, four to a hole. Left loose it
  melts away after 40 minutes above freezing.

Wax seals already exist (`code/modules/paperwork/stamps.dm`) and telescopes are
already craftable (Optics & Instruments), so neither was added. Terraces were
left out: farming has no slope penalty for a terrace to remove.
