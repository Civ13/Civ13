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
- `client_check.py` + `client_probe.dm`: the real-client check (#3594), Windows
  only and not run by CI. It builds a temporary copy of `civ13.dme` with the
  probe, starts the daemon on a loopback port in a fresh evidence directory,
  connects one Dream Seeker client and saves a picture of the client window at
  each stage:

  ```bat
  py -3 tests\snowfall_ground\client_check.py --byond-bin "C:\Program Files (x86)\BYOND\bin" --output D:\snow-client-run
  ```

  The probe forces winter and snow weather, stages walls, a roof, a tree, tall
  grass, a loose item and a bystander on a Gaia grass field, accumulates snow
  with the production check, then moves the connected client into a body
  there. It photographs the scene by day, at night and beside a lit brazier,
  walks the client over snowed dirt, snowed grass, melted and bare ground
  through `client.Move`, and shovels through `ClickOn`. `result.json` lists
  the footstep sound sent to the client on every tile. It does not record
  audio, and someone still has to look at the pictures in `shots/`.
  `-params headless=1` on the probe rehearses staging and shovelling with no
  client (Linux works); that mode cannot pass the client checks.
