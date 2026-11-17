# Training gear and obstacle course

Covers `code/modules/1713/active_training.dm` (shared fatigue, rewards, crafting
gate, old fixtures), `training_gear.dm` (lifting stones, bronze hand weights,
iron barbell) and `training_course.dm` (start and finish posts, hurdles, balance
log, best times).

- `python3 -B -m unittest discover -s tests/active_training -p 'test_*.py'`
  runs the offline seam checks: recipes, research, the crafting gate, the
  walking hook, saved fields, old fixtures and the art.
- `python3 tests/active_training/run.py --byond-bin <BYOND bin>` compiles the
  committed sources with `probe.dm` and runs it headless on the pinned BYOND.
  It prints `PASS` and the number of checks.

The probe replaces the two-second lift waits and the dice (slips, stumbles,
falls) so each outcome is chosen by the test. It does not cover a connected
client, real elapsed time or a world save and reload.

The art comes from `tests/sprites/create_training_gear.py`.
