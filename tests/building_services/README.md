# Building services probe

Native probe for cables and pipes through walls
(`code/game/objects/building_services.dm`).

    python3 tests/ecology_spawning/run_linux.py . tests/building_services/probe.dm 300

It checks that nothing goes into a wall before a chase is cut, that a chisel
does not cut stone, that a coil feeds one straight cable through a chased wall
and it joins the cables on both sides, that a pipe slides into the wall next to
its neighbours, which pipe pieces fit, and that a breaking wall snaps the cable
and bursts the pipe inside while cables outside survive.
