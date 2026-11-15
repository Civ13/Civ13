# Earthworks: steam roller and steam shovel

`code/modules/1713/earthworks.dm`. Both are site machines on
`/obj/structure/workshop_machine/steam_site`: pulled into place, stoked with
solid fuel counted in jobs (coal 4, charcoal 3, wood, planks or bamboo 1 a
unit, up to 40), and worked from beside them. A job is one wait; nothing ticks.

| Machine | Built from | Research |
| --- | --- | --- |
| Steam roller | 20 iron, gear set, 2 shafts, 2 bearings | Rail & Steam |
| Steam shovel | 20 iron, gear set, shaft, 2 bearings | Steam Power |

## Steam roller

Unfastened, with stone in its hopper (up to 60). The operator stands straight
behind it and clicks it with an empty hand; the road runs away from them. It
offers the road types in `road_roller_types` the operator may craft. The run
starts under the roller and stops at the first tile `tile_problem()` refuses
(no ground, water, lava, something dense, or `tile_build_refusal()`), at 12
tiles or when the stone runs out. The wait is 0.8 seconds a tile. Only when
it succeeds are the tiles rechecked and paved, one stone each, and the roller
moved to the last tile laid with `persistence_set_loc()`.

## Steam shovel

Fastened. One job takes up to 12 units of `available_dirt` and
`available_sand` from uncovered tiles within two tiles, 0.8 seconds a unit,
and heaps them on its own tile as dirt piles and sand. The ground is counted
again after the wait, so nothing is made that the ground no longer has.

## Tests

`python3 -m unittest tests.earthworks.test_contract` checks the source
contracts above; it does not run DM.
