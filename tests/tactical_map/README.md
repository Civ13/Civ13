# Live tactical map

`code/modules/1713/tactical_map.dm` gives officers, commanders and squad leaders
a live map of their own side (design reference: CM-SS13's tactical map,
reimplemented; no CM-SS13 code or art is copied).

- `test_tactical_map.py` (offline CI suite `tactical_map`): include and job
  wiring, the officer-only guard on every marker change, the own-side filter,
  and the page's client script run in Node with a stub canvas (clicks map to
  the tile they show; drawing and bad updates do not throw).
- `native_probe.py` + `native_probe.dm`: developer evidence, not CI. Compiles a
  temporary DME with the probe appended, runs it once in DreamDaemon on the
  default map and checks permissions, terrain sampling, blips, markers, the
  page and viewer cleanup. It writes the officer page to `tacmap.html` in the
  evidence directory for a screenshot.

```text
python3 -I -B tests/tactical_map/test_tactical_map.py
python3 tests/tactical_map/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
```

Neither is real-client acceptance: the browser window, live refresh over
`output()` and clicks inside Dream Seeker were not exercised.
