# Vehicle speed ladder

One table, `vehicle_speed_ladder` in
`code/modules/1713/machinery/modular_vehicles/vehicle_speeds.dm`, sets how
long a tile takes in each gear for every vehicle class that names a
`speed_class`. Figures are true intervals in deciseconds per tile; lower is
faster. The frame vehicle loop waits one tick more than the delay it is
given, so `apply_speed_class()` hands it the interval less that overhead.

## Top speeds, fastest first

| Vehicle | Deciseconds per tile | Source |
| --- | --- | --- |
| Car with a light hull (extra top gear) | 1.2 | ladder, load factor floor |
| Car, 5th gear | 1.6 | ladder `car` |
| Motorcycle, 120cc or larger | 1.6 | `axis/bike/check_enginepower` |
| Pedal bicycle, unloaded, on a road | 1.8 | `bicycle_step_delay` |
| Person running | about 1.9 | `get_run_delay` |
| Motorcycle, 95 to 119cc | 2 | `axis/bike/check_enginepower` |
| Carriage at a canter | 2.2 | `carriage_gear_delays` |
| BT-7 | 3 | ladder `tracked_sprint` |
| M41, M113, BMD, BTR-80, Bradley, T-80, Abrams, Leopard 2 | 4 | ladder `tracked_fast` |
| T-34, SU-85/100, T-55, T-62, T-64, T-72, T-90, Challenger 2, Ha-Go, L3/33 | 5 | ladder `tracked_quick` |
| Sherman, Panzer IV, Tiger, M13/40, Chi-Ha, M48, M60 | 6 | ladder `tracked_medium` |
| KV-1, IS-1/2/3, I-Go | 7 | ladder `tracked_slow` |

Trains, aircraft, ships and boats still carry their own figures. Targets for
the work that moves them onto the ladder: steam locomotive 2, diesel
locomotive 1.2, propeller aircraft 0.8 in cruise, jets 0.4.

## Rules

- A class is a row of intervals, one per gear, each quicker than the last
  (`tests/vehicle_load/probe.dm` checks this and the order of the classes).
- Give a new axis type a `speed_class` instead of its own `speedlist`.
- The load factor (`vehicle_load.dm`) scales the whole interval, so a hull 30%
  lighter takes 30% less time per tile, down to a floor of 1.2.
- The server tick is 0.4, so keep intervals on multiples of 0.4 where the
  loop is a plain `spawn`; the bicycle schedules against a deadline and may
  use any figure.
