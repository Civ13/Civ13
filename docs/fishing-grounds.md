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
- **Odds:** a pole has 30% after 15 seconds, a rod 40% after 12, a spear
  35% after 10, a sharpened stick 20% after 12. Bait adds 30 points to a line.
  The chance is scaled by how full the ground is, from a quarter at empty to
  the whole at full, and by 0.6 in the open ocean.
- **Cast net:** a fishing net takes 15 seconds a throw and has three separate
  25% chances, so one throw can land up to three fish. It takes no bait. It
  feeds more people than a line and empties a ground faster.
- **Set gear:** a fish weir and a fishing cage take their fish from the ground
  they stand in (`fish_ground_trap_catch()`), one a catch. In a fished-out
  stretch a weir stays empty and a cage brings up only shellfish, crabs,
  lobster and the like, which are not counted as stock. A fish pen is a closed
  stock of its own and takes nothing.
- **Conditions** (`fish_condition_factor()`), multiplied into the chance and
  shown as a second line when the water is examined:
  - Salmon run, in autumn (`SEASON_FALL`): fresh water x1.5, 85% of the catch
    is salmon, and fresh grounds regrow twice as fast.
  - Rain on the tile: x1.25 everywhere.
  - A storm (extreme weather) on the tile: the sea x0.5, other water x0.75.
  - River in spate (stage 1 or more): fresh and jungle water x0.6.
  - Low river (stage -1 or less): deep fresh and jungle water x1.2.
  The final chance is capped at 95%.
- **From a ship** (`fish_ship_factor()`): a running engine aboard x0.6, with a
  warning when the cast starts. While she is making way a cast becomes
  trolling (`fish_troll()`): lines only, the fisher must stay aboard and within
  two tiles of open water, and the fish come out of the ground she is over
  when the wait ends. Slow ahead x1.3, half ahead x1, full ahead x0.5. Sails
  and oars are silent.
- **Sonar:** a submarine's ping adds what the fish overhead look like and the
  bearing of a clearly fuller neighbouring stretch (`fish_finder_line()`).
- **Flood strandings:** a tile of ankle-deep floodwater over outdoor land that
  somebody can see has a 2% chance each river minute to leave a fish on it
  (`fish_flood_stranding()`, asked by the flood's item pass). The fish come out
  of a flooded-ground stock of 2 for the 16x16 stretch, so a flood plain gives
  a few fish and then waits for regrowth.
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
