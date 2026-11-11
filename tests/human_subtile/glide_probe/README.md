# Dream Seeker glide probe

Small worlds that show how Dream Seeker 516.1688 draws free-movement pulses.
They are not compiled by CI; run them by hand on Windows.

- `glidetest_legacy.dme` / `glidetest_pixel.dme`: a fixed camera watching three
  movers under each `world.movement_mode`. Red moves 2px per tick with step
  offsets (free movement), green adds an animated `pixel_w` counter-offset,
  blue takes ordinary tile steps with `glide_size` 8.
- `camtest_*.dme`: the player's own mob walks with free-movement pulses
  (16 x 2px per 13 ticks) and the camera follows it. `camtest_raw` is plain
  pulses, `camtest_smooth` is `human_subtile_smooth_pulse` as shipped,
  `camtest_pixel` is `PIXEL_MOVEMENT_MODE` with `glide_size` set to the pace,
  and `camtest_smooth3/4/5` are rejected variants.

Run: compile with `dm.exe`, start `dreamdaemon.exe <name>.dmb 5191 -trusted`,
connect `dreamseeker.exe byond://127.0.0.1:5191`, size the map to 800x600 and
record the "glidetest" window with
`ffmpeg -f gdigrab -framerate 100 -draw_mouse 0 -i "title=glidetest" -t 5 -c:v libx264rgb -crf 0 -preset ultrafast out.mkv`.
`python3 analyse_camera.py out.mkv` and `python3 frame_motion.py out.mkv`
measure the camera from the checkerboard and the red mob.

Results (2026-11-11, 800x600 client, ~70 fps capture):

| world | new frames/s | 50 Hz frames with no camera motion |
| --- | --- | --- |
| camtest_raw | 25 | 52% |
| camtest_pixel | 25 | 52% |
| camtest_smooth (shipped) | 44-45 | 26-27% |
| camtest_smooth3 (zero-time chain) | 50 | 52% |
| camtest_smooth4 (relative) | 53-55 | 54% |

In legacy mode an atom with a step offset is never glided, and
`PIXEL_MOVEMENT_MODE` did not glide the camera either. Setting the offset and
animating it back with `ANIMATION_PARALLEL` is the only variant that moved the
camera between ticks; the mob stays locked to the camera. It still shows an
occasional 2-4px catch-up when an update reaches the client early or late.
