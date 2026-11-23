# Rocket plans

From 1969 a rocket is not one recipe. Players draw one on a ship's draught
around a mission, and the pieces they choose decide what it can do. The
design plan is the "Modular rocketry from 1969" doc in the project thread;
this file is the reference for the code.

- `code/modules/space/rocket_plan.dm`: the `/datum/rocket_plan`, its pieces,
  stages, delta-v, the legs and the design code.
- `code/modules/space/rocket_plan_checks.dm`: design checks of kind
  `rocket_plan` and the part book.
- `code/modules/space/rocket_designer.dm`: the designer window.
- `tests/rocket_plans/probe.dm`: pins the starter rockets and the checks.

## The sheet

A rocket sheet is the draught kind `ROCKET` (`naval/draught_kinds.dm`), from
1969 (`ORBIT_MIN_AGE`). Its code is

    C13ROCKET/1/<name>/<frame>/<boosters>/<stack, bottom first>

`frame` is `s` (steel) or `a` (aluminium); framed pieces (tanks and
decouplers) weigh 1.0x or 0.6x on them. `boosters` is 0, 2, 4 or 6 strap-on
solid boosters on the first stage. The stack is at most
`ROCKET_PLAN_MAX_PIECES` piece keys and `ROCKET_PLAN_MAX_SECTIONS` sections;
fittings take no section. A launch stand holds `ROCKET_STOREY_SECTIONS`
sections a storey.

| Key | Piece | Dry t | Propellant t | Thrust kN | Exhaust speed |
| --- | --- | --- | --- | --- | --- |
| E | Sea-level engine | 1.5 | - | 1100 | 2.9 |
| V | Vacuum engine (no liftoff thrust) | 1.0 | - | 250 | 3.9 |
| T | Propellant tank (framed) | 2.0 | 15 | - | - |
| D | Decoupler (framed) | 0.5 | - | - | - |
| M | Service module | 1.2 | 2.5 | 60 | 3.0 |
| C | Crew capsule, 3 seats | 2.6 + 0.3 crew | - | - | - |
| K | Cargo bay, 20 items, planned 5 t | 1.0 | - | - | - |
| Q | Probe bus | 0.6 | - | - | - |
| X | Heat shield (fitting) | 0.5 | - | - | - |
| Y | Heavy heat shield (fitting) | 0.9 | - | - | - |
| R | Parachutes (fitting) | 0.3 | - | - | - |
| L | Landing rockets (fitting) | 0.4 | - | - | - |
| G | Landing legs (fitting) | 0.6 | - | - | - |
| boosters | each | 2.5 | 10 | 800 | 2.4 |

## Stages and delta-v

Decouplers split the stack into segments; a decoupler drops with the segment
below it. Each segment with an engine and propellant is a burn: exhaust speed
(thrust-weighted over its engines) x ln(m0 / m1) with everything above it
attached. Boosters burn with the first stage while the core burns at its own
rate, then drop. Service modules burn last, carrying only the top segment.

## Legs

| Leg | Delta-v from the pad | Also needs |
| --- | --- | --- |
| Liftoff | - | Sea-level engines and boosters push 1.2x the weight |
| Reach orbit | 7.0 | Every upper stage pushes 0.3x what it carries |
| Come home from orbit | 7.1 | Capsule, heat shield directly under it, parachutes directly over it |
| Lunar transfer | 9.5 | - |
| Land on the Moon | 11.3 | Landing legs in the top segment |
| Come home from the Moon | 13.5 | Heavy heat shield and parachutes |

Failing liftoff or orbit is a design error: every mission needs both. The
later legs are reported by the launch planner (`legs()`, `planner_lines()`),
with what each is missing.

## Starter rockets

| Rocket | Code stack | Supports |
| --- | --- | --- |
| crew orbiter | `a/0/ETTTDVTXCRM` | orbit, come home |
| cargo hauler | `a/4/EETTTTDVTTTKK` | orbit with two full bays |
| lunar probe | `a/0/EETTTDVTTDVTGQ` | orbit, lunar transfer, landing |

A steel crew orbiter falls short of orbit while a steel two-stage probe
reaches it; the cargo hauler needs its boosters; six boosters on a crew
rocket still fall short of the Moon.

## Building

Rockets are no longer a single recipe. With Orbital Flight researched, a
rocket works (`code/modules/space/rocket_works.dm`) takes a rocket sheet
and steel, aluminium, copper and electronics, and builds the sheet's
sections one at a time in the sheet's frame, each onto a floor tile beside
it. A launch stand placed beside a launch pad takes the same sheet and
mounts the sections bottom-up, refusing any section out of order. Every
`ROCKET_STOREY_SECTIONS` sections make a storey: storey 2 and up mount from
the level above the stand (open sky over it), so upper sections are hauled
up with shear legs or a tower crane (`hoist_only_types`). Where the world
has fewer levels, the remaining storeys mount from the highest level.

The finished stack is a modular rocket on the stand's tile. It takes the
sheet's propellant and seats, shows the launch planner on examine, flies
only to orbit for now, and refuses to launch until the orbit leg is reached
with what is actually in its bays. A crew that cannot come home is warned
before launch.

## Reuse and wear

Reuse belongs to each section (`code/modules/space/rocket_reuse.dm`), never
to the whole rocket. Every section keeps its condition, its flights and
whether it was inspected since its last flight. A stand refuses a section
below `ROCKET_SECTION_MIN_CONDITION` or one not inspected.

- Engines, tanks, decouplers, boosters and bays are spent at launch in 1969.
- A crew capsule with a heat shield directly under it and parachutes over it
  carries its record (`capsule` payload field) to orbit and home. A capsule
  in orbit without them cannot deorbit. Coming home, landing rockets under
  the shield set it down on dry ground (wear 10); parachutes alone splash it
  down off the nearest shore, where it is towed in (wear 15), or land it hard
  with no water near (wear 40). The heat shield burns away, the parachutes
  come back to be repacked and the landing rockets come back worn.
- From 2013 (`ROCKET_FLYBACK_AGE`) landing legs in the first segment fly the
  first stage back beside the stand (wear 20 per section), at the cost of the
  10% of its propellant it keeps to land (`ROCKET_FLYBACK_RESERVE`).

A wrench inspects a section. Steel sheets restore frames and capsules (4%
per sheet), an engine overhaul kit (Orbital Flight) restores an engine, and
10 cloth repack parachutes. Every repair needs a new inspection. Nothing is
random.
