# Orbital stations

Val approved this plan on 2026-11-07. The full design, the review and the
13-step PR plan are in the project's planning document. This page records
what the code does so far and the rules later steps must keep.

## Rules

- **Orbit is its own region**, shard kind `ORBIT`. It is never the mainland,
  and trail markers never offer it. It is reached only by rocket.
- **The planes are compiled, not grown.** `maps/space/orbit.dmm` is 24 planes
  of 64 x 64 vacuum (98,304 cells). Nothing resizes the world at runtime, so
  `world_z_budget` and its 32-level and 8-added-level limits are not involved.
- **The plane registry hands out planes** (`code/modules/space/orbit_world.dm`).
  Plane 1 is the arrival plane, owned by `arrival`, and is never released. A
  station owner holds at most 6 planes. Planes link `up`, `down`, `north`,
  `east`, `south` and `west`, always both ways.
- **Levels follow the graph.** On an orbit world, `multiz_level_above()` and
  `multiz_level_below()` answer from the registry, so ladders, stairs and
  cable risers follow the deck links.
- **Edges are seams.** Something unanchored that steps onto an edge turf with a
  linked neighbour on that side arrives one tile inside the matching edge of
  the neighbour. BYOND does not draw across z, so the seam is visible.
- **Saves.** Plane 1 saves in full and holds the registry. Every other plane
  saves sparsely against vacuum (sparse kind `orbit`), so an empty plane costs
  almost nothing. The registry's fields are text keys with number or text
  values, so nothing cross-level is saved.
- **Durable profile.** `/obj/map_metadata/nomads/orbit` is listed in
  `durable_nomads_profiles()`.
- The region describes `free_planes` to its peers, so a launch office can
  refuse before launching into a full orbit.

## Built

| Step | What | Where |
| --- | --- | --- |
| 1-2 | Cable risers and bus tie switches; ladders and stairs through `multiz_level_*` | #3902, `code/modules/1713/machinery/cable_risers.dm` |
| 3 | Orbit world skeleton: kind, vacuum, area, metadata, map, plane registry, seams, sparse saves | #3909, `code/modules/space/orbit_world.dm`, `maps/space/orbit.dmm` |
| 4 | Orbital flight: Orbital Flight node, two-stage rocket, launch pads to orbit, capsule shelter with bunk, deorbit home | #3916, `code/modules/space/orbital_flight.dm`, `lander.dm` |
| 5 | EVA in orbit: handholds, push-off and drift, truss, safety tether, lost drifters at unlinked edges | #3933, `code/modules/space/orbit_eva.dm` |
| 6a | Station hardware: orbital day, module heat, fixed solar wing, fuel cell, radiator, orbital workshop, debris breaches | #3934, `code/modules/space/orbit_station.dm` |
| 6b | Starter stations: launch complex office project, 1969 station founded on a free plane, return capsule hatch, orbit console with lost-drifter recovery | `code/modules/space/orbit_project.dm`, `party_train.dm` |
| 6c | Moon gear: lunar surface kit, sortie reserve and lift-off home from a landed lander | `code/modules/space/lander.dm` |
| 8 | Module pods and docking: release a kit as a pod, RCS steering from the pod or an orbit console, hard dock, fold back, party checks, rams | #3948, `code/modules/space/orbit_pods.dm` |
| 9 | Decks: node modules, deck hatches, building a deck above or below, shared air between decks, console over every deck | #3949, `code/modules/space/orbit_decks.dm` |
| 10a | Upkeep: orbit decay by band, drag heating and strikes, reboost thruster, altitude on the console | #3952, `code/modules/space/orbit_upkeep.dm` |
| 10b | 2013 layout and hardware: tracking solar array, radioisotope generator, bigger starter station | #3956, `orbit_station.dm`, `orbit_project.dm` |
| 10c | Wear: scrubber sorbent beds and cartridges, solar cell wear and glass repairs | #3959, `code/modules/space/orbit_wear.dm` |
| 11 | Sectors outward (2026): sector beacon claims a plane at an edge, edge couplers carry power across the seam, seam margins for modules and pods | `code/modules/space/orbit_sectors.dm` |

## Next

7. Live: the first orbit region (Val set it up on 2026-11-07).
12. Reusable launch: booster condition and refurbishment, crew ship, the 2026
    starter layout.
13. Wider network: shuttles between orbit, the Moon and Mars; station radio.
10d. The uncrewed cargo freighter. It needs items to cross regions without a
    traveller, which the transfer agent cannot do yet, so it waits for that
    infrastructure. Seal and battery wear wait for a reason to exist (seals
    already fail through breaches and strikes).

## Orbital flight

- **Orbit opens in 1969** (age 7), like the Moon. A launch pad may lead to an
  orbit region; trails never do. Orbit needs no survey map.
- **The two-stage rocket** is a crewed lander subtype: 3 seats, 10 cargo
  items, 600 units of propellant, gated on Orbital Flight (after Crewed
  Flight). It flies only to orbit, and a lander cannot reach orbit. It refuses
  to launch when the orbit region last reported no free plane.
- **The capsule** is built by the first arrival of a flight. It claims the
  lowest free plane (owner `capsule:<flight id>`) and sits in its middle; when
  every plane is taken it shares the arrival plane at a clear spot away from
  the edges. It is a landed lander subtype: a 3 x 3 sealed deck, about three
  hours of air and power, one claimable bunk, vacuum cold outside and no dust
  storms.
- **Deorbit.** Crew strap in on the capsule's tile and deorbit; they travel
  home to the mainland's ordinary arrival point as a flight home. A capsule
  will not deorbit while someone else is in its cabin or keeps its bunk as
  home. The capsule is then spent: its deck turns back to vacuum, its bunk
  goes, and its plane is released only when nothing else stands on it.
- Landing home beside a launch pad, and docking a capsule to a station, come
  with the station steps.

The arrival plane's `JoinLateCiv` landmark is a fallback for travellers who
arrive with no capsule. A live orbit region still needs Val's rollout step.

## EVA in orbit

- **Handholds.** On vacuum a person moves freely only while something to hold
  is within one tile: any ground that is not vacuum (a capsule deck, a
  habitat floor or hull), a truss, or any anchored or solid structure.
  Ordinary ladders already link decks through the plane registry.
- **Drift.** Stepping away from the last handhold pushes off: the person
  drifts on in that direction one tile every 0.4 seconds, cannot steer, and
  stops when a handhold comes within reach or something blocks them. A drift
  across a linked plane edge carries on into the next plane.
- **Lost drifters.** A drift into an unlinked edge stops there with nothing in
  reach. The drifter stays until recovered or until their air runs out
  (recovery from an orbit console comes with the station step).
- **Truss** (2 steel) is an anchored open frame to hold. The **safety tether**
  (1 steel, belt or hand) clips to a handhold within reach. Clipped, a drift
  stops at seven tiles and pulls back to the clip, and the wearer can haul
  themselves back toward it. Crossing a plane edge unclips it. Both are gated
  on Orbital Flight.
- Drifting is a process-local loop: it never saves, stops while the world is
  empty and wakes on the next move. A tether's clip is not saved either. A
  person restored mid-drift can push off again, unless lost at an edge.

## Station hardware

- **Orbital day.** Each orbit is 20 minutes of sunlight and 10 of shade. The
  registry keeps whether the station is sunlit and the seconds left as plain
  numbers; the clock only counts while the world has players, and no call
  counts more than 10 seconds at once. Sunrise and sunset are announced in
  orbit.
- **Heat.** A module in orbit cools slowly to the -100 C of space, gains
  0.15 C a second from the sun while sunlit, and gains heat from every
  machine working inside it (its power draw). Heaters carry it through the
  shade; radiators shed what is above room temperature. Orbit has no dust
  storms or cold snaps; solar flares still happen.
- **Solar.** Any solar generator in orbit follows the orbital day and
  ignores the weather. The **fixed solar wing** (20 PU) is the orbit panel.
- **Fuel cell** (15 PU) burns hydrogen and oxygen poured into it and keeps
  the water it makes, which a container can draw off.
- **Radiator**, a cabled life support machine inside a module.
- **Orbital workshop kit**, a 5 x 5 module with two bunks, a workbench and a
  crate: the first module of a 1969 station.
- **Debris** strikes hull modules in orbit as meteorites do on Mars, leaving
  a breach to vacuum that a hull patch kit closes.
- All of it is gated on Orbital Flight.

## Starter stations

- **The launch complex office** (40 steel, Orbital Flight) is a project like
  the party train. Built within 3 tiles of a launch pad approved for an orbit
  region, from 1969, a party starts it and delivers 180 steel, 40 glass, 40
  copper and 60 electronics. One project per party. Members then fly up from
  the office; it refuses when orbit has no free plane, unless the party has
  already flown up.
- **The station** is founded by the first member to arrive: it claims a free
  plane (owner `station:<party>`) and builds the starter layout in the middle:
  a hub with arms and a keel. The hub holds the heater, scrubber and radiator
  in its corners, so with the hatches open it serves every arm one hop away,
  and its doorway tiles stay clear. The workshop arm holds a bench, the orbit
  console, the return capsule hatch and a crate with two pressure suits and
  helmets, two air tanks, two hull patch kits, a suit patch, two tethers,
  cable, two sorbent cartridges, six rations and three canteens. The airlock
  arm points south; outside its outer hatch a truss keel carries the cable
  spine, a cross boom with a solar wing at each end, a fuelled fuel cell (off,
  for the shade) and the reboost thruster at the aft end. Every piece of
  outside hardware stands on or beside the truss, so a suited crew member
  reaches it hand over hand without drifting.
- **In 1969** the hub is the workshop itself (the machines take its top row,
  the bench stands beside the core), quarters with two bunks dock east, the
  wings are fixed and the thruster holds three burns.
- **From 2013** the hub is a node module whose deck hatch is ready for a
  second deck, with the workshop east, a greenhouse west, quarters north and
  the airlock south. Tracking solar arrays replace the fixed wings, a
  radioisotope generator joins the keel, the thruster holds six burns and the
  crate adds a node module kit. The deliveries are the same.
- **The return capsule hatch** takes members home to their office, like a
  train berth. The station is the plane its party owns in the plane registry;
  members keep their party in orbit as they do in the rail yard. Later members
  arrive at the hatch; if no plane is free, they arrive at the orbit's arrival
  point.
- **The orbit console** (20 electronics, Orbital Flight) shows the owner, the
  orbital day and each module's pressure, temperature and breaches, and
  recovers lost drifters: anyone stuck at an unlinked plane edge is reeled in
  beside it after 10 seconds. A console on a station plane only lets that
  party recover.
- The 2026 layout comes with stage D.

## 2013 hardware

- **Tracking solar array** (25 electronics): 35 PU in orbital sunlight,
  nothing in the shade. Runs from 2013.
- **Radioisotope generator** (40 electronics): a steady 10 PU through
  sunlight and shade with nothing to feed. Runs from 2013.
- Both are gated on Orbital Flight.

## Moon gear

- **Sortie.** A crewed lander's tank holds its 300-unit flight plus a
  150-unit ascent reserve. Launched to the Moon or Mars with a full 450, the
  flight is a sortie (payload flag `sortie`): the landed lander keeps the
  ascent, and its crew strap in on its tile and lift off home to the
  mainland, spending it. Without the reserve the landed lander is a shelter
  only, as before. A capsule in orbit uses the same lift-off as its deorbit.
  A spent lander's deck goes back to regolith.
- **Lunar surface kit** (40 steel, Crewed Flight) flies in the hold and
  unpacks into two pressure suits and helmets, four air tanks, a suit patch,
  a rover battery, six rations and four canteens.

## Module pods and docking

- **Pods.** In orbit, using a module kit asks whether to unfold it where you
  stand or release it as a pod. A pod appears three tiles ahead of you and
  answers to your party. It has a 5 x 5 footprint (the module it becomes),
  which it checks itself: it keeps two tiles off the plane edge, out of other
  pods' footprints and off any hull or solid object.
- **RCS.** A pod moves one tile at a time on rocket propellant, up to 8 tiles
  per burn, steered from the pod itself or from an orbit console within 12
  tiles. Each tile costs one unit; a kit pod starts with 20 and the tank holds
  60. A pod that runs into something stops and its frame takes 25 damage; at
  0 its thrusters are wrecked until two steel sheets brace it. The hull it hit
  is unharmed, so pods are not battering rams. A burn in progress is never
  saved.
- **Docking.** Steer the pod until its centre is four tiles straight out from
  a module core, then hard dock it with a wrench (5 seconds). It unfolds in
  place: the shared wall's middle becomes a hatch, opening it equalises the
  two modules, and cable runs through it as on any module.
- **Folding back** (wrench on the core, 10 seconds) is the undock. Every
  hatch must be shut, nobody else may be inside, no cable may run through the
  module and no bunk in it may be someone's home. Machines, furniture, items
  and air go into the pod; the neighbour keeps the shared wall, sealed. A
  folded pod has an empty RCS tank and does not get new furniture when it
  docks again.
- **Parties.** On a station plane only that station's party may steer, dock
  or fold. A released pod answers only to the party that released it.

## Decks

- **Node module kit** (70 steel, Orbital Flight): a module with a deck hatch
  in its floor, south-east of the core.
- **A new deck.** Open a node's deck hatch and use a node module kit on it.
  This claims a free plane for the station's party, links it above or below
  in the plane registry and unfolds a node there at the same spot. Only the
  station's party can do it, and the station quota of 6 planes holds.
- **The shaft.** Two nodes at the same spot on linked decks join through
  their deck hatches. People climb through while both are open, and the two
  modules share their air like modules behind an open side hatch. An open
  deck hatch with nothing beyond it is a breach.
- **Power** crosses decks with cable risers, which follow the same links.
- **Folding** a node needs its deck hatch shut and no deck joined through it.
- The orbit console reports the modules on every deck of its station.

## Upkeep

- **Orbit decay.** The registry keeps each station's altitude in km, keyed
  by party. It starts at 400 and falls about 30 km an hour, only while the
  world has players, on the space hazard clock, down to 150 km at worst.
- **Bands.** Below 300 km the station is warned. Below 250 km drag heats
  every module 0.05 C a second and adds a 20% chance a minute of a debris
  strike. Below 200 km the station skims the atmosphere: 0.2 C a second and a
  50% chance a minute. Nothing is ever deleted, and the crew is told each
  time the station crosses a band.
- **Reboost thruster** (25 electronics, Orbital Flight): fill it with rocket
  propellant (tank 200). Each burn takes 20 units and climbs 20 km, up to
  420 km. Only the station's party can fire it. A starter station comes with
  one holding three burns.
- The orbit console shows the altitude and what it means.
- **Sorbent.** In orbit, each CO2 scrubber uses up its sorbent bed as it
  works (one percent per 10 kPa-tiles of CO2 removed, a little under three
  hours of steady scrubbing). An empty bed stops the scrubber. A sorbent
  cartridge (4 plastic, Life Support) refills it; a starter station's crate
  holds two. Ground, Moon and Mars habitats are unchanged.
- **Solar cell wear.** Wings and arrays in sunlight lose 3% output an hour,
  down to half. Two glass sheets replace the worst cells (25 points). Wear
  counts on the hazard clock, so nothing wears while the world is empty.

## Sectors

- **Sectors open in 2026** (age 9). A sector is another plane linked at a
  cardinal edge of a station plane, on the same deck. The station quota of
  6 planes counts decks and sectors together.
- **Sector beacon** (15 electronics, Orbital Flight): stand within 4 tiles
  of an unlinked edge of your party's plane and use it. After a short setup
  it claims a free plane, links it there and is used up. Outsiders, a full
  quota, a full pool and a running save refuse it.
- **Crossing.** Walking or drifting off a linked edge arrives one tile
  inside the matching edge of the sector (the existing seams).
- **Edge coupler** (4 copper, Orbital Flight): a cable riser for seams.
  Secure one on a cable one tile inside a linked edge, and another at the
  matching spot across the seam, and the cables on both tiles share one
  grid. Couplers already in place join when the sector is claimed. Plain
  risers ignore couplers.
- **Seam margins.** In orbit, modules and pods keep two tiles clear of every
  edge, so nothing stands on a seam or on the tile where travellers arrive.

## Tests

`python3 tests/orbit_world/run.py --byond-bin <pinned bin> --output <empty directory>`
checks the registry, claims and quotas, deck and sector links, the multiz
helpers, seams, ladder pairing, the sparse save kind, the durable profile,
release, orbital flight (rocket, capsule arrival, deorbit refusals and
spending) and EVA (handholds, push-off, drift across a seam, catching hold, an
unlinked edge, the tether's pull, haul and clip) and station hardware (the
orbital day, solar and fuel cell output, module heat, radiators, the
workshop's furnishing and debris breaches) and starter stations (office
placement, era and delivery, full-orbit refusal, founding, power, supplies,
boarding, the hatch home and console recovery), Moon gear (the sortie
reserve and payload flag, lift-off and spending, the lunar kit) and module
pods (release, footprint, steps, rams, party checks, hard dock, fold refusals,
folding back and docking again, console steering) and decks (the node's
hatch, building a deck above, pairing, breaches, shared air, refusals,
console reports and risers) and upkeep (decay, the hazard clock, bands,
drag heating, floor and ceiling, the thruster and the console) and the 2013
layout (four sealed modules, tracking arrays, the isotope generator in sun
and shade, six burns, the node kit and the era gate).
