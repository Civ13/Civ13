# Wild herb tests

- `test_wild_herbs.py`: offline source contracts (DME order, ticker hook, sprite states, saved stock, tea reagents). CI suite `wild_herbs`.
- `probe.dm`: native probe of picking, winter dormancy, regrowth, dressings, steeping, tea effects and the once-per-boot seeding pass. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/wild_herbs/probe.dm 300
```
