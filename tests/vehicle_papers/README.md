# Vehicle papers

`probe.dm` is a native probe for `code/modules/craft/vehicle_papers.dm`: a
premade car as a craft with an axis body, its papers read in a vehicle's
words, registering, the lock on the steering wheel for strangers, forced
controls, crew roles, saving the papers and the name on the axis, the list
of a party's vehicles, giving a vehicle up and a destroyed vehicle.

    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_papers/probe.dm 300

It expects `"failures": 0`. No client connects, so the menus, the timed
forcing of the controls and the right-click verb are not exercised; the
probe calls `papers_action()`, `papers_allow()` and `papers_steer()`
directly.
