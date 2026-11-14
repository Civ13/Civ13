# Vehicle load

`probe.dm` is a native probe for
`code/modules/1713/machinery/modular_vehicles/vehicle_load.dm`: an empty or
crewed car keeps every listed gear delay and its turning time, crates past the
seat-and-frame allowance (a packed crate weighs its contents too) slow it,
a huge load is held to the 1.5 cap, the factor is cached between rechecks,
a light vehicle gets one extra top gear that drops away when it is heavy
again, an armoured tank with a full crew still reads 1.0 and drives, and
boats and aircraft keep their own speeds.

    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_load/probe.dm 300

It expects `"failures": 0`. No client connects, so the steering wheel's
gear menu is not exercised; the probe calls `get_speed()`, `top_gear()` and
`loaded_turntimer()` directly.
