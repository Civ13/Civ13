# Medical side effects

`test_registration.py` checks offline that `add_side_effect()` resolves an effect type by its name rather than reading the patient's active-effects list as a type registry.

The native probe registers a headache, refreshes it, adds a second effect and ignores an unknown name:

```bash
python3 tests/ecology_spawning/run_linux.py . tests/medical_side_effects/probe.dm
```
