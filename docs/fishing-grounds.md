# Fishing grounds

Fish belong to the water. Code: `code/modules/1713/fishing_grounds.dm`.
Tests: `tests/fishing_grounds/`.

- **Grounds:** water is divided into stretches of 16x16 tiles. Each stretch has
  one ground per kind of water in it: salt, fresh, jungle river, swamp and
  flooded riverbed. Ice and the seabed level hold none.
- **Capacity:** coastal shelf 12, deep river or lake 10, shallow river 6, open
  ocean 6, swamp 3, flooded riverbed 2. A ground takes the capacity of the best
  water anyone has fished in it.
- **Fishing:** use a fishing pole, net or rod on any water tile next to you. A
  spear, harpoon or sharpened stick works in shallow water only. Over deep
  water you need a deck, bridge or pier under you. The target tile must be open
  water, not a hull or a covered tile.
- **Odds:** a pole or net has 30% after 15 seconds, a rod 40% after 12, a spear
  35% after 10, a sharpened stick 20% after 12. Bait adds 30 points to a line.
  The chance is scaled by how full the ground is, from a quarter at empty to
  the whole at full, and by 0.6 in the open ocean.
- **Catch:** rivers give salmon or plain fish; the coast plain fish or cod; the
  open ocean mostly cod, with squid on a baited line; swamps plain fish.
- **Regrowth:** worked out from elapsed time when the ground is next asked.
  Fastest at half stock (about one fish in four minutes), slow near full. An
  empty ground gets a fish every sixteen minutes while a neighbouring ground of
  its kind still has fish, and nothing otherwise. Unfished water is full and
  has no record.
- **Reading:** examining water within two tiles tells a player how full it is.
- **Admin:** Debug > Fishing Grounds lists fished grounds, emptiest first.
- **Saved:** grounds short of fish are saved with the durable world metadata
  in the map field `fishing_grounds_state` (field version 5), six values a
  ground: kind, cell x, cell y, z, capacity, stock. Full grounds are not kept.
  A save from before the field restores with every ground full. Time the
  server is down does not count towards regrowth.

The old fishing spot objects (`/obj/structure/fish`, salmon, cod) and the 8x8
open-sea stock are gone, from code, world-start seeding, maps and the land
generator.
