# SR-3 suppressor

Covers #6363: the SR-3 trains the machinegun skill, so its 9x39 SRM suppressor
must accept that weapon class or the constructor's install is rejected.

- Native: `python3 tests/ecology_spawning/run_linux.py . tests/sr3_suppressor/probe.dm 300`
- Offline: `python3 tests/sr3_suppressor/test_sources.py`
