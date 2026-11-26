# Preserves tests

- `test_preserves.py`: offline source contracts (DME include, sprite states, crock and jar recipes with research nodes, unique vinegar and jam IDs, lid timer ownership, no `spawn`). CI suite `preserves`.
- `probe.dm`: native probe of the kiln result, a closed crock souring wine into vinegar, packing and pickling vegetables in vinegar and salt, taking them back out, jam from juice with sugar or honey, and spreading jam on bread. Also opens and reseals a crock and runs the real timer subsystem through both deadlines to check souring, pickling, and potting. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/preserves/probe.dm 300
```
