# Modular aircraft

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/aircraft/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. The fixture world has a plain ground level (z1) with a runway and an open-air level above it (z2), standing in for Gaia's surface and its standing building level.

The probe covers phase 1 of modular aircraft (`code/modules/1713/machinery/modular_vehicles/aircraft/`):

- **Build:** the admin-spawned light plane builds twelve frames in a 4x4 turning square with four wheels, an engine, a fuel tank and a pilot's seat whose control column steers it.
- **Takeoff:** a slow roll stays on the ground; a full-throttle roll along eight runway tiles lifts the whole airframe, its engine, passengers and loose cargo to the level above; a full-throttle roll off the runway never takes off; with no level above there is nowhere to climb.
- **Open air:** what stands on an airborne frame stays aboard; an item dropped away from the aircraft, or a passenger who steps off it, falls to the ground.
- **Flight:** low flight moves everything aboard; cruise passes over an upper storey and refuses to descend into it; climbing twice or on the ground is refused.
- **Landing:** descending over a runway too fast is refused; at approach speed it lands with the passenger and leaves the airborne list.
- **Crashes:** flying into an upper storey in low flight crashes to the ground, breaks the wheels and stops the engine; with the engine off it stalls and comes down; off the runway a landing needs a second Descend, which forces a crash landing.

Negative control: removing the `aircraft_holds` hook from `/turf/sky/building/Entered` makes the airframe and passengers fall through the open air and fails 14 checks.

Not covered: flying with a real client (arrow-key steering, the Climb and Descend verbs from a player's hands), the view of the ground from the air, and saving or loading an aircraft in flight.
