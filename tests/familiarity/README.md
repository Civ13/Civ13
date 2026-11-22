# Familiarity tests

- `test_familiarity.py`: offline source contracts (DME entry, the click and Life hooks, book-research worlds only, the tiered cap below a whole subject, familiarity never takes the last step). CI suite `familiarity`.
- `probe.dm`: native probe of first/repeat use, noticing nearby things, the daily limit, the era cap, combining with reading and cleaning a saved record. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/familiarity/probe.dm 300
```
