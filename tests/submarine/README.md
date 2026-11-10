# Player submarines

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/submarine/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. The fixture world is 30x30 with two levels: z2 is the surface (land at x 1-3, shallows at x 4, deep ocean beyond) and z1 is solid rock with an old tunnel, standing in for Gaia's surface and caves.

The probe covers `code/modules/1713/machinery/modular_vehicles/ships/sea_layer.dm` and `submarine.dm`:

- **Sea layer:** rock under open ocean becomes open sea; rock under land, a one-tile shell under the coast and the rock around an old tunnel stay; a second pass changes nothing; the pass waits a minute after the world is ready (so it does not stack on the end of a save load) and yields in bounded batches.
- **No swimming down:** a mob cannot enter open sea unless a hull frame covers the tile, so crew cannot leave a submerged boat.
- **Build:** a submarine builds fifteen roofed steel hull frames with open hatches amidships, a ship wheel, the ballast and periscope station, a diesel engine and a tank, and joins the ship registry.
- **Dive and surface:** a moving boat must stop first; a stopped boat over open sea dives with its crew, cargo and machinery; it cannot dive beside the coast or surface under anything floating; surfacing brings everyone back.
- **Submerged movement:** the boat moves through open sea with its crew and stops when rock lies ahead.
- **Periscope and contacts:** the periscope looks at the surface tile straight above; contacts list surface ships and aircraft, and other submerged boats by sonar without naming them; a surface ship never sees submerged boats.
- **Research and pen:** Submarines research follows Wagons & Ships, Combustion and Electricity and gates the submarine pen, which launches a submarine with an empty tank and a key into a clear 5x5 square of deep sea and refuses a bay that reaches the shallows.

Negative control: dropping the neighbour checks from `sea_layer_candidate()` opens the coast and tunnel shells and fails 2 checks.

Not covered: a real client at the periscope (eye and perspective), steering from the ship wheel, the sea layer pass on a full Gaia save and load, and a human with a lifejacket (the fixture cannot construct a full human).
