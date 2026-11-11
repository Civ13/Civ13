# Underground excavation

Dirt piles (`/obj/item/weapon/barrier`) build dirt walls, mould into clay with
water and fill graded ground back up (docs/terrain-height.md). On the surface
they come from scooping dirt ground (`available_dirt`, 3 per plain dirt tile)
and from grading a hill down a level. Below ground there are three more
sources, all in `code/modules/1713/underground_excavation.dm`:

| Route | Tool | Time (before strength and shovel speed) | Yield |
| --- | --- | --- | --- |
| Dig out soft cave rock (`/turf/floor/dirt/underground`, sandy too) | shovel, any intent | 30 s | 2 dirt piles (sandy rock adds 1 sand pile); the opened floor still holds 3 scoopable dirt |
| Clear cave-in rubble (`/turf/floor/dirt/underground/empty`) | shovel, any intent | 12 s | 1 dirt pile |
| Finish a tunnel shaft (shovel "Tunnel" dig, down or up, native levels and the dug cave level) | shovel | unchanged | 2 dirt piles at the digger's feet |

A pickaxe still breaks the same rock for stone and ore in 24 s; the shovel is
the slower dirt route and never rolls ore or stone. Both open the tile with
`change_the_turf()` and roll the same cave-in check (`collapse_check`), so mine
supports matter either way. Frozen rock (`underground/icy`) and rock that is
not mineable refuse a shovel. A tile being mined cannot be dug at the same
time (`mining_in_progress`, `pickaxe_mining_owner`).

The shovel override runs before the base cave-rock `attackby` and returns its
result, so a shovel on a cave wall no longer falls through to the dirt-ground
handlers (trench digging on harm intent, grading on disarm intent, scooping
on help intent), none of which applied to solid rock.

Underground levels have no terrain height rows, so cave floors cannot be
graded; their dirt comes from these routes and from scooping the opened floor.

## Tests

- Native: `python3 tests/ecology_spawning/run_linux.py . tests/underground_excavation/probe.dm`
  (pinned BYOND from `scripts/cloud_byond_setup.sh`). Full sources, ordinary
  startup disabled; checks the yields, the opened floors, sand from sandy rock,
  rubble, refusals (busy, frozen, unmineable, open or built floors), a shovel on
  frozen rock leaving it intact, and the shaft spoil.
- Offline: `python3 -m unittest tests/underground_excavation/test_underground_excavation.py`
  checks every tunnel shaft route calls the spoil and the include order.

Not established: real client clicks and wait timing, cave-in rolls after a dig
(they share the pickaxe's spawn-delayed check), or save/load of the piles
beyond ordinary item persistence.
