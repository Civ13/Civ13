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
- **Trawl** (`/obj/item/weapon/fishing/trawl`, 12 rope, research node
  `rail_steam`): only from a ship making way at slow or half ahead. 20 seconds,
  six separate 35% chances, no bait, no engine penalty, no speed bonus and no
  tuna. It is the gear that empties a ground. Sprite `trawl_net` in
  `icons/obj/fishing_gear.dmi`.
- **Sonar:** a submarine's ping adds what the fish overhead look like and the
  bearing of a clearly fuller neighbouring stretch (`fish_finder_line()`).
- **Shoals** (`code/modules/1713/fish_shoals.dm`): great shoals travel the salt
  water, one for every 300x300 tiles of level (1 to 8). Each keeps to its own
  elliptical circuit about the middle of the map at about 3 tiles a minute and
  makes a whole number of laps a day, so it is in the same water at the same
  hour every day (`fish_shoal_position()`, from `world.timeofday`). Nothing is
  stored, ticked or saved, and it stands in for a current belt: the code has no
  ocean current field. Salt water within 12 tiles of a shoal fishes x1.5, 60%
  of its catch is herring, half the fish landed leave the ground's stock alone,
  and a fished-out stretch still fishes. The water reads "a great shoal is
  passing through", always shows signs (gulls, leaping fish), and sonar gives a
  shoal overhead or its bearing and range within 96 tiles. Debug > Fishing
  Grounds lists where the shoals of the level are.
- **Signs** (`code/modules/1713/fish_signs.dm`): rings where fish rise, a
  leaping fish now and then (more during the salmon run) and gulls over a
  shoal on the coast. They are images on the viewer's client from
  `icons/effects/fish_signs.dmi` (drawn by
  `tests/sprites/create_fishing_signs.py`), not objects. Every 8 seconds a
  client with a living human asks 14 random tiles within 9; a tile shows a sign
  with a chance equal to its ground's fullness, and never when fished out.
- **Ice** (`code/modules/1713/ice_fishing.dm`): frozen water cannot be cast
  into. A pickaxe or hatchet (8 s) or a chisel (12 s) used on an ice tile cuts
  an ice hole. A pole or rod used on the hole fishes the ground under the ice
  (fresh 6, sea ice 12, the same ground the water has when it thaws) at 0.8 of
  the usual chance; bait works, nets and spears do not fit. A hole freezes over
  after 20 minutes, also across a save, and goes when the ice thaws. Sprite
  `ice_hole` in `icons/obj/fishing_gear.dmi`
  (`tests/sprites/create_fishing_gear.py`).
- **Breaking ice** (`code/modules/1713/ice_breaking.dm`): on harm intent a
  pickaxe (12 s), hatchet or crowbar (15 s) or chisel (25 s) breaks a whole ice
  tile into open water, scaled by `work_delay()` as mining; a crowbar breaks on
  any intent since it cannot cut a hole. Bare hands on harm intent break only
  thin ice (15 s); tools break thin ice in half the time. Nobody may stand on
  the tile. It opens deep beside deep water of its kind, shallow otherwise, and
  any fishing hole on it goes. Ice is thin while newly refrozen, or while the
  air over it is above 1 C. Each broken tile gets one hidden
  `/obj/structure/broken_ice` marker that checks its tile every 5 minutes (15
  in a thaw): after 30 minutes at -2 C or colder, with no boat or person in it,
  the water skins over as "thin ice"; 60 more freezing minutes make it ordinary
  ice and the marker goes. Thin ice above 1 C melts back. The counts are saved;
  a marker whose tile something else changed deletes itself. Rafts, canoes and
  small boats crunch through thin ice and stop at thick ice. A built ship stops
  at any ice unless a hull tile beside the ice tile carries belt armour
  (`hull_armour_at()`), which breaks thin ice ahead of her; airships ignore ice.
  Probe checks are in `tests/fishing_grounds/probe.dm`.
- **Flood strandings:** a tile of ankle-deep floodwater over outdoor land that
  somebody can see has a 2% chance each river minute to leave a fish on it
  (`fish_flood_stranding()`, asked by the flood's item pass). The fish come out
  of a flooded-ground stock of 2 for the 16x16 stretch, so a flood plain gives
  a few fish and then waits for regrowth.
- **Catch** (`fish_catch_type()`): rivers and lakes give salmon, trout and
  plain fish, with catfish from their deep water; jungle rivers catfish, salmon
  and plain fish; swamps catfish and plain fish; the coast herring, cod and
  plain fish; the open ocean mostly cod, squid on a baited line, and tuna on a
  baited (12%) or towed (25%) line only. The new fish
  (`code/modules/1713/fish_species.dm`, sprites in
  `icons/obj/food/fish_species.dmi` from `tests/sprites/create_fish_species.py`)
  are raw fish like any other; a catfish cuts into 4 fillets, a herring 2, a
  tuna 6.
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
