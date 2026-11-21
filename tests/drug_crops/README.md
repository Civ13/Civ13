# Drug crop tests

- `test_drug_crops.py`: offline source contracts (real climates for poppy, tobacco, hemp, cannabis and coca; wild forage and regrowth sources inside each crop's climates; cannabis split from fibre hemp, the joint recipe on dried cannabis). CI suite `drug_crops`.
- `probe.dm`: native probe that grows each crop wild, harvests its product and seeds, and checks the cannabis materials and contraband flags. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/drug_crops/probe.dm 300
```
