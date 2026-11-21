# Lighter ignition probe

Native probe for #6265, run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/lighter_ignition/probe.dm

- An unlit lighter, with or without fuel, does not set a fuel-soaked person alight.
- A lit lighter still does.

The first two checks fail on the unfixed source. `test_sources.py` is the
offline contract.
