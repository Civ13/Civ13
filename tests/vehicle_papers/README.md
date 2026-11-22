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
taken apart and assembled again. Last it builds a tank with a built turret
(`code/modules/craft/vehicle_turret.dm`): what an empty turret needs, the
cannon and seats on its tile taken in at assembly, a seat fitted later, one
emplaced machine gun fitted beside the cannon (a second one riding along loose
on the frames), the turret riding along, the styles by age, and everything set down again when
the tank is taken apart, and a turret armed with only a machine gun.

    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_papers/assembly_probe.dm 300

It expects `"failures": 0`. No client connects, so the axis menu is not
exercised; the probe calls `assemble()`, `fit_parts()`, `take_apart()`,
`do_move()` and `do_matrix()` directly.

## Vehicle sheets (`sheet_probe.dm`)

A native probe for `code/modules/craft/vehicle_draught.dm` and
`vehicle_draught_checks.dm`: the four ready-made sheets pass their checks and
read back from their design codes, bad codes are refused (tiles not filling
the size, an engine too big, an unknown part, a 2 wide plane, an airframe
section on a car axis), each `vehicle_sheet` check fires (no frame, no
engine, a bare corner, a wheel off the corners, a tiny engine, no tank, no
seat, two seats, a pilot out of the wing row, a turret on a plane), every
key has a part description, a field car laid out by hand around an axis with
the sheet clipped to it is compared tile by tile (a missing seat and tank
named, everything laid out front to the north), a heavy axis refuses the
light axis's sheet, and the assembled car is drawn back onto a sheet tile for
tile.

    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_papers/sheet_probe.dm 300

## Sheets built in a workshop (`sheet_works_probe.dm`)

A native probe for `code/modules/craft/vehicle_sheet_works.dm`: the
automobile workshop takes light and heavy axis sheets and the hangar plane
sheets, each sending the other kind to the right press; a sheet costs its
parts with the corner wheels from the wheel stock and 10 cable; an empty
press names what it lacks, a sheet that fails its checks and a loose item in
the bay are refused; the field car is assembled front to the north from its
front left corner with its engine, an empty tank, four wheels and a key, the
stock is spent and the car draws back onto its sheet tile for tile; a tank
sheet needs Mechanized Warfare and is built with its turret; the hangar
builds the light plane sheet and the helicopter (Rocketry, 7x7, empty tank,
key); a sheet press holds 1000 steel and the shipyard office the carrier's
400.

    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_papers/sheet_works_probe.dm 300
