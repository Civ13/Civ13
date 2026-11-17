# Knowledge spread tests

- `test_knowledge_spread.py`: offline source contracts (DME entry, config lags and defaults, book-research worlds only, the band shown in the research windows). CI suite `knowledge_spread`.
- `probe.dm`: native probe of the bands by era, the labels and the fall back when the era falls. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/knowledge_spread/probe.dm 300
```
