# Aluminium

`code/modules/1713/aluminium.dm` turns bauxite into aluminium. Aluminium is
the light metal for vehicle hulls: its density is 35 against steel's 100
(`material_properties.dm`), and a lighter hull drives faster under the
vehicle load rules (`vehicle_load.dm`, docs/craft-core.md "Vehicle load").

## Route

| Step | Where | In | Out | Power |
| --- | --- | --- | --- | --- |
| Bauxite | mined walls from the Industrial age (6%, 12% under jungle or savanna, 24-36 per find); stone crushers (1.5%) | - | bauxite | - |
| Bayer process | alumina digester | 2 bauxite + 1 unit of sodium hydroxide or lye | 1 alumina; red mud every 10 | 10 |
| Hall-Heroult process | reduction pot | 1 alumina, 1 coal or charcoal per 2 ingots | 1 aluminium ingot | 40 |

Each batch takes five powered object-process steps (about 10 seconds). A
machine without power waits; one that runs out of an input stops and goes
quiet. The digester holds 100 bauxite and 100 units of caustic; the pot holds
100 alumina and 100 carbon. Factory arms load both. An extraction kit purifies
bauxite into the `aluminum` chemistry reagent, as it does other ores.

Both machines are steel recipes unlocked by **Aluminium Refining**
(Industrial, tier 5; needs Electricity and Alloys). A reduction pot draws 40
from the cable, about all a steam engine gives, so the gate is a real power
plant.

Sprites are in `icons/obj/aluminium.dmi`, drawn by
`tests/sprites/create_aluminium.py`.

## Uses

- Aircraft: the hangar's cabin plane, cargo plane and twin-engine plane have
  aluminium airframes (48, 44 and 64 ingots) with steel engines; the trainer
  and light plane are wood, cloth and wire (docs/piece-projects.md).

## Hulls

`code/modules/1713/machinery/modular_vehicles/vehicle_hulls.dm` gives a
vehicle's frames a hull material when the press assembles it
(`set_hull()`). Against steel:

| Hull | Weight | Wall armour | Wall health | Used by |
| --- | --- | --- | --- | --- |
| aluminium | 0.55 | 0.6 | 0.85 | any works vehicle on request; the tracked carrier always; cabin, cargo and twin-engine planes |
| wood | 0.6 | 0.3 | 0.6 | trainer and light plane |

The walls' armour and health are scaled once at assembly. The frame keeps its
`hull_material`, so `wall_weight()` and `airframe_weight()` can weigh it
against the same body in steel. A lighter works vehicle drives faster
(docs/craft-core.md "Vehicle load"), and a lighter plane rolls and climbs
sooner.

When a player who knows Aluminium Refining starts a works vehicle project,
the press asks for a steel or aluminium hull. Aluminium pays four fifths of
the frame and body steel as ingots, in multiples of 4. The engine and gun
stay steel (`works_hull_cost()`). The tracked carrier uses the M113 layout and
is aluminium only: 112 aluminium and 40 steel. Tank guns cost more on bigger
tanks: 40, 70, 100 and 130 steel from the light tank to the main battle tank.

## Composite armour

`code/modules/1713/composite_armour.dm`, unlocked by **Composite Armour**
(Military, tier 7; needs Modern Armor and Mechanized Warfare). Its inputs need
alumina (Aluminium Refining) and prepared Kevlar (Synthetic Fabrics):

- **Ceramic tiles:** put alumina in a kiln; each firing turns every measure
  into one ceramic armour tile (up to 40 at a time; `accept_alumina()` and
  `fire_alumina()`, hooked from `refining.dm`).
- **Panels:** use a stack of tiles on prepared Kevlar to bond two tiles to one
  sheet into a composite armour panel.
- **Fitting:** use a panel on any frame with an armoured wall: tanks,
  armoured cars, carriers and hand-built frames. Choose the wall, then wait 8
  seconds. One panel fits per wall. It adds half the wall's armour (at least
  20) and a third of that in health.
- **Weight:** a panel weighs half what the same armour would in steel
  (`COMPOSITE_PANEL_WEIGHT`). It is load on top of the steel body, so a fully
  plated heavy tank is much tougher and somewhat slower
  (`wall_weight()`, docs/craft-core.md "Vehicle load").

## Tests

    python3 tests/ecology_spawning/run_linux.py . tests/aluminium/probe.dm 300
