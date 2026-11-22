# Butter tests

- `test_butter.py`: offline source contracts (DME include, sprite states, churn recipe and research node, unique butter and buttermilk ids, the crock and food decay hooks, the diet fat profile, no `spawn`). CI suite `butter`.
- `probe.dm`: native probe of churning milk and cream (with and without salt), interrupted and open churns, salting a pat, rancid butter, spreading butter on bread, and potting cooked meat under butter and lard in a crock, including the slower decay step while the crock stays closed. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/butter/probe.dm 300
```
