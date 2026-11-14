# Lifting: shear legs and heavy loads

`code/modules/1713/lifting_machines.dm`, sprites `icons/obj/lifting_machines.dmi`
(drawn by `tests/sprites/create_lifting.py`), suite `tests/lifting_machines`.

## Heavy things need a hoist

`hoist_only_types` lists what is too heavy for a ladder: anvils, furnaces and
kilns, ovens, saw mills, mills, workshop machines, engines, vehicle parts,
cannon, drills, printing presses, fabricators, tanning drums and research
forges. `hoist_exempt_types` takes the bellows and the shear legs back out.
Both ladder climbs in `code/modules/multiz/structures.dm` call
`ladder_refuses_load(M)` before the wait, so the climber is told why and
nothing moves. People, animals, crates, carts and everything not listed still
go up and down ladders as before. Stairs and edge climbing already drop pulls.

## Shear legs

10 wood, Primitive Construction. One unfastened item or structure per haul;
nothing is stored in the legs and nothing ticks.

- Drag a load standing next to the legs onto them: raise it to the level
  above (open air must be over the load, and a clear supported tile within 2
  tiles of the legs up there) or lower it to the level below (open air beside
  the legs with clear ground under it).
- Click the legs with an empty hand to haul up a load lying below, under open
  air within 2 tiles; it lands on the nearest clear tile beside the legs.
- A haul takes 6 seconds, 10 for a hoist-only load. The load moves only when
  the wait finishes and the hauler, load and landing are all still valid.
- Fastened objects, anything with someone inside, and hauls during a save are
  refused. Wrench to unfasten the legs, hammer on harm intent to dismantle.

Scaffolding was planned beside the legs and left out: placed ladders already
give a way up, and floors already extend over open air.
