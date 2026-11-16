# Trapdoors

`python3 tests/trapdoors/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 12x12 world of
two levels with real humans, a wooden ladder and a flight of stairs, checks
`code/game/objects/structures/trapdoors.dm` and its hooks in the multiz code
(`structures.dm`, `edge_climbing.dm`, `pit_climbing.dm`, `hole_ladder.dm`,
`open_space.dm`, `building_levels.dm`):

- a trapdoor kit is laid into an opening beside you, one per opening and
  never on solid floor, and lies flat: not dense, not opaque;
- shut, it is floor: it is not open air, it is solid footing, nobody climbs
  down the ladder under it, things lie on it;
- its sides are above and below; it won't open while someone stands on it;
- bar brackets and a bar from above keep it shut against a push from below
  through the ladder;
- a latch fitted from below through the ladder treats below as its outside;
- open, the ladder climbs through, things on it drop to the level below and
  the stairs under it climb again; shut, the stairs say the trapdoor is shut;
- with its hinges below, it comes out only from below, through the stairs,
  back into a kit;
- closers and other door-only fittings are refused;
- no runtime errors.

It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).
