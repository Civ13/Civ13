# Cooked meal regression

See [the player route and verification limits](../../docs/cooked-meals.md).
Run `run.py --source-check` for offline mutation-target validation, then the
pinned native positive probe and each of the five `--negative-control` choices.
Output directories must be empty; evidence records the tested head, source
hashes, dirty diff, compile/runtime logs and exact expected result. The runner
removes its unique generated compiler files and uses isolated runtime storage.
No production config/saves, client, Topic request or restart is used.
