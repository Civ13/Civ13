# Selecting expensive game CI

CI and train workflows always start a lightweight change detector and retain their
stable build/train-collision job names. Documentation-only changes skip game
compilation, recipes, world-save, chemistry, power, boats, batteries and trains.
Offline evidence, API generation, tooling contracts and security analysis remain
enabled: they are inexpensive or validate the documentation/tooling change.

The detector allows docs/, root Markdown, scripts/build-api-docs.py and the two
API documentation workflows. Every other path runs all game suites. This includes
civ13.dme, DM shared defines/includes, maps, assets, config, tests, harnesses,
the selector and shared CI workflows. Full-game probes share compilation and
runtime dependencies, so this deliberately avoids a fragile subsystem path map.

PRs compare base SHA with exact head; pushes compare before with head.
Deleted and renamed old paths are included. Manual runs, missing comparison
commits and failed Git comparisons select all suites. A failed detector or missing
output fails the stable jobs, rather than silently skipping game validation.
The detector runs selection regressions and actionlint on all workflows.
No whole-workflow path filters leave required checks pending.

Run the selection unittest with a verified interpreter:
python -m unittest discover -s tests -p test_ci_selection.py -v
Publication is still restricted to master.
