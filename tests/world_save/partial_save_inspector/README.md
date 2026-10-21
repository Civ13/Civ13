# Incomplete-save structural inspector

This Linux diagnostic examines a private copy of one incomplete version-2 level
file. It reports at most 12 descending numeric entry IDs, saved type paths and
bounded field names. It never imports the save into the game or reads saved
field values through native deserialization. An entry or field can be unfinished
or outside this window, so the report cannot prove which live relationship
caused a save failure. It does not repair or validate a recovery checkpoint.

The self-test needs existing BYOND 516.1681 binaries and an ordinary non-root OS
user. It compiles two standalone worlds in a fresh private staging directory,
creates only synthetic saves, and checks unknown type paths, numeric shard
order, scalar-value omission, malformed-input rejection and unchanged bytes.
The self-test rejects any `--source` argument and returns before copying a source.

```sh
python3 -B -m unittest discover -s tests/world_save/partial_save_inspector -p test_inspector.py -v
python3 tests/world_save/partial_save_inspector/inspect-partial-save.py \
  --self-test-only --byond-bin /path/to/byond/bin
```

Native execution uses the project's required `-trusted` mode, loopback binding,
closed ports, disabled clients, fixed audited source, timeouts and OS resource
bounds. Trusted mode is not a BYOND filesystem sandbox. The subprocess retains
the invoking OS user's normal permissions. No production game source is included.

Only `selftest-summary.json` is a public synthetic receipt. Keep staging saves
and native logs private. CI invokes synthetic-only mode and uploads only that
fixed-value receipt, never a source save or the staging directory.

Real inspection is a separate operator action, requires an explicit absolute
`--source` ending in `map_saves/2.sav`, and uses the existing binaries at
`/usr/local/byond/bin`. It first passes the same synthetic native checks, then
copies a bounded regular file without following symlinks or replacing any file.
It checks the source twice while copying, verifies copy bytes after native
inspection, and rejects a report if the original bytes changed. Run only within
an approved read-only diagnostic window. Share only the sanitized `report.json`,
never the private input or native logs.
