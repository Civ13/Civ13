# Vehicle storage

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/vehicle_storage/probe.dm
```

Production sources run in the shared resource-extraction constructor fixture with ordinary game startup disabled. The probe covers garages and aircraft hangars (`code/modules/1713/machinery/modular_vehicles/vehicle_storage.dm`):

- **Garage:** Automobiles research gates the garage. A keyed car parked in the 4x4 bay northeast of it is refused without its key, refused while its engine runs (every part stays saveable after a refusal), refused by a hangar, and otherwise put away: no part is left on the map, a road under it stays, and the record is a text field in the garage's saved fields.
- **Reload:** a garage rebuilt from its saved field alone lists the car by its plate. Taking it out needs the key and an uncluttered bay; it comes back with the same frames, plate, key binding, fuel, damage and a wheel that belongs to its seat, and every rebuilt part is saved with the map again. A full garage refuses another car.
- **Hangar:** the aircraft hangar builds a light plane and offers to hangar it; a garage refuses the plane, an airborne plane is refused, and a hangared plane rolls out whole with its control column, tank aboard and saveable parts.

Negative control: storing with the strict extraction footprint (`ignore_ground` FALSE) refuses the car parked over a road and fails 3 checks.
