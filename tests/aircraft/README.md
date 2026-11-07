# Modular aircraft

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/aircraft/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. The fixture world has a plain ground level (z1) with a runway and an open-air level above it (z2), standing in for Gaia's surface and its standing building level.

The probe covers phases 1 and 2 of modular aircraft (`code/modules/1713/machinery/modular_vehicles/aircraft/`):

- **Build:** the admin-spawned light plane builds twelve frames in a 4x4 turning square with four wheels, an engine, a fuel tank and a pilot's seat whose control column steers it.
- **Airstrip spawner:** lays a 3x16 runway with the light plane parked at its north end, which can take off from it and land back on it.
- **Takeoff:** a slow roll stays on the ground; a full-throttle roll along eight runway tiles lifts the whole airframe, its engine, passengers and loose cargo to the level above; a full-throttle roll off the runway never takes off; with no level above there is nowhere to climb.
- **Open air:** what stands on an airborne frame stays aboard; an item dropped away from the aircraft, or a passenger who steps off it, falls to the ground.
- **Flight:** low flight moves everything aboard; cruise passes over an upper storey and refuses to descend into it; climbing twice or on the ground is refused.
- **Landing:** descending over a runway too fast is refused; at approach speed it lands with the passenger and leaves the airborne list.
- **Ground view and shadow:** in the air every frame casts a dark silhouette on the ground turf straight below it, closer in low flight and farther at cruise; the open air around the aircraft shows the ground below, except under a floor on the upper level; both follow the aircraft and nothing is left behind after landing or a crash. Neither is a map atom: they are drawn through turf `vis_contents`, and the frames themselves never gain a `vis_locs` entry.
- **Saved in flight:** an aircraft restored over open air is set down on the ground below with its engine off, intact where the ground is clear and with broken wheels over an obstacle; one restored on the ground stays put.
- **Crashes:** flying into an upper storey in low flight crashes to the ground, breaks the wheels and stops the engine; with the engine off it stalls and comes down; off the runway a landing needs a second Descend, which forces a crash landing.

Negative control: removing the `aircraft_holds` hook from `/turf/sky/building/Entered` makes the airframe and passengers fall through the open air and fails 14 checks.

Not covered: flying with a real client (arrow-key steering, the Climb and Descend verbs from a player's hands), how the ground view and shadows look on screen, and a real world save and load (the probe calls the restore set-down directly).
