# Salting container restore

Covers #6446: a salting container saved mid-batch keeps `salting = TRUE`, but its
completion callback is not saved, so `after_load()` restarts it.

- Native: `python3 tests/ecology_spawning/run_linux.py . tests/salting_restore/probe.dm 300`
- Offline: `python3 tests/salting_restore/test_sources.py`
