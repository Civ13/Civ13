# Geometric line-of-sight cost

Record for issue #3582 (follow-up to #3233). Geometric line of sight is on by
default (`CIV13_GEOMETRIC_LOS_CORE`).

## Measured: one client (2026-11-04)

Pinned BYOND 516.1688, master build, on a maintainer PC, never the live server.

| Measurement | Result |
| --- | --- |
| Line-of-sight refresh, small test scene | about 11 ms per refresh |
| Line-of-sight refresh, Gaia | about 23 ms per refresh |
| Tick usage while moving on Gaia, line of sight on | 20.7% |
| Tick usage while moving on Gaia, line of sight off | 16.1% |

These figures predate later changes in both directions: height-aware sight
(hills, seeing over walls) added work per refresh, while keyed mask sets, the
audit scan that skips an unchanged scene, transparent movers re-decided alone
and bullets exempt from invalidation removed work. Treat them as a dated
reading, not the current cost.

## Not measured

The issue was closed on 2026-11-15 with these items unmeasured, by the
maintainer's choice:

- Server cost with several clients at once, where the per-viewer cost adds up.
- Mask image churn and network cost per client while moving, panning and
  toggling doors.
- Memory held per active context and released on disconnect.

Until they are measured, make no RAM-saving or supported-player-count claim
for line of sight, as #3233 states.

## How to measure them

[tests/los_cost_probe](../tests/los_cost_probe/README.md) is the tool: it
scripts 1, 2, 4 and 8 guest Dream Seeker clients through standing, walking,
camera pans and a door on a small map and on Gaia, with line of sight on and
off, and records per-proc server time, mask image churn, bytes sent to the
clients and Dream Daemon memory. Its boot, scene search and result pipeline
were run headless on Linux; its client-driven phases have not been run yet.

It needs a Windows PC with BYOND: GitHub-hosted Windows runners boot the world
but Dream Seeker 516.1688 crashes on connect there (see the probe's README).
