# Vehicle breaches and glass

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/vehicle_breaches/probe.dm
```

Runs `code/modules/1713/machinery/modular_vehicles/vehicle_breaches.dm` and the `try_destroy()` hook in `frame.dm` in the shared resource-extraction fixture (10x10, one level):

- **Sides:** `side_toward()` names the wall a mover crosses leaving toward each world direction, the same table as `CheckExit`, for a frame facing north and east.
- **Breaches:** a wall with no health left opens as a hole that people pass through, the frame remembers the wall it was, and a second blast does not overwrite that record. A wrecked door hangs open as before and is not a breach.
- **Welding:** mending gives the wall back at 20 health and shuts the way; nothing is left to mend after.
- **Glass:** only windows, windshields and glazed doors count, not walls, doors, armour or a submarine's pressure glass; smashed glass is a breach.
- **Submarines:** a wrecked pressure hull stays shut.

Negative control: making `breach_passable()` return FALSE fails 4 checks.

Not covered: a full human smashing glass or welding through `breach_attackby()` (timers, intents, held items), and the broken-wall art as a client sees it.
