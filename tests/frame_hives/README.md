# Frame hive probe

Native probe for the moveable-frame hive kit in `code/modules/1713/beekeeping.dm`:
the frame hive, hive tool, frames, bellows smoker, honey extractor and nucleus
box, and the frame hive's share of `kept_hive_cycle()` in `kept_hives.dm`.

Run after a fresh compile:

    python3 tests/ecology_spawning/run_linux.py . tests/frame_hives/probe.dm 300

It checks the lid and frame handling, swarms settling in a frame hive, honey
filling (drawn comb faster, an open hive slower, capped by frames), stings when
reaching in unsmoked, smoker loading/lighting/burning out, lifting full frames,
extractor honey and drawn frames, the honey gate, nucleus box splits and swarm
catching, the shared colony cycle and winter die-off.
