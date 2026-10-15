# Cooked meal regression

See [the player route and verification limits](../../docs/cooked-meals.md).
Run `run.py --source-check` for offline mutation-target validation, then the
pinned native positive probe and each of the five `--negative-control` choices.
Output directories must be empty; evidence records the tested head, source
hashes, dirty diff, compile/runtime logs and exact expected result. The runner
removes its unique generated compiler files and uses isolated runtime storage.
No production config/saves, client, Topic request or restart is used.

`python -m unittest discover -s tests/cooked_meals -p test_runner.py -v`
checks that asynchronous production runtime formats, native bad refs/locs,
missing completion and nonzero exits reject a run even after a PASS marker.
