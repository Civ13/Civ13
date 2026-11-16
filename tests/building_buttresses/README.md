# Buttress probe

Native probe for buttresses, flying buttresses and corbels
(`code/game/objects/building_buttresses.dm`).

    python3 tests/ecology_spawning/run_linux.py . tests/building_buttresses/probe.dm 300

It checks the storey bonus on stone and mapped walls (none for plank walls),
the wider span from flying buttresses and corbels, a brace turning to face its
wall, the doubled resistance to a blow that pushes the wall onto its buttress,
and that a broken buttress stops helping.
