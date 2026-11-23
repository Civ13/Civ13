# The Moon & Mars

The Moon is its own land in the region group: a grey, airless world under a black sky. From 1969 any party can map it with survey probes, fly a crew there in a lander, and settle in sealed habitats. Mars works the same way and opens in 2026.

Nothing walks there. A trail marker only joins lands on the same world, so no trail on Earth leads to the Moon or Mars, and trails on the Moon only join other Moon lands. The only way up is a rocket from a launch pad.

## When it opens

| World | Opens | Conditions |
| --- | --- | --- |
| The Moon | 1969 (Cold War) | No air, no weather, -100 C in the open, darker crater floors, shadowed ice |
| Mars | 2026 (Digital Age) | Thin unbreathable air, -60 C, dust storms |

Your world has to reach the era first, and the research below needs a tier 7 research bench. A bench can't be upgraded past the current era. A flight home is never closed by the era.

## Research

Everything here is in the crafting menu's **spaceflight** section.

| Node (Industrial) | Unlocks |
| --- | --- |
| **Rocketry** (after Aviation & Rocketry) | Launch rail, survey probe, mission console |
| **Planetary Survey** (after Rocketry) | Advanced survey probe; sample analysis gives research notes |
| **Crewed Flight** (after Planetary Survey) | Launch pad, crewed lander, lunar surface kit |
| **Sealed Habitats**, **Life Support**, **Pressure Suits** | Habitat modules, air machines and suits, see [Space Stations](Guide_to_Space_Stations.md) |
| **Off-world Mining**, **Surface Vehicles**, **Local Resources** | Regolith mining, ice melter, rovers, propellant plant |

## Rocket propellant

Every rocket burns **rocket propellant**, mixed from **2 parts hydrazine and 1 part nitric acid**. See [Chemistry](Guide_to_Chemistry.md) for the reagents.

| Craft | Propellant |
| --- | --- |
| Survey probe on a launch rail | 60 |
| Crewed lander, one way | 300 |
| Crewed lander with fuel kept for the flight home | 450 |

## Probe missions

A probe maps a world from the mission console without anyone leaving home.

1. Build a **mission console** (20 electronics) and a **launch rail** (30 electronics) within 7 tiles of it.
2. Load a **survey probe** (25 electronics) or an **advanced survey probe** (35 electronics) onto the rail and fill the rail with 60 units of rocket propellant.
3. Use the console. While no probe is flying it lists every rail in reach. Choose **Destination** to pick the Moon (or Mars), **Aim** to pick a landing cell, then **Launch**. An aimed probe lands on flat ground within 2 cells of the aim; with no aim it lands anywhere flat. You can also do all of this at the rail itself.
4. Drive the probe from the console. Moving costs battery: 1 on plains, 2 in channels (rilles on the Moon), 3 on ice, and ridges block the way. The battery slowly recharges while the mission runs. The probe must stay within relay range of its landing site.
5. **Photograph** new sites and **Sample** the ground. **Ascend** from the landing site to bring the samples home as items, then hand them to the console to turn them into research notes.

| Probe | Battery | Relay range | Samples | Sight |
| --- | --- | --- | --- | --- |
| Survey probe | 100 | 12 cells | 3 | 1 cell |
| Advanced survey probe | 160 | 18 cells | 5 | 2 cells; its relay never drops a command |

The console keeps a separate survey record for each world, and every probe landing site becomes a **surveyed landing site** for crewed flights.

A rocket built with a probe and enough stages to land on the Moon can also fly a one-way probe from a console within 7 tiles of it. That probe maps the Moon and marks its landing site, but it never ascends or brings samples home (see [Rockets](Guide_to_Rockets.md#lunar-probes)).

## Flying a crew there

1. Build a **launch pad** (40 steel) and use it. Choose **The Moon** (or Mars). The pad is ready at once, and you can use it again to change where it flies.
2. Build a **crewed lander** (60 electronics) beside the pad and fill it with rocket propellant: 300 units to get there, or 450 to keep enough for the ascent home.
3. Pack what you need. Each crew member flies with what they wear and carry. The lander's hold takes up to 20 items of space gear and building stacks (habitat kits, suit tanks, glass, plastic, electronics, ice). A **lunar surface kit** (40 steel) holds two pressure suits and helmets, four air tanks, a suit patch kit, a rover battery, and food and water for two people for three days.
4. Up to four people stand on the lander's tile and choose **Strap in**. One of them chooses **Launch** and picks a landing site.
5. A **surveyed site** (from a mission console within 7 tiles of the lander) is safe. **Anywhere flat** works without a survey, but half of those landings are rough and hurt everyone aboard.

The crew arrive inside a landed lander: a 3 x 3 sealed cabin with air, heat and power for three hours, and a bunk you can claim as your home bed. After that you need your own habitat modules, suits and life support, built the same way as on a [space station](Guide_to_Space_Stations.md).

## Living there

- **Outside is deadly.** There is nothing to breathe and the cold is extreme. Wear a pressure suit, helmet and an air tank, and patch tears with a suit patch kit.
- **Hazards:** cold snaps, solar flares that irradiate anyone in the open, and meteorites that can hole a module (patch it). Mars also has dust storms; the Moon has none.
- **Water:** sinks, wells and plain showers are dry. Melt ice from the ground in an **ice melter**, reclaim water with a **water recycler**, and pipe it to taps and showers.
- **Mining:** drills and a regolith rig bring up off-world ore and ice.
- **Rovers:** build sealed electric rovers in a rover assembly bay and charge them at a rover charger. Fuel engines need air and won't run here.
- **Propellant:** a **propellant plant** cracks ice into rocket propellant, so a settlement can fuel its own landers.

## Coming home

A lander filled to 450 units keeps enough for one ascent. Otherwise build a launch pad and a new lander on the Moon and fill it there. A flight home from the Moon or Mars always lands at the mainland's arrival point.
