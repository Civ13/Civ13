# Geiger counter scan loop

Regression checks for #4918 (quick off/on duplicated the scan loop), #4919
(a counter saved while on stopped scanning after restore) and #4920 (an old
radiation pulse kept being reported after leaving the source).

- Offline: `python3 tests/geiger_counter/test_geiger.py`
- Native: `python3 tests/ecology_spawning/run_linux.py . tests/geiger_counter/probe.dm 300`
