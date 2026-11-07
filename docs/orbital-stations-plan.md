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
| 4 | Orbital flight: Orbital Flight node, two-stage rocket, launch pads to orbit, capsule shelter with bunk, deorbit home | `code/modules/space/orbital_flight.dm`, `lander.dm` |

## Next

5. EVA in orbit: drift, handholds, tethers, truss.
6. The 1969 station and the launch complex office project.

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

## Tests

`python3 tests/orbit_world/run.py --byond-bin <pinned bin> --output <empty directory>`
checks the registry, claims and quotas, deck and sector links, the multiz
helpers, seams, ladder pairing, the sparse save kind, the durable profile,
release, and orbital flight (rocket, capsule arrival, deorbit refusals and
spending).
