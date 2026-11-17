# Death legacy tests

- `test_death_legacy.py`: offline source contracts (DME entry, death() records before forgetting, the spawn and lobby hooks, the save and load hooks, the three damage paths). CI suite `death_legacy`.
- `probe.dm`: native probe of the loss table, station and bed returns (range, one day, a long-held bed, doubling), causes, the save round trip and the weakness. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/death_legacy/probe.dm 300
```
