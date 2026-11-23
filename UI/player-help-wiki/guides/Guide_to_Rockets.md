# Rockets

From 1969 a rocket is not a single recipe. You design one around a mission on a rocket sheet, build its sections at a rocket works, and stack them on a launch stand beside a launch pad. The parts you choose decide what it can do: reach orbit and bring a crew home, haul heavy cargo up to your station, or send a probe to the Moon.

Everything here is in the crafting menu's **spaceflight** section, unlocked by **Orbital Flight**. Rockets burn rocket propellant or methalox (see [The Moon & Mars](Guide_to_the_Moon.md#rocket-propellant)).

## Designing a rocket

Craft a **ship's draught** (1 softwood, in the paper & printing section) and use it in hand: choose **Draw a rocket on the sheet**. The rocket designer opens. Stack pieces from the bottom up and pick a frame and a number of boosters. The **launch planner** beside the drawing updates as you go. It lists every leg of a flight, whether your rocket can fly it, and what is missing when it cannot.

A rocket sheet can be exported as a code and imported on another land, but every land still has to build and fly the rocket itself.

### Pieces

| Piece | What it does |
| --- | --- |
| **Sea-level engine** | Lifts the rocket off the pad. Put one or more at the bottom of the first stage. |
| **Vacuum engine** | Efficient but weak, so it cannot lift off. Use it at the bottom of an upper stage. |
| **Propellant tank** | Fuel for the engines of its stage. Its frame sets how much it weighs. |
| **Decoupler** | Ends a stage: everything below it drops away when that stage is empty. |
| **Service module** | A small engine with its own fuel that rides with the capsule and burns last. |
| **Crew capsule** | Three seats and a small hold. |
| **Cargo bay** | Carries up to 20 hold items. |
| **Probe bus** | An uncrewed probe with cameras and a radio. |
| **Heat shield** | Goes directly under the capsule. It survives a return from orbit. |
| **Heavy heat shield** | Goes directly under the capsule. Thick enough for a return from the Moon. |
| **Parachutes** | Go directly over the capsule. They bring it down in water near where the crew land. |
| **Landing rockets** | Go directly under the heat shield. They set the capsule down softly on dry ground. |
| **Landing legs** | Go at the bottom of the top stage, for anything that lands on the Moon. |

**Boosters** (0, 2, 4 or 6) burn alongside the first stage. They get a heavier load off the pad, but they do not carry it much farther.

**Frames.** Tanks, decouplers, capsules, bays and probes are built in a **steel** or **aluminium** frame. Steel is cheap but heavy: a steel frame can put a small probe in orbit but struggles with a crew capsule. Aluminium is lighter and lets the same engines go farther.

### Legs

The planner checks each leg separately, so a rocket can reach the Moon but not land on it, or reach orbit with no way home.

| Leg | What it needs |
| --- | --- |
| Lift off | Enough thrust for the rocket's weight on the pad |
| Reach orbit | Enough speed from every stage together |
| Come home from orbit | A capsule with a heat shield under it and parachutes over it |
| Lunar transfer | More speed again, usually from an upper stage |
| Land on the Moon | Still more speed, and landing legs in the top stage |
| Come home from the Moon | A heavy heat shield and parachutes |

Every rocket must lift off and reach orbit. What it carries counts: a full cargo bay weighs more than an empty one, so the planner on a built rocket uses what is actually in its hold.

### Starter rockets

A new sheet opens with a crew orbiter drawn. These three designs each fly one of the first missions. Import a code on a sheet to start from it:

| Rocket | Mission | Code |
| --- | --- | --- |
| **Crew orbiter** | Three crew to orbit and home again | `C13ROCKET/1/crew_orbiter/a/0/ETTTDVTXCRM` |
| **Cargo hauler** | Two full cargo bays to orbit on four boosters, no crew | `C13ROCKET/1/cargo_hauler/a/4/EETTTTDVTTTKK` |
| **Lunar probe** | A probe to the Moon's surface, one way, on three stages | `C13ROCKET/1/lunar_probe/a/0/EETTTDVTTDVTGQ` |

The biggest rocket is not always best: six boosters still will not reach the Moon, and a crew capsule on a steel frame will not reach orbit.

## Building a rocket

1. Build a **rocket works** (60 electronics). Use your rocket sheet on it to give it the order, then stock it with steel, aluminium, copper and electronics. Use it to build the next section; each one comes out beside it, in order, and the menu shows what the next piece costs.
2. Build a **launch pad** (40 steel), and a **launch stand** (40 steel) beside it. Give the stand the same sheet.
3. Drag each section onto the stand, bottom first. The stand refuses a section that is out of order.
4. Every four sections make a storey. From the second storey up, the next sections must be mounted from the level above the stand. Lift them up with **shear legs** or a **tower crane**, and keep the space over the stand open. On a land without enough levels, the top storeys mount from the highest level.
5. When the last section is on, the stack is a finished rocket. Fill it with propellant and examine it to see its launch planner.

To take the top section down again, use the stand.

## Missions

What a rocket does at launch follows what it carries.

### Crewed flights

A rocket with a **crew capsule** flies its crew to orbit. Strap in on the rocket's tile, point the pad at orbit and launch. As with any rocket to orbit, choose a free docking port on a station that welcomes you, or open orbit (see [Space Stations](Guide_to_Space_Stations.md#docking-a-rocket-at-a-station)). If the planner says the crew cannot come home, you are warned first: they can then only come down from a station.

### Heavy cargo launches

A rocket with **cargo bays and no capsule** carries cargo, not crew. Load its bays, point the pad at orbit and launch it. The cargo lands in a freight crate beside your party's station hatch. You need a party and a BYOND account to launch it, and the planner must show the orbit leg with the bays loaded.

### Lunar probes

A rocket with a **probe bus and no capsule** sends a probe to the Moon. It needs:

- the orbit, lunar transfer and landing legs on the planner,
- an idle **mission console** within 7 tiles of the rocket.

The probe lands anywhere flat. Its landing is recorded at the console as a **surveyed site**, which a crewed lander can choose as a safe place to set down. Drive the probe from the console to map the Moon (see [Probe missions](Guide_to_the_Moon.md#probe-missions)). It has no ascent stage, so it never comes home and takes no samples: abandon the mission when you are done.

## Reuse and wear

Each part wears on its own. The whole rocket never has a fixed number of flights.

- Engines, tanks, decouplers, boosters, bays and probes are used up at launch.
- A **crew capsule** with a heat shield and parachutes comes home with its crew. Where it lands decides how worn it is:
  - **Landing rockets** set it down softly on dry ground. This is the least wear.
  - With **parachutes alone** it splashes down off the nearest shore and is towed in.
  - With no water nearby it **comes down hard** and wears the most.
- The heat shield burns away. The parachutes come back to be repacked, and the landing rockets come back worn.
- From **2013**, **landing legs on the first stage** fly it back beside the stand after it separates. It keeps a little propellant to land, so the rocket goes slightly less far.

Every section that comes back must be **inspected** with a wrench before it flies again. A stand will not mount a section that is badly worn or not inspected.

| Repair | With |
| --- | --- |
| Frames and capsules | Steel sheets |
| Engines | An **engine overhaul kit** (30 steel) |
| Parachutes | 10 cloth |

After any repair, inspect the section again.
