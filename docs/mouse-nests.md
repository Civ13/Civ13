# Mouse nests

Mice do not appear out of rotten food. They live in nests.

- **Wild burrows** (`/obj/structure/mouse_nest/burrow`): the ecology cycle
  places them out of sight on grass and dirt in temperate, semiarid, savanna,
  taiga and jungle land, one per 4,000 habitat tiles, at most 30. They do not
  count toward the 450 wild animal cap. A burrow holds 2-4 mice and does not
  breed outdoors in winter.
- **House nests** (`/obj/structure/mouse_nest`): hold 0-8 mice; a nest with no
  reachable food loses one mouse per step and disappears at 0.
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
