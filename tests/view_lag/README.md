# Player view vs ghost view profiler

Manual tool, Windows only. It measures why the game looks laggier from a
player's camera than from a ghost's, and which player-only system is
responsible.

One Dream Seeker client connects to a local daemon running Gaia with the live
config line `DAYNIGHT_CLIENT_TINT`. The probe moves the client through roles,
each in a fresh body on open ground:

| Role | What is switched off |
| --- | --- |
| `ghost`, `ghost_repeat` | Nothing (observer) |
| `human`, `human_repeat` | Nothing (player) |
| `human_no_los` | Line-of-sight masks and the tree compositor |
| `human_no_trees` | Tree compositor only |
| `human_no_fov` | Vision cone |
| `human_no_ao` | Ambient occlusion drop shadow |
| `human_no_lighting` | Lighting (ghost-style vision) |
| `human_no_hud` | HUD updates from Life |
| `human_all_off` | All of the above |

Each role runs four stages: `still` (10 s), `walk` (20 s, the runner holds the
arrow keys), `taps` (15 s, single key presses) and `crowd` (20 s walking past
20 humans who shuffle about).

Measured per stage:

- Server: `world.tick_usage` (average, p95, max), `world.cpu`,
  `world.map_cpu`, a proc profile (`profile_<stage>.json`), the camera mob's
  glide size and step timing, `client.images` and `client.screen` counts.
- Network: bytes sent through a counting proxy.
- Client: a 240 px box at the centre of the map copied from the screen as fast
  as possible. From it: redraws per second, scrolling frames per second while
  walking, gaps in scrolling (hitches over 100 ms and 250 ms) and key to
  picture time for taps.

## Running

```
py -3 tests\view_lag\run.py --byond-bin "C:\Program Files (x86)\BYOND\bin" --output D:\view-lag\run1
```

Keep the Dream Seeker window in front and do not use the mouse or keyboard
while it runs (about 20 minutes after Gaia has started). `--roles ghost,human`
runs a subset. The report is written to `report.md` and `summary.json` in the
output folder; `py -3 tests\view_lag\report.py <folder>` rebuilds it.

`python3 tests/view_lag/selftest.py` checks the report maths offline.

The probe overrides a few procs to switch systems off. It is only ever
appended to a temporary copy of `civ13.dme`; the shipped game never includes
it. Nothing here touches a live server.
