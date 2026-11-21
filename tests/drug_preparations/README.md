# Drug preparation tests

- `test_drug_preparations.py`: offline source contracts (DME include, the Fable-drawn khat, cannabis, hashish and opium sprite states, no instant opium craft, mortar rows, new reagents dosing their class, khat wilting and wild sources). CI suite `drug_preparations`.
- `probe.dm`: native probe of poppy and coca tea, chewing coca and tobacco, khat harvest and wilting, hashish and dried cannabis in a pipe, and picking dried latex off a lanced poppy. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/drug_preparations/probe.dm 300
```

Sprites: `python3 tests/sprites/create_drugs.py --check`.
