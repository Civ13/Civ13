# Upper-window lob verification

In-game entry: stand outdoors in line with a visible window or exposed upper floor,
hold a throwable item in the active hand, and use **IC → Lob Upstairs**. This
opens Look Up if needed. Pick a target and check the preview before confirming.
A miss or blocked opening stops outside. This action does not prime, pause, or
extend a fuse. Ordinary Throw is unchanged. Grabs, tied items and lit bottles are not admitted.

The isolated native fixture checks an empty frame, open and closed casements,
bars, shutters, fixed glass, an interior blocker, a roof on the approach,
range and skill, a window closing midflight, fuse expiry midflight, and landing
ordinary items on a ledge or through a window.

```sh
python3 -B scripts/ci_baseline.py unit --suite throw_launch --output /tmp/throw-launch.json
python3 -B tests/ecology_spawning/run_linux.py . tests/throw_launch_clearance/window_lob_probe.dm 300
```
