# Motorcycle refuelling

Regression for #6733: a motorcycle's fuel tank takes every fuel its installed
engine burns (gasoline engines also burn `enginefuel`; ethanol-gasoline engines
burn `pethanol`), up to the tank's free space, and leaves other reagents in the
container.

- Native: `python3 tests/ecology_spawning/run_linux.py . tests/motorcycle_refuel/probe.dm 300`
- Offline: `python3 -m unittest tests/motorcycle_refuel/test_sources.py`
