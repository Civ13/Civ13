# Vehicle papers

`probe.dm` is a native probe for `code/modules/craft/vehicle_papers.dm`: a
premade car as a craft with an axis body, its papers read in a vehicle's
words, registering, the lock on the steering wheel for strangers, forced
controls, crew roles, the lock on its turret guns, saving the papers and the name on the axis, the list
of a party's vehicles, giving a vehicle up and a destroyed vehicle.

    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_papers/probe.dm 300

It expects `"failures": 0`. No client connects, so the menus, the timed
forcing of the controls and the right-click verb are not exercised; the
probe calls `papers_action()`, `papers_allow()` and `papers_steer()`
directly.

## Vehicle assembly (`assembly_probe.dm`)

A native probe for `code/modules/craft/vehicle_assembly.dm`: the survey's
refusals (no frame under the axis, a single row, an L, too long), a 2 by 3
bed assembled facing north with its parts fitted in one step, a second bed
laid against it staying its own vehicle, driving and turning left and right,
the same for beds facing east, south and west, an engine fitted after
assembly, and taking a vehicle apart and assembling it again. It then
builds a boat of ship frames: refused on dry land, a car axis not taking ship
frames, a hull with a wheel and a mast assembled facing east, moved, turned,
taken apart and assembled again.

    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_papers/assembly_probe.dm 300

It expects `"failures": 0`. No client connects, so the axis menu is not
exercised; the probe calls `assemble()`, `fit_parts()`, `take_apart()`,
`do_move()` and `do_matrix()` directly.
