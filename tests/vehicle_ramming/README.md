# Vehicle ramming probe

Native probe for vehicles and trains hitting buildings
(`code/modules/1713/machinery/modular_vehicles/vehicle_ram.dm` and `rail_hit` in
`code/modules/1713/trains.dm`).

    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_ramming/probe.dm 300

It checks that a car at speed smashes through plank walls and loses one gear,
that stone stops it and only cracks, that a crawl dents a wall and stops, that an
open road costs nothing, and that a train runs through planks but stops at stone.
