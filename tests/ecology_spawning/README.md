# Ecology-driven spawning

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/ecology_spawning/probe.dm
```

On Linux or in a cloud session (after `bash scripts/cloud_byond_setup.sh`):

```bash
python3 tests/ecology_spawning/run_linux.py . tests/ecology_spawning/probe.dm
python3 tests/ecology_spawning/run_linux.py . tests/ecology_spawning/perf_probe.dm 900
```

Production sources run in the shared constructor fixture with ordinary game startup disabled. A probe deer subtype skips AI start-up but registers in the real `deer_count` and living lists. The probe calls `cycle()` directly instead of waiting on the 60-second loop.

`probe.dm` checks the habitat filter (biome, indoor, roofed, occupied, water), ground classes, 8x8 cells, the warm-up, herds up to the target and none above it, dead and tamed animals not counting, busy player cells receiving nothing, unknown heatmap coverage never counting as quiet, stop releasing the heatmap, runtime-only state, the default species table and type matching, habitat-sized targets and the map cap, which map spawners ecology replaces, and when distant animals rest.

`perf_probe.dm` is not a pass/fail test; it prints the mob process cost per second for 100-900 animals with and without resting. Results are in `docs/ecology-spawning.md`.

Not established: real client visibility, the scheduler loop on a live server, or how quickly populations recover on a real map.
