# Player activity recorder

Checks the recorder in `code/modules/player_activity/player_activity.dm` that
appends per-account play sessions, heartbeats, server health, deaths, travel
and world saves to `data/player_activity/<date>.jsonl` when `PLAYER_ACTIVITY 1`
is set.

- `python3 tests/player_activity/test_source.py` checks the wiring (client join
  and leave, travel depart/arrive/refusal, death hook, save notice through
  `text2path`, reboot), the off-by-default flag and that no IP, computer id,
  chat or character name is written.
- `python3 tests/player_activity/run.py --output <dir> --byond-bin <bin>`
  compiles the unchanged production file with small stubs and runs it in
  DreamDaemon: causes of death, travel methods, refusal classes, the written
  lines, counter merging, one header per file, the 2000-line cap and the off
  switch.

Not covered: real client sessions and heartbeats in a full world; that needs a
native game run.
