# Husbandry and contact fixes

Covers #6313 (carried eggs pause and resume incubation), #6320 (milking only
takes what the container can hold), #6333 (one engine start owns one
fuel-consumption chain), #6300 (objects embedded in a human's organs can be
yanked out) and #6305 (a weapon's contact effect gets the struck zone).

- Native: `python3 tests/ecology_spawning/run_linux.py . tests/husbandry_contact/probe.dm 300`
- Offline: `python3 tests/husbandry_contact/test_sources.py`
