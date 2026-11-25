# Building insulation probe

Native probe for room insulation (`code/game/objects/building_insulation.dm`
and the inside branch of `get_temp()` in `code/modules/1713/weather.dm`).

    python3 tests/ecology_spawning/run_linux.py . tests/building_insulation/probe.dm 300

In a temperate winter evening it checks that open air is -29 C, a bare roof
shelters 5 C, a room in mapped walls keeps 10 C as before, a closed wooden room
sits between the two, a hole in its wall makes it draughty and colder, braziers
warm a long hall by how much fire it has, an outdoor fire warms only two tiles
round it, and a room is surveyed once for all its tiles. It also checks that a
closed curtain over a hole stops the draught (an open one does not), that wool
lining holds more warmth, and which stacks line a wall.

Window regressions cover shuttered frames with and without fixed glazing,
and curtain bonuses over both shut and open casements.
