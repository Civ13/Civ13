# Dead mounts

A dead animal takes no rider. `take_rider()` refuses a corpse, and dragging
yourself onto one does not start mounting. If the animal dies during the
mounting delay, the climb ends without seating the rider.

- Native: `python3 tests/ecology_spawning/run_linux.py . tests/dead_mount/probe.dm 300`
