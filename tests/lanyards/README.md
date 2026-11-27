# Wearable tethers

Run the offline source checks with `python3 -B tests/lanyards/test_lanyards.py`. For the production DM paths, run `python3 -B tests/ecology_spawning/run_linux.py . tests/lanyards/probe.dm 300` with pinned DreamMaker and DreamDaemon on PATH. The isolated probe uses the timer subsystem to verify wrist catch admission, false-success handling, and a real catch. It also exercises loose cord emptying, the Storage Window, and classic drag on the server side.
