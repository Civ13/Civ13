# Orbit world

```
python3 tests/orbit_world/run.py --byond-bin <pinned bin> --output <empty directory>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless on an 8 x 8 x 5 vacuum world with the orbit map settings. It
checks the plane registry (made on plane 1, arrival plane owned and never
released), claims taking the lowest free plane, links both ways and refusing
a side already taken, `multiz_level_above/below` following deck links, a
seam moving an item to one tile inside the linked neighbour and leaving it at
an unlinked edge, ladders pairing across linked decks, the sparse save kind
(`orbit` for every plane but the first, with a vacuum baseline), the durable
profile, and release cutting every link.

It also checks orbital flight (`code/modules/space/orbital_flight.dm`): orbit
opens in 1969, a launch pad may lead to it and a trail never does, the
two-stage rocket (3 seats, 10 cargo, 600 propellant) flies only to orbit and
refuses a full orbit while a lander cannot reach it, the Orbital Flight node
gates the rocket, orbit payloads are well formed, a refused flight builds
nothing, the first arrival claims the lowest free plane and builds the capsule
in its middle and the rest of the crew join it, the 3 x 3 deck is breathable
inside and vacuum outside, a home bunk held by someone not aboard keeps the
capsule from deorbiting, a spent capsule turns its deck back to vacuum,
removes its bunk and releases an empty plane but keeps one with something
left on it, a full orbit puts the capsule on the arrival plane clear of the
edges, and the deorbit hatch carries a flight home and catches no arrivals.

It also checks EVA (`code/modules/space/orbit_eva.dm`): a truss is a handhold
and open space is not, both EVA recipes are gated on Orbital Flight, stepping
off a handhold drifts and refuses steering, a drift crosses a linked edge and
catches hold near a truss, an unlinked edge stops a drifter who then cannot
push off, a still floater away from the edges pushes off again, and the safety
tether clips to a truss, is not saved, pulls a drifter back at its reach, lets
the wearer haul toward the clip but not push away, and unclips.

Not covered: a real save and restore of an orbit world, connected clients,
seams crossed by players, the drift loop itself (it needs clients; the probe
drives each step), and a full launch and deorbit through the transfer
agent (the travel path is the existing crewed-flight one).
