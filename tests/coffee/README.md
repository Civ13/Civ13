# Coffee tests

- `test_coffee.py`: offline source contracts (DME include, sprite states, oven roast and brew hooks, mortar row, no instant-coffee shortcuts, no coffee speed boost, unique grounds id, no `spawn`). CI suite `coffee`.
- `probe.dm`: native probe of wild coffee and foraged seeds, roasting in a campfire (and burning on a second roast), grinding in the mortar, brewing in a pot and the wooden-mug stone-boil whitelist, and what drinking coffee does. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/coffee/probe.dm 300
```
