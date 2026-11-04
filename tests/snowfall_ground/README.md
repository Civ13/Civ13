# Generated ground snow tests

- `test_snowfall.py`: offline source projections and contracts (CI suite).
- `native_probe.dm`: native module fixture used by the isolated native lane.
- `full_game.py` + `full_game_probe.dm`: headless full-game acceptance run on
  the Gaia map (#3312). It appends the probe to a temporary copy of
  `civ13.dme`, runs DreamDaemon once from a fresh evidence directory and checks
  `result.json`:

  ```bash
  source "$HOME/byond-516.1688/byond/bin/byondsetup"
  python3 tests/snowfall_ground/full_game.py --byond-bin "$HOME/byond-516.1688/byond/bin" --output /tmp/snow-run
  ```

  It drives the production code only: forced season changes to winter, real
  `change_weather`/`get_temp`, heat sources, roofs and level connection,
  shovel/spoon/ant actions with headless awake actors, floor `update_icon`,
  `ChangeTurf` and `qdel`, a real `savemap`/`loadmap` round trip with an
  elevation region and zone topology, the scheduled worker accumulating over
  the whole map with 40 extra actors, and the winter-to-spring melt. Expect
  about 65 minutes on a cloud container (the save and load take ~20 of them).
  It does not cover client pixels, planes on a real client or footstep audio.
