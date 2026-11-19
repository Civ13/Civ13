# Scope zoom adjustment probe

Native probe for #6219, run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/scope_zoom/probe.dm

- Adjust Zoom locks the scope during its wait.
- Moving during the wait interrupts it and releases the lock, so a later
  attempt starts again; the release checks fail on the unfixed source.

`test_sources.py` is the offline contract: the lock is released before the
wait's result is checked, and is a `tmp` field so it is never saved.
