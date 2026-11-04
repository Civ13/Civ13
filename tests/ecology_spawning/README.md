# Ecology-driven spawning

```powershell
./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/ecology_spawning/probe.dm
```

Production sources run in the shared constructor fixture with ordinary game startup disabled. A probe deer subtype skips AI start-up but registers in the real `deer_count` list. The probe calls `cycle()` directly instead of waiting on the 60-second loop.

It checks the habitat filter (biome, indoor, roofed, occupied, water), 8x8 cells, the ten-minute warm-up, one spawn per species per cycle up to the target and none above it, dead animals not counting, busy player cells receiving nothing, unknown heatmap coverage never counting as quiet, stop releasing the heatmap, runtime-only state, and that every default species resolves its registry.

Not established: real client visibility, the scheduler loop on a live server, or how quickly populations recover on a real map.
