# Beekeeping probe

Native regression probe for #4233, #4234 and #4235. It runs the production
actions and real concurrent waits in an isolated world, checks the harvest race,
colony insertion, frame and wood recovery, lid and smoke changes, and target
movement. `result.json` records failures, runtime errors and the BYOND version.
It also checks stationary filled-frame cutting and cancellation when a frame
moves during the cutting wait.
The hive stores partial honey as a percentage, but frame items only represent full
or empty frames; dismantling returns partially filled frames as empty items.
Frame hives now start with the lid on, so the probe takes it off first, and
colony insertion uses a full nucleus box (the old bee jar is gone). The newer
frame hive behaviour has its own probe in `tests/frame_hives/`.

Run on Linux with the pinned compiler and the existing isolated runner:

    python3 tests/ecology_spawning/run_linux.py . tests/beekeeping/probe.dm
