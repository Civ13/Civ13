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

Not covered: a real client using the helm menu, the hop timer firing from the timer subsystem, saving and restoring a carrier (the deck turf types are not in the saved-turf allowlist yet) and how the decks look on screen.
