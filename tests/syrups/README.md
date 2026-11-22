# Syrup tests

- `test_syrups.py`: offline source contracts (DME include, unique reagent ids, tree, oven and world-time hooks, uses kept in the chemistry files the Crafting Atlas reads, no `spawn`). CI suite `syrups`.
- `probe.dm`: native probe of sap tapping (knife, wait, season, climate, pines and lacquer trees), boiling sap, sugar and water into syrups and boiling syrups again into sugar and molasses, and the fruit syrup, lemonade, jam and rum mixes. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/syrups/probe.dm 300
```
