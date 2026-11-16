# Building defences probe

Native probe for solid pillars, bollards and barriers
(`code/game/objects/building_defences.dm`).

    python3 tests/ecology_spawning/run_linux.py . tests/building_defences/probe.dm 300

It checks that roof supports and stone or concrete pillars block people but let
most shots through, that hidden roof props and wooden mine timbering stay
walk-through, that people walk between bollards while a row of stone bollards
stops a car before the wall behind, that a wooden bollard only costs a gear, and
that jersey barriers and sandbags take a crash.
