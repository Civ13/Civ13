# Admin map

`code/modules/admin/verbs/admin_map.dm` gives staff the **Admin Map** verb: one
live map of a level with the players, the weather systems, the wind and the air
grid as layers. It is the former Player Map and Weather Map in one window.
Admins and moderators see names and may jump, follow or watch; admins and
debuggers may send, end or clear weather; a debug-only holder sees unnamed dots.

- `test_admin_map.py` (offline CI suite `admin_map`): include and verb wiring,
  the three guards and which Topic actions sit behind each, and the page's
  client script run in Node with a stub canvas and DOM (skipped without Node):
  picking players, storms and spots, every button's link, the layer switches,
  the air readout, the unnamed view and opening with a player already picked.
- `native_probe.py` + `native_probe.dm` (developer evidence, not CI): compiles
  the game with the probe appended and runs it once in DreamDaemon with no
  client. It checks markers, level data, sending and ending weather, the update
  payload and the refresh timer, and writes `adminmap.html` for screenshots.

```bash
python3 -I -B tests/admin_map/test_admin_map.py
python3 tests/admin_map/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
```

Not covered: a real Dream Seeker window.
