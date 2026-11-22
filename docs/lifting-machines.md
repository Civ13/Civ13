# Lifting: shear legs and heavy loads

`code/modules/1713/lifting_machines.dm`, sprites `icons/obj/lifting_machines.dmi`
(drawn by `tests/sprites/create_lifting.py`), suite `tests/lifting_machines`.

## Heavy things need a hoist

`hoist_only_types` lists what is too heavy for a ladder: anvils, furnaces and
kilns, ovens, saw mills, mills, workshop machines, engines, vehicle parts,
cannon, drills, printing presses, fabricators, tanning drums and research
forges. `hoist_exempt_types` takes the bellows and the shear legs back out.
`level_change_load_problem(A, ladder)` decides what a pulled thing may do
between levels (since 2026-11-18). Hoist-only loads go on neither ladders nor
stairs, and wheeled carts (`wheeled_load_types`) go on neither. Stairs take
people, animals, crates and items:
`stairs_check_load` lets go of what cannot come before the climb, and
`stairs_bring_load` moves what is still pulled onto the climber's tile, so the
pull holds. A ladder needs both hands, so it takes only people, small animals
(mob_size up to MOB_MEDIUM) and loose items. Both ladder climbs in
`code/modules/multiz/structures.dm` call `ladder_refuses_load(M)` before and
after the wait, so the climber is told why and nothing moves. Edge climbing
still drops pulls.

Ramps (`code/modules/multiz/ramps.dm`, suite `tests/ramps`) are a straight run
of cover sections facing the climb direction, with open air over every
section. The top section of a full run is found by `stairs_in` and climbs like
stairs. Each kind passes its `ramp_carries` to the load rule: an earth ramp
(4 sections) takes what stairs take, a timber ramp (4) adds wheeled loads and
wheelchair riders, and a stone or concrete ramp (8) adds a hoist-only load when
`ramp_haul_helper` finds a second person beside the hauler or the load; that
haul waits `RAMP_HEAVY_TIME`.

## Shear legs

10 wood, Primitive Construction. One unfastened item or structure per haul;
nothing is stored in the legs and nothing ticks.

- Drag a load standing next to the legs onto them: raise it to the level
  above (open air must be over the load, and a clear supported tile within 2
  tiles of the legs up there) or lower it to the level below (open air beside
  the legs with clear ground under it).
- Click the legs with an empty hand to haul up a load lying below, under open
  air within 2 tiles; it lands on the nearest clear tile beside the legs.
- A haul takes 6 seconds, 10 for a hoist-only load, less with a prime mover
  turning next to the hoist (`docs/mechanical-power.md`). The load moves only when
  the wait finishes and the hauler, load and landing are all still valid.
- Fastened objects, anything with someone inside, and hauls during a save are
  refused. Wrench to unfasten the legs, hammer on harm intent to dismantle.

Scaffolding was planned beside the legs and left out: placed ladders already
give a way up, and floors already extend over open air.

## Treadwheel crane

`/obj/structure/workshop_machine/shear_legs/crane`: 16 wood plus a shaft, two
bearings and a belt, Imperial Architecture. It is the same hoist with
`reach = 3` and its own sprites; it adds no procs.

## Powered cranes

`code/modules/1713/power_cranes.dm` adds two cranes that are the same hoist
with their own engine. Fuel is one number counted in hauls: a powered crane
refuses to haul with none, burns one haul when a haul starts and winds in
0.35 of the hand time. Nothing ticks.

| Crane | Built from | Research | Reach | Fuel |
| --- | --- | --- | --- | --- |
| Steam crane | 20 iron, gear set, shaft, 2 bearings | Steam Power | 4 tiles, one level | coal 4, charcoal 3, wood, planks or bamboo 1 haul a unit, up to 40 |
| Tower crane | 30 steel, 2 gear sets, shaft, 2 bearings | Modern Construction | 6 tiles, up to 3 levels | 5 units of diesel, biodiesel or gasoline a haul, up to 60 |

The tower crane overrides `haul_choices()` only. Raising stops at the first
level where the tile over the load is not open air. Lowering follows the
columns of open air within reach on the crane's level and offers the nearest
clear ground on each level those columns still reach.
