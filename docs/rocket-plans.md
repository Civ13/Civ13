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
