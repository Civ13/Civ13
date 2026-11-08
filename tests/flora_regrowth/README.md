# Flora regrowth probe

```bash
bash scripts/cloud_byond_setup.sh   # once per cloud session
python3 tests/ecology_spawning/run_linux.py . tests/flora_regrowth/probe.dm
```

On Windows, use `./tests/resource_extraction/run.ps1 -ByondBin '<pinned BYOND bin directory>' -Probe tests/flora_regrowth/probe.dm`.

Production sources run in the shared constructor fixture with ordinary startup
disabled, on a 40x40 temperate grass level. The probe calls `cycle()`,
`wither_plants()` and `regrow_stumps()` directly instead of waiting on the loop.

It checks plant sites (settlement, field, roof, item, indoor and water refusal),
the warm-up, the habitat-sized target and no growth above it, that wild plants
are ripe and suit their biome and season, do not grow or dry out, give produce
and seeds and wither out of season; that chopped trees leave a stump that
remembers the tree, full-health deletion and bushes leave none, stumps do not
regrow in winter or under a built object and otherwise grow back; and the save
fields, after_load re-registration and runtime-only worker state.

Not established: client visibility, the live scheduler loop, or regrowth pace on
a real map.
