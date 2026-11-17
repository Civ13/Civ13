# Newcomer start

An account in its first two days starts 40 to 80 tiles from the largest group
of awake players outdoors (`code/game/objects/map_metadata/nomads/newcomer_start.dm`).

- `test_newcomer_start.py`: offline source contracts. CI suite `newcomer_start`.
- `tests/gaia_spawn/test_spawn.py` covers the order: faction station, home bed, near people, random.
- `probe.dm`: native probe of the group choice, the distance band and the fallbacks:

```
python3 tests/ecology_spawning/run_linux.py . tests/newcomer_start/probe.dm 300
```
