# Log wall building tests

Log walls are built in steps (`code/game/objects/covers_types/log_wall_building.dm`):
a 1-log sill from the crafting menu, two courses and a top plate added by hand
(4 logs in all), notching with an axe or hatchet, and chinking with 1 clay or
2 hay or straw.

- `test_log_walls.py`: offline source and recipe contracts. CI suite `log_wall_building`.
- `probe.dm`: native probe of the build steps, health, insulation, corner sills
  and taking a half-built wall down:

```
python3 tests/ecology_spawning/run_linux.py . tests/log_wall_building/probe.dm 300
```

The stage sprites (`sill`, `courses`, `upper`, `unchinked` and their `_corner`
states in `icons/obj/log_wall_build.dmi`) are drawn by
`tests/sprites/create_log_wall_build.py`; `test_log_walls.py` runs its `--check`.
