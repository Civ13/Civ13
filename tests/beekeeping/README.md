# Beekeeping probe

Native regression probe for #4233, #4234 and #4235. It runs the production
actions and real concurrent waits in an isolated world, checks the harvest race,
colony insertion, frame and wood recovery, lid and smoke changes, and target
movement. `result.json` records failures, runtime errors and the BYOND version.
The hive stores partial honey as a percentage, but frame items only represent full
or empty frames; dismantling returns partially filled frames as empty items.

Run on Linux with the pinned compiler and the existing isolated runner:

    python3 tests/ecology_spawning/run_linux.py . tests/beekeeping/probe.dm
