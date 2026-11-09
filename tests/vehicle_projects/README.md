# Vehicle projects

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/vehicle_projects/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. Only the piece and assembly waits and the cable supply are adapted. The probe covers piece-by-piece builds at the automobile workshop and the aircraft hangar (`code/modules/1713/machinery/modular_vehicles/vehicle_projects.dm`, plans from `code/modules/1713/piece_projects.dm`):

- **Plans:** a car project costs exactly what the one-go assembly costs (small and large cars), in 11 pieces over 6 stages; the hangar's plane plan starts with the airframe and costs 50 steel on 4 wheels. The press offers a project for each model; the shipyard does not.
- **Starting:** a cluttered bay refuses a project, a clear bay takes one and the jig fills the vehicle's cells; only one project runs at a time and it keeps the bay from one-go builds and stored vehicles.
- **Pieces:** the chassis refuses glass; a short stack pays part of a piece; a full piece is fitted and the rest of the stack kept, and the chassis grows from the back row; a wheel dragged onto the vehicle is fitted.
- **Saving:** the project saves in three vars, its parts are never saved, and a load rebuilds them.
- **Roll out:** the finished car rolls out keyed with four wheels and an empty tank, leaving the press's stock as it was; the plane rolls out whole and keyed with an empty tank; abandoning clears the jig.

The slipway uses the same plans; its probe is `tests/naval_carrier/slipway_probe.dm`.
