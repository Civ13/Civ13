# Martial schools

Covers `code/modules/1713/martial_arts/martial_schools.dm`, `martial_training.dm` and `code/__defines/martial.dm`.

- `test_sources.py` (offline suite `martial_schools`): twelve schools whose eras cover 0-9, each school's Military research node in its own era, the gear recipes and research, the company multipliers, the rank defines, the includes and the region travel hooks.
- `run.py` + `probe.dm` (native): compiles the committed sources with the probe and checks choosing and leaving a school, the 7-day wait, ranks at 40/150/400 points, solo forms, practice from punches and hand sets, training company (partner x1.5, verified Master x2, sparring a verified Master x2.5), the heavy bag and wooden dummy, and the travel record. Commit first, because the runner archives `HEAD`.

```
python3 tests/martial_schools/test_sources.py
python3 tests/martial_schools/run.py --byond-bin <dir with DreamMaker and DreamDaemon>
```
