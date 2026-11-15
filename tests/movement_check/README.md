# Check Movement

Headless probe for `code/modules/1713/movement_check.dm`, the IC verb that
lists what slows a player down. A real human's listed body costs must add up
to `movement_delay()`, the report must name hunger, thirst and low mood with
their share of the step, shallow water underfoot must be listed at its cost,
and a rested, fed player on flat dirt must read as unhindered.

```
bash scripts/cloud_byond_setup.sh   # once, installs the pinned compiler
python3 tests/ecology_spawning/run_linux.py . tests/movement_check/probe.dm
```

The hill lines (which way the ground rises or falls and by how much) are
checked in `tests/terrain_height/probe.dm`.
