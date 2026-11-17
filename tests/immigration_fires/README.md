# Immigration by smoke signal

Whoever raises a smoke signal on the mainland may invite newcomers to start
near the fire (`code/modules/1713/immigration_fires.dm`).

- `test_immigration_fires.py`: offline source contracts. CI suite `immigration_fires`.
- `tests/gaia_spawn/test_spawn.py` covers where it sits in the start order.
- `probe.dm`: native probe of opening, pausing, ending, the mainland rule and the start tile:

```
python3 tests/ecology_spawning/run_linux.py . tests/immigration_fires/probe.dm 300
```
