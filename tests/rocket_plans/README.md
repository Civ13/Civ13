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

## `works_probe.dm`

Building a rocket (`rocket_works.dm`): the works builds every section of a
sheet from its stock and spends what the sheet costs; the stand mounts them
in order, refuses the wrong, distant or worn section, mounts upper storeys
only from the level above and raises the rocket's body there; the finished
rocket takes the sheet's propellant and seats, carries the planner, flies
only to orbit and takes its storeys and sections with it.

    python3 tests/ecology_spawning/run_linux.py . tests/rocket_plans/works_probe.dm 300

## `reuse_probe.dm`

Rocket reuse (`rocket_reuse.dm`): a returned section is worn, counts its
flight and is refused until inspected; a capsule with a heat shield and
parachutes carries a well-formed record to orbit and home, and a capsule
without parachutes cannot deorbit; malformed records and records on other
flights are refused; coming home, the capsule splashes down by the shore,
lands softly on its landing rockets or comes down hard, once per flight;
landing legs fly a first stage back only from 2013, and the propellant kept
to land costs delta-v.

    python3 tests/ecology_spawning/run_linux.py . tests/rocket_plans/reuse_probe.dm 300

## `missions_probe.dm`

Uncrewed missions (`rocket_missions.dm`): the payload picks the mission; a
lunar probe rocket needs a pad, propellant and an idle console nearby, and an
orbit-only probe is told it lacks the lunar transfer; the probe flies a
one-way Moon mission, records its landing as a surveyed site a crewed lander
can choose, never ascends or carries samples, and the site stays after the
mission is abandoned. The heavy cargo launch is checked through the transfer
bridge in `tests/orbit_world/probe.dm` (`orbit_rocket_cargo_checks`).

    python3 tests/ecology_spawning/run_linux.py . tests/rocket_plans/missions_probe.dm 300
