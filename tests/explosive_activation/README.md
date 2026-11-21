# Explosive activation

Covers #6298 (an armed impact grenade has no fuse timer, so a severe blast must
detonate it directly, and only once) and #6337 (an empty dynamite casing holds no
charge and must not activate).

- Native: `python3 tests/ecology_spawning/run_linux.py . tests/explosive_activation/probe.dm 300`
- Offline: `python3 tests/explosive_activation/test_sources.py`
