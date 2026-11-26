# Scripted Voyage navigation

Run the offline contracts with `python3 -B tests/voyage_navigation/test_source.py`.
With the repository's pinned BYOND compiler and daemon available, run the
isolated lifecycle probe with:

```sh
python3 -B tests/ecology_spawning/run_linux.py . tests/voyage_navigation/probe.dm 180
```

The probe calls the real wheel handler, navigation tick and encounter departure.
It substitutes only prompt input, the action delay, map load/clear, ship speed,
and side effects of ordinary game startup. It is not a real-client test.
