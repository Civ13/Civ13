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

Not covered: a real client using the helm menu, the levers or the office, the hop timer firing from the timer subsystem, a full world save and load with the deck turfs written and read by the persistence code, projectile hits on the hull (`bullet_act` is wired but not probed), launch and recovery lights (fit-out phase) and how the decks look on screen.
