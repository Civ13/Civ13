# Radiation armor probe

Native probe for #6276, run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/radiation_armor/probe.dm

- An unprotected person takes the whole radiation pulse.
- A worn hazmat suit (rad 100, full coverage) blocks every body part's
  share, not only the head's.

The suit check fails on the unfixed source. `test_sources.py` is the offline
contract.
