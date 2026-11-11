# Admin player map

`code/modules/admin/verbs/player_map.dm` gives admins and moderators the
"Player Map" verb (Admin tab): a live map of any level with every player on it,
coloured by side. It reuses the tactical map's terrain sampling
(`tactical_maps.terrain_for`). Clicking a marker or a name selects that mob;
the panel can jump to it, follow it as a ghost, or open its player panel or
variables.

- `test_admin_player_map.py` (offline CI suite `admin_player_map`): include and
  verb list wiring, the staff guard on the verb, page and every Topic action,
  the admin jump switch, script-block escaping, and the page's client script
  run in Node with a stub canvas and DOM (marker picking, ghost/NPC filters,
  panel links, level picker, names set only as text).
- `native_probe.py` + `native_probe.dm`: developer evidence, not CI. Compiles a
  temporary DME with the probe appended, runs it once in DreamDaemon on the
  default map and checks the staff guard, level data, marker states and sides,
  the page and the refresh timer. It writes the page to `playermap.html` in the
  evidence directory for a screenshot.

```text
python3 -I -B tests/admin_player_map/test_admin_player_map.py
python3 tests/admin_player_map/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
```

Neither is real-client acceptance: the browser window, live refresh over
`output()` and jumping or following from a Dream Seeker client were not
exercised.
