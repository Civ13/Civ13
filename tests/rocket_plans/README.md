# Rocket plans

## `probe.dm`

A native probe for `code/modules/space/rocket_plan.dm` and
`rocket_plan_checks.dm` (docs/rocket-plans.md). The three starter rockets
pass their checks, read back from their design codes and each supports its
own mission only: the crew orbiter reaches orbit and brings its crew home but
cannot reach the Moon, the cargo hauler reaches orbit only, and the lunar
probe transfers and lands but never comes home. It pins the tradeoffs: a
steel frame lifts a small probe to orbit but not a crew capsule, two cargo
bays need boosters, six boosters still fall short of the Moon, and a rocket
too heavy for its engines cannot lift off. It checks that empty cargo bays
leave more delta-v, that each fitting check fires (heat shield, heavy heat
shield, parachutes, payload below a decoupler, a stage with no engine, a
decoupler on top, the bottom engine, no payload, two capsules), that a weak
upper stage and missing landing legs are named by the planner, that bad
codes are refused, that the sheet keeps the rocket, and that every piece has
a part description.

    python3 tests/ecology_spawning/run_linux.py . tests/rocket_plans/probe.dm 300
