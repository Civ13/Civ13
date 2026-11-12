# Turf-built vessels: the aircraft carrier

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. The fixture world is 70x60 with three levels: cave rock on z1, deep saltwater on z2 and open air (`/turf/sky/building`) on z3, standing in for Gaia's cave level, surface and standing building level.

The probe covers phase 1 of the carrier (`code/modules/naval/`):

- **Flooding controllers:** a bare `/datum/flooding_controller` is still the Submarine Commander global; a deck tile outside any vessel reports to it; a vessel's controller is its own, is ticked from `flooding_controllers`, and keeps a breached compartment's air pocket.
- **Laying down:** `carrier_lay_down()` writes 342 hangar-deck cells (hull, bulkheads, six compartments with a blast door each), 360 flight-deck cells and the 15-cell island with the helm; the flight deck overhangs the hull by one tile at each end; ladders pair hangar to flight deck and flight deck to island; `vessel_at()` finds the ship on each level and nothing beside it.
- **Compartment air:** the engine room ledger holds 28 tiles and the hangar 113 at sea-level air; the controller tracks every deck tile (222) and the SUBCOM13 controller none of them.
- **The hop:** at full ahead a hop moves the block six tiles with a crate, a sailor, a bucket in the hangar and the helm aboard; sea, rock and sky come back behind it; a hull breach and the water it let in move with the hull; a compartment keeps its thinned air; the ladders still pair; the flooding tick keeps filling the breached compartment. The hop's wall time is logged (about 40 ms in the fixture).
- **Refusals:** land off the bow stops the ship with the reason; an obstacle three tiles ahead leaves a two-tile hop and the next hop stops hard against it; no hop runs while `persistence_save_in_progress`; a ship over the map edge or over another ship is refused and writes nothing.
- **Coming about:** turning north swaps the 40x9 box about its centre, the helm and the sailor are where the island and deck now stand, and nothing is left behind.
- **Removal:** `remove()` restores every tile of sea, rock and sky, the controller forgets the decks, cargo is left in the water, and deleting the vessel clears the registries.

## Phase 2: the flight deck (`flight_deck_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/flight_deck_probe.dm
```

The carrier lies bow north in the same fixture so the light plane, which is built facing south, rolls along the deck.

- **Layout:** 360 flight deck tiles of which 36 are arresting wires (stern cells u 6-9) and 32 are two 4x4 elevator platforms on the port side; the hangar keeps its 113 tiles with 32 elevator floors under the platforms; each elevator has a lever on both decks that serves only its own 16 tiles.
- **Runway:** deck, wires and platform tiles count for `aircraft_runway_at()`; the island deck, the sea and the hangar floor do not. A fuelled light plane takes off after the usual eight-tile roll and climbs to the level above the ship.
- **Hops:** a parked plane rides a hop whole, still on runway, with a crate; the plane in the air stays where it flies; moving the ship back brings them back.
- **Landing:** a descent over the wires lands and stops the plane at once (tailhook); a landing clear of the wires rolls on at taxi speed.
- **Crash barrier:** the step off the stern is refused and the plane stops; amidships it may roll. The plane that rolled over the after lever at takeoff leaves it standing (ladders and levers are neither crushed nor carried by vehicles).
- **Elevators:** the deck lever lowers a parked plane and a crate to the hangar and the hangar lever lifts them back; a plane half on the platform, a blocked hangar floor and a plane still rolling keep the elevator still; an empty elevator moves.
- **Removal:** the sea comes back under wires and platforms.

## Phase 3: the shipyard (`shipyard_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/shipyard_probe.dm
```

The probe's map metadata answers `is_node_done()` from a global toggle, so the research gate can be exercised without a faction.

- **Research:** the Naval Aviation node needs Powered Flight and Submarines; the shipyard office recipe is gated on it.
- **Office:** without research the placement refusal names the research and the missing cable but not the sea; with research only the cable. A carrier fits bow east or west on the sea north-east of the office; bow north it would run off the map; fit checks lay nothing down. Laying down costs 400 steel, 20 glass and 40 cable and leaves the ship anchored with empty bunkers; an office whose sea is under another ship lays nothing down.
- **Bunkers:** a dry ship stops with the reason; pouring a barrel takes its diesel and petroleum and leaves the water; the bunkers hold 1000 units; a hop at full ahead burns 6 and the last hop stops the ship.
- **Chart:** heading, telegraph, fuel, hops left, the map edge or rock ahead with the distance, and the last refusal.
- **Saves:** the helm records the ship's state before a save; with the vessel datum deleted and the decks left on the map, the helm rebuilds the ship where it was with its fuel, the decks and controller are its again (222 tiles, hangar at 113 with sea-level air), a stopped ship does not sail by itself, a second load builds no second ship, and the rebuilt ship hops and restores the sea, rock and every tile on removal.

## Phase 4: damage control (`damage_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/damage_probe.dm
```

- **Craters:** a blast (`ex_act`) craters a flight deck or island tile instead of tearing it out; a crater is no runway until it is welded shut; craters ride hops and come back with the ship.
- **Steel:** light, medium and heavy blasts take 100, 300 and 600 off a hull wall, the heavy one breaching it so the compartment takes water, and 25, 75 and 150 off a bulkhead, buckling its seals; the turfs stay hull and bulkhead. A blast on the hangar deck starts a deck fire and leaves the deck.
- **Listing:** ten ticks of a breach fill the engine room short of flooded; a flooded compartment caps the telegraph at half ahead and ringing full gives half; a second one leaves slow ahead and slows the ship; pumping one out eases the list; the chart reports the flooding.
- **Sinking:** three flooded compartments sink her: the vessel and its controller leave the registries, the decks give way to sea, rock and sky, the sailor from the hangar deck comes up into the water, the deckhand and the crate are in the water where the deck was, the plane and the wheel go down with the ship, and five pieces of wreckage float where she sank.

## Phase 5: the fit-out (`fitout_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/fitout_probe.dm
```

The carrier lies bow south so the light plane, built facing south, faces the bow from the catapult track.

- **Layout:** twelve catapult track tiles at the bow with their lever beside them; a gun tub at each corner of the deck that is no runway and that the crash barrier keeps planes off; sixteen lit deck lights along the deck edges; the radar set and two searchlights on the island either side of the wheel; the elevator levers still on both decks.
- **Deck lights:** the wheel switches them off and on and the saved state records the switch.
- **Catapult:** an empty catapult, a plane with a wheel off the track, a cold engine and a plane pointed across the deck are each refused with the reason and the plane stays put; a fuelled plane on the track is thrown into the air above the bow at full speed with no deck roll, and the track is clear and ready again.
- **Radar:** the plane in the air shows as an aircraft; a second carrier shows as a stopped vessel with its heading and a ship's rudder axis as a ship, three contacts in all; the other carrier's radar sees this one and leaves herself out; a scrapped ship drops off the screen.
- **Recipes:** shoring kits are gated on Submarines and the shipyard office on Naval Aviation.
- **Sinking:** scuttling the other carrier takes her fittings and leaves this ship's; when this ship sinks her lights, radar, searchlights and levers go down with her.

## Phase 6: arming the aircraft (`arming_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/arming_probe.dm
```

The probe runs explosions at once through a stub of the call-proc scheduler, and steps projectiles by hand, since neither process runs in the fixture.

- **Magazine:** two empty bomb racks stand in the carrier's magazine compartment; the rack takes bombs and nothing else. Bomb casings are a Powered Flight recipe.
- **Filling:** a casing takes ten units of nitroglycerin from a container and refuses less.
- **Mounting:** a Madsen bolts into the light plane's nose and a second gun is refused; a magazine loads through the nose section; one bomb hangs under each wing and a second on the same wing is refused; bombs are not dropped on the ground.
- **Strafing:** the pilot fires the nose gun from the column on the deck; the round leaves the nose, not the pilot's tile, and hits a crate five tiles ahead.
- **Bombing:** after a deck roll into the air the first bomb falls away and bursts, cratering the deck under the plane and its neighbours; the gun cannot be aimed from cruise height; the second bomb follows and the wings are empty.
- **Cook-off:** two bombs racked in the magazine; a heavy blast on the rack sets off the filled one, empties the rack, and the hull wall beside the magazine takes the blast (1000 to 700); an empty rack shrugs off the blast.

Not covered: a real client using the helm menu, the levers or the office, the hop timer firing from the timer subsystem, a full world save and load with the deck turfs written and read by the persistence code, projectile hits on the hull (`bullet_act` is wired but not probed), a strafing run from the air, the searchlights' beams and how the decks look on screen.

## Slipway shipbuilding (`slipway_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/slipway_probe.dm
```

The fixture is the same three levels with sand ashore (x 1-20) and deep sea beyond. See `docs/slipway.md`.

- **Gating and berth:** the slipway recipe is gated on Wagons & Ships; the schooner needs Wagons & Ships and the freighter Combustion; no keel without research, facing along the shore (no water to launch into), with a solid object on the berth or across another berth.
- **Pieces:** a stack pays only the material the next piece needs and keeps the rest; the keel, ribs, hull and deck grow from stern to bow on the 62 berth frames; masts and wheel show as overlays; frames are never saved and come back after a load.
- **Launch:** a wreck on the ways blocks it; the schooner slides 15 tiles to float with a sailor and a crate aboard, the berth is sand again, her wheel and masts stand; she makes half ahead at best and sails without fuel.
- **Freighter:** a 132-tile berth reaching into the water; afloat she has 82 hold and engine room tiles in two compartments, the bunker in the engine room, paired ladders, and stays put with dry bunkers.
- **Dry dock:** a schooner built in a dug trench is refused until the trench is flooded, then floats out; abandoning a project clears the berth.

## Craft core (`craft_probe.dm`)

The shared craft core (`code/modules/craft/`, `docs/craft-core.md`): a craft
with a template body around a `datum/vessel`, its move and turn hooks, drives,
the crew register, berths and tickets, crafts carried on crafts, charts and
plane pools, and steered charts: burns, coasting, the speed limit, stop
orders, a course that arrives and stops, the chart edge, hazard countdowns and
interference, a craft's drives pushing her token, and the helm console saving
and restoring its token.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/craft_probe.dm 300

## Ship's papers (`papers_probe.dm`)

The crew register at the wheel (`code/modules/naval/ship_papers.dm`): an
unregistered ship answers to anyone, registering, owners and listed crew at
the wheel, a stranger chained out or forcing the wheel while an owner is
about, the levers and radar, joining, barring, giving the ship up, and the
papers saved and restored by the wheel.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/papers_probe.dm 300

## Player-built hulls (`built_hull_probe.dm`)

Floors laid over water commissioned at a tiller (`code/modules/craft/built_body.dm`,
`code/modules/craft/under_way.dm`, `code/modules/naval/built_hull.dm`): what is
and is not a hull, the one-tile gliding step (`code/modules/craft/glide.dm`)
with planks, cargo and crew, the water level handed
from tile to tile, obstacles, the marked path, coming about around the tiller,
refitting, papers, the hull saved and found again by the tiller, sails that
give half ahead, engines that give full ahead and burn from their tank at
every hop, and wiring that stays joined aboard while a cable to the shore
parts.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/built_hull_probe.dm 300

## Sea chart and harbours (`chart_probe.dm`)

The mirror sea chart and mooring posts (`code/modules/naval/craft_chart.dm`):
hails and running dark (`craft_signals.dm`), grappling and boarding lines
(`craft_grapple.dm`), weather, fog and night at the lookout (`sea_weather.dm`),
chart squares, tokens that follow real ships and posts, the chart read at a
helm with lookout range and a ship running dark, a berth asked for and
refused (too far, not welcome, promised, taken, foul), the marked slide
alongside for a built hull and a slipway ship, mooring, casting off by
sailing, guests, and what leaves the chart.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/chart_probe.dm 300

## Vehicles aboard (`ferry_probe.dm`)

A modular car on a built hull (`code/modules/craft/vehicle_aboard.dm`): a hop
carries every part, a turn of the ship leaves the car exactly as a turn of its
own would (compared part by part with a car ashore), it still drives and
steers afterwards, and a car parked half aboard holds the ship until it is
gone.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/ferry_probe.dm 300

## Freight contracts (`freight_probe.dm`)

A crate offered at one mooring post for another with a reward
(`code/modules/naval/freight.dm`, `code/modules/craft/contract.dm`): who may
offer, the post taking in crate and reward, a registered crew taking it, the
hand-in and payment at the destination, a broken seal, a lost crate written
off, a withdrawn offer, a crate finding its contract after a load, a full
board and a destroyed post. No client connects, so the post's menus are not
exercised.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/freight_probe.dm 300

## The open sea (`open_sea_probe.dm`)

An open-sea world (`code/modules/naval/open_sea.dm`, `open_sea_sites.dm`,
`open_sea_chart.dm`) on a fixture of six 40-tile cells: cell geometry, tide
races nobody swims, the home island raised once, the cell pool (free means no
site, no ship and nobody there), the chart's sites saved as one text, a hull
that puts to sea, makes passage, raises an island and anchors off it, the
island staying while someone is ashore or a mooring post stands and sinking
when its count runs out, the same island rising the same, a wreck with her
hold, the site cap and the admin pause, standing off when no water is free,
ships in different waters not sighting each other, a passage saved by the
tiller and resumed, the way home, and the harbour office (`sea_office.dm`): its
board on the home island, a survey and a salvage contract taken, done,
paid and saved, a contract given up, and two ships meeting at sea and
parting company.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/open_sea_probe.dm 300

`python3 tools/open_sea/make_map.py --check` confirms `maps/sea/open_sea.dmm`
matches the cell size in `code/__defines/naval.dm`.

## Naval mines (`mines_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/mines_probe.dm
```

Linux: `python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/mines_probe.dm`. Blasts are recorded instead of set off (the fixture has no explosion config).

- **Signature:** a freighter is worth 140, a carrier 600, a schooner 0; the reading words; a magnetic mine feels a freighter from 3 tiles but not 4, a carrier from 4 but never 5, a 30 boat only beside it, a wooden hull never; a contact mine only under a hull.
- **Laying:** not on sand or on a hull, yes on open water; a mine is a heavy item.
- **Wooden hull:** worth nothing and the tiller says so; she sails over a magnetic mine, which stays where it was laid and is not counted aboard; a contact mine under her goes off, with the blast on the hull tile over it.
- **Steel hull:** twenty steel plates are worth 20 ("strong"); a magnetic mine three tiles off her course stays quiet, one tile off it goes off under her nearest plate.
- **Submarine:** a Scout is worth 30, the systems report reads it, and a magnetic mine beside her springs two leaks.

## Degaussing (`degaussing_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/degaussing_probe.dm
```

The probe answers the wiping station's wired power itself.

- **Wiping:** the station on the beach finds a steel hull alongside; it asks for cable, takes thirty lengths, does nothing without power, and with power wipes 70% off for twenty lengths (20 shows as 6, "faint", and the tiller says so); ten lengths are not enough for another; the tiller keeps the wipe for a save.
- **Wear:** the wiped hull passes a magnetic mine one tile off her course; ten tiles wear 1% off; with the wipe gone the same mine goes off.
- **Coil:** a running coil takes 80% off; with no engine aboard a built hull trips it out on the next move. On a Scout submarine the coil is switched on by hand, takes 30 to 6, costs a battery unit a tile and trips out on a flat battery; the axis saves the wipe.

## Minesweeping (`sweeping_probe.dm`)

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/naval_carrier/sweeping_probe.dm
```

- **Oropesa:** a sweep must be bolted down and on a deck to stream; under way on a wooden hull it cuts a contact mine two tiles off her side up to the surface, leaves a far one moored, and a surfaced mine still goes off under a hull.
- **Magnetic:** with no engine aboard a built hull the reel goes dead and is wound in; streamed aboard a Scout submarine it sets off a magnetic mine six tiles off, not one nine tiles off or a contact mine, for a battery unit a tile, and goes dead on a flat battery.
