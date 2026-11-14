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

## Tests

    python3 tests/ecology_spawning/run_linux.py . tests/aluminium/probe.dm 300
