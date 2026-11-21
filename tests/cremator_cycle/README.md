# Cremator cycle probe

Native probe for #6273, run on Linux with the pinned compiler:

    python3 tests/ecology_spawning/run_linux.py . tests/cremator_cycle/probe.dm

With a dead occupant processed first and a living occupant still burning,
the cremator stays running and locked, so the igniter cannot start an
overlapping cycle. It unlocks once every occupant is done.

The running check and the final unlock check fail on the unfixed source.
`test_sources.py` is the offline contract.
