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

## Stacked harvest regression

The probe also harvests beside existing 1-, 49- and 50-unit hemp piles. It checks
that soil and farming bonuses survive automatic merging, and larger fixture
yields split without losing units or exceeding stack capacity. Unmodified
master 2143aad fails four of these assertions with zero runtime errors.

Windows, using the existing isolated runner and installed pinned BYOND:

```powershell
& tests/resource_extraction/run.ps1 -ByondBin 'C:\Program Files (x86)\BYOND\bin' -Probe tests/harvest_skills/probe.dm
```

`python tests/harvest_skills/test_stacked_crops.py` executes the complete stacked
yield branch offline with fake constructor/merge boundaries over 128 input
combinations. It is registered as `stacked_crop_yields` in the offline CI
registry. The existing native probe is an explicit local check; ordinary PR CI
does not run it. Neither check establishes real-client or save/load behavior.
