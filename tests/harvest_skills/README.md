# Harvest skill yields

`probe.dm` checks that trained skills raise harvest yields from renewable sources:

- `harvest_skill_amount()` and `harvest_skill_bonus()`: no bonus at skill 100 or below,
  +1% per point above 100, capped at +100% (skill 200).
- Hunting scales butchered meat (and pig legs, chicken carcasses, animal fat).
- Farming scales seeds and crops (single produce and stacked produce).
- A body restored from an older save without the `hunting` stat gets it at 100.

Run on Linux with the pinned compiler (`bash scripts/cloud_byond_setup.sh`):

```bash
python3 tests/ecology_spawning/run_linux.py . tests/harvest_skills/probe.dm
```

Expect `"failures": 0` and no runtime error. The probe does not exercise
clicks, waits or connected clients.
