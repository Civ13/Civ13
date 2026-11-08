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

It also checks the station hardware (`code/modules/space/orbit_station.dm`):
the orbital day turns at sunset and sunrise and repairs a bad count, orbit is
-100 C with no dust storms, the solar wing and any panel follow the orbital
day, the fuel cell needs both hydrogen and oxygen, sunlight and working
machines warm a module and radiators add none, an unpowered radiator idles,
the orbital workshop unfolds sealed with two bunks, a table and a crate,
debris breaches it to vacuum and the breach can be patched, and all four
recipes are gated on Orbital Flight.

It also checks starter stations (`code/modules/space/orbit_project.dm`): the
launch complex office needs an approved orbit pad and 1969, allows one project
per party, completes on delivery, refuses a full orbit until the party has
boarded, and is where members land coming home; the first arrival founds the
station on a free plane with three sealed modules (the workshop hub in the
middle, quarters docked east with two bunks, the airlock south), the heater,
scrubber and radiator on the hub's grid with its doorways clear, a porch
truss outside the outer hatch, two generating solar wings on a truss cross
boom, a fuelled fuel cell and the thruster at the aft end of a keel whose
every tile is a hold point, the console, crate and return hatch in the
workshop and stowed supplies; later members board at the hatch, which flies
home; the console names the owner and recovers a drifter lost at an unlinked
edge; and a full orbit founds nothing. The world grows to 28 x 28 for the
station layout.

Last, it checks Moon gear (`code/modules/space/lander.dm`): a lander keeps a
150-unit ascent reserve and a rocket none, only a full tank is a sortie, the
`sortie` payload flag is 1 and only rides a landing flight, a landed lander
without the reserve cannot lift off and one with it can, a spent lander turns
its deck back to regolith, and the lunar kit flies in the hold, is gated on
Crewed Flight and unpacks two suits and four tanks.

Then module pods (`code/modules/space/orbit_pods.dm`): a kit released as a pod
lands three tiles ahead and answers to the party; footprints refuse hulls,
plane edges and other pods; outsiders cannot steer, dock or fold; each step
costs propellant; a ram stops and damages the pod; one burn at a time; a hard
dock unfolds a furnished, sealed module with a shared hatch; folding refuses
an open hatch, someone else inside, cables or a homed bunk; a fold keeps the
furniture and air, seals the neighbour's wall and opens the site; the folded
pod docks again without new furniture; and the console steers member pods
only.

Last come decks (`code/modules/space/orbit_decks.dm`): a node's deck hatch,
an open hatch to nothing as a breach, outsiders refused, a deck built above
on a station plane and linked in the registry, the hatches pairing, no air
through a shut hatch and shared air through an open shaft, one deck each way,
no deck without a free plane, node fold refusals, the console reporting every
deck, and cable risers pairing across the deck link.

Then upkeep (`code/modules/space/orbit_upkeep.dm`): the starter station's
fuelled thruster, decay with play and through the hazard clock, no heat in
low orbit, drag and skim heating, the floor and ceiling, thruster refusals
for no propellant, outsiders and the ceiling, a reboost and its cost, and the
console's altitude line.

Last, the 2013 layout on a 32 x 32 world: five sealed modules with the node
hub in the middle (its deck hatch and doorways clear, life support in its
corners) and the workshop, greenhouse, quarters and airlock on its four
sides, the return hatch, bench, crate and console in the workshop, two
tracking arrays generating 35 PU, the radioisotope generator on the keel
grid and steady in the shade, the fuel cell and thruster aft, six reboost
burns, a node kit in the crate, recipe gates, and no isotope power before
2013.

Then wear (`code/modules/space/orbit_wear.dm`): a scrubber using up its
sorbent and stopping when empty, a cartridge refilling it, two spare
cartridges in the starter crate, solar wings wearing only in sunlight down to
half output, a glass repair, and the cartridge recipe gate.

Not covered: a real save and restore of an orbit world, connected clients,
seams crossed by players, the drift loop itself (it needs clients; the probe
drives each step, and each pod step), and a full launch and deorbit through the transfer
agent (the travel path is the existing crewed-flight one).
