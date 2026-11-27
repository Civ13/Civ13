# Hay tests

- `test_hay.py`: offline source contracts (DME order, sprite states, override fall-through). CI suite `hay`.
- `probe.dm`: native probe of spreading, drying (rain, snow, sandstorm, roof, stale callbacks, save/load resume), bale placement (solid shore fallback, open water refusal, covered water and ice), thatch refusal and feeding. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/hay/probe.dm 300
```
