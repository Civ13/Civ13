# Mouse nests

Mice do not appear out of rotten food. They live in nests.

- **Wild burrows** (`/obj/structure/mouse_nest/burrow`): the ecology cycle
  places them out of sight on grass and dirt in temperate, semiarid, savanna,
  taiga and jungle land, one per 4,000 habitat tiles, at most 30. They do not
  count toward the 450 wild animal cap. A burrow holds 2-4 mice and does not
  breed outdoors in winter.
- **House nests** (`/obj/structure/mouse_nest`): hold 0-8 mice; a nest with no
  reachable food loses one mouse per step and disappears at 0.

## Food and spreading

Each settle takes one look 5 tiles around the nest (`forage_scan()`).

| Store | Access |
| --- | --- |
| Loose food or seed on the floor, ripe crops, woven baskets, racks | Open: 1 unit each |
| Hewn log chests, storage pits, wooden crates and closets | Gnawed: 1/4 unit each |
| Clay storage jars, fridges, ice houses, freezer crates, metal, stone, glass and brick crates, anything carried | Proof |

- A nest grows by one mouse per step while it has more food units than mice,
  up to its cap; a house nest with no food loses one. Burrows hold 2-4 and do
  not breed outdoors in winter.
- Each step the nest eats half its mice (rounded up) in food, open stores
  first (gnawable ones only 1 time in 4): a food item is gone, a seed stack
  loses one seed, a ripe crop loses its harvest but the plant lives and grows
  again. Each meal fouls one more food in the same store: it is renamed
  "gnawed ...", gets the gnawed overlay and 1u food poisoning.
- A full nest with food has a 20% chance per step to found a house nest of 2
  within 2 tiles of a store it eats from (and within 12 tiles of itself),
  taking two of its own mice. The site must be dirt, grass, a wooden floor or
  carpet, not seen by a player, and not where 3 nests already lie within 15
  tiles. This is how burrows next to fields and stores move into settlements.
- Mice no longer use the generic granivore/scavenger AI: everything they eat
  goes through the nest.
- A nest saves `population`, `last_settle`, `commensal` and `fleas`. Loading
  restarts its settle clock, so downtime never causes a burst of growth.
- The `mouse nests` process runs every 10 s: it settles two nests (each applies
  every whole 5-minute step since its last settle, at most 12) and lets mice
  out. While nobody is on the map, nests are not settled.
- Mice come out at dusk and night outdoors, any time indoors, only when a
  player is within the ecology awake range: at most 2 per nest and 40 in the
  world. They are not saved. They wander within 5 tiles and run home when a
  person, cat or dog comes within 4 tiles, after 3 minutes, or at daybreak.
- A shovel or digging stick digs a nest out in 10 s; 1-3 mice scatter and
  slip away out of sight after 10 minutes.
- Cap: 60 nests world-wide.

## Cats and dogs

- Wildcats (`/mob/living/simple_animal/pet/cat/wild`) are an ecology species:
  temperate, semiarid and savanna grass or dirt, density 0.1, at most 8. They
  run from anyone within 3 tiles who is not holding meat or fish.
- Cats take raw meat, raw or dried fish and fish fillets by hand. A wildcat
  becomes a tame cat after the usual domestication feedings (6, at least 10
  minutes apart; `domestication.dm`) and then leaves the wild census.
- Two tame adult cats within 3 tiles can raise a kitten, at most once every
  2 real hours each, while there are fewer than 12 cats in the world.
- Each conscious cat within 7 tiles of a nest takes one mouse per settle step,
  a dog half of one, and a nest with any hunter near never spreads. Emitted
  mice still run home from people, cats and dogs, and cats still pounce on
  mice they reach.

## Traps

- **Snap mousetrap** (`/obj/item/weapon/mousetrap`, iron, Iron Tools): use it in
  hand to set it, then put it on the floor. Each settle step every set, empty
  trap within 5 tiles of a nest takes one mouse and holds it; use it in hand
  to drop the dead mouse, then set it again. A mouse mob running over it is
  caught too. A barefoot person stepping on it gets a sore toe and springs it.
- **Baited deadfall**: the stone-age deadfall can also be set on any indoor
  floor. Bait a set deadfall with a bit of food; each settle step a baited
  deadfall within 5 tiles of a nest falls on one mouse, which you take out and
  reset as with any catch. Indoors a deadfall catches no game, only mice.
