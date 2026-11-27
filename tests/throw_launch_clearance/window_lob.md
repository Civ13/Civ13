# Upper-window lob verification

In-game entry: stand outdoors in line with a visible upper window, hold a
grenade in the active hand, and use **IC → Lob at Upper Window**. This opens Look
Up if needed. Pick a window and read the landing preview before confirming.
A miss or blocked opening stops outside. This action does not prime, pause, or
extend a fuse. Ordinary Throw is unchanged.

The isolated native fixture checks an empty frame, open and closed casements,
bars, shutters, fixed glass, an interior blocker, a roof on the approach,
range and skill, a window closing midflight, and fuse expiry midflight.

```sh
python3 -B scripts/ci_baseline.py unit --suite throw_launch --output /tmp/throw-launch.json
python3 -B tests/ecology_spawning/run_linux.py . tests/throw_launch_clearance/window_lob_probe.dm 300
```
