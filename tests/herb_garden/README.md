# Herb garden tests

- `test_herb_garden.py`: offline source contracts (DME include, crop, seed, produce, dried and dehydrator sprite states, tea reagents, wild pool and foraging entries). CI suite `herb_garden`.
- `probe.dm`: native probe of seeds and plants, dandelion/rose/sunflower harvests, sunflower shelling, steeping fresh and dried herbs, mint tea clearing food poisoning, and the wild and foraging tables. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/herb_garden/probe.dm 300
```
