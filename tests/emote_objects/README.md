# Emotes and nearby objects

An emote tells the objects in view about itself in one deferred pass instead of
one spawned proc per object. A crowded view used to queue thousands of procs,
which crashed DreamDaemon in the load-construction sweep. Objects deleted
before the pass are skipped.

- Native: `python3 tests/ecology_spawning/run_linux.py . tests/emote_objects/probe.dm 300`
- The load-construction sweep (`tests/load_construction/run.py`) covers the crowded case.
