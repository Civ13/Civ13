# Day/night and weather transitions

Day/night lighting and outdoor weather appearances update progressively. Each has one active worker. A newer request received during a pause replaces the pending target; the worker restarts toward that target rather than launching another world sweep. This does not change seasonal durations, climate/weather selection, research gates or debris decay rules.

Daylight keeps the existing area and z-level exclusions and dynamic-lighting rules. All lighting overlays still receive the time-of-day label, including excluded areas, for consumers such as vampires. Wasteland Two zombie spawners follow the completed Night/Morning request; an older request cannot overwrite the newer completed effect. Administrators receive completion messages for the target that finishes.

The worker pauses after at most 4,096 overlay/turf/area visits, or once the current tick reaches 20% usage. The threshold is checked after a visit, so a single visit can exceed it. At the fixture's 20 FPS this is about a 10 ms script budget followed by at least one 50 ms tick sleep. It is a responsiveness tradeoff: spreading work across ticks can make the visible transition take longer. It does not guarantee production latency, instant transitions, client rendering performance or long-term memory stability.

Weather retains the existing per-climate, per-season outdoor appearance/intensity rules, indoor exclusions and radiation prefix. A new weather request during a pause is applied by the same worker. No additional timer chain, registry or copied world list is introduced. Save formats are unchanged.

For discarded rubbish and unrecoverable spent casings, see [abandoned item decay](abandoned-item-decay.md). Admin-forced seasons default to **Keep decay age**; **Advance decay age** explicitly counts the transition. Natural seasonal transitions count normally. This daylight/weather scheduler does not advance debris age.

## Repeatable isolated verification

Use BYOND **516.1681** and a verified Python interpreter:

```text
python-path tests/environment_sweeps/run.py --byond-bin byond-bin --baseline --size 128 --areas 256 --output-metadata baseline.json
python-path tests/environment_sweeps/run.py --byond-bin byond-bin --size 128 --areas 256 --compare-metadata baseline.json
python-path tests/environment_sweeps/run.py --byond-bin byond-bin --size 128 --areas 256 --negative-control yield
python-path tests/environment_sweeps/run.py --byond-bin byond-bin --size 128 --areas 256 --negative-control overlap
```

The baseline is pinned to commit `9ea42a6c5269d4970672655460ca96a3a7ec07f6`. Git history must contain it. `--size 256 --areas 4096` exercises 131,072 turfs and actual shared lighting corners/color matrices, plus 4,096 synthetic areas across eight climates. These are representative workloads, not a clone of a particular map.

Normal world startup, map loading and outbound game systems are disabled. The fixture measures production sweep bodies and lighting calculations, verifies final colors/TOD, area/z exclusions and radiation behavior, latest-request behavior, released single workers and Wasteland effects through an injected spawner adapter. It compares complete outdoor/indoor weather state digests with the original source. Mutations remove yielding or the worker guard and must fail their respective contracts. Compilation alone is insufficient.

Each run prints its temporary evidence directory, containing compiler/runtime logs, tested commit and dirty patch, phase metrics and weather digests. Setup and assertion scans are excluded from timing. A heartbeat samples every world tick; `world.timeofday` supplies elapsed timing (6.25 ms resolution observed on Windows), and `world.tick_usage` supplies script tick usage. The latter measures the current tick, not OS process CPU or memory. Timing is machine-dependent. A path-filtered CI workflow repeats bounded Linux fixtures on the exact PR commit.

The headless probe does not reproduce client/engine appearance costs, player activity, save imports during a transition, production lockups or multiweek memory behavior. No deployment or production transition is part of this verification.

## Windows representative measurement

On an isolated 256 x 256 x 2 fixture (131,072 turfs/overlays, 4,096 areas), three original daylight sweeps took 2.70-3.04 seconds, reaching approximately 90% tick usage (45 ms of a 50 ms tick) and 94-100 ms heartbeat gaps. The bounded production sweeps took 7.71-9.26 seconds, reached approximately 20.1% (10 ms), and had 56.25 ms maximum heartbeat gaps. These measurements include trace instrumentation on both versions and show the transition-duration tradeoff; they are not a production service guarantee. Original weather script work completed within about 3-6 ms on this workload, so the reported weather lockup was not reproduced. The weather change adds a bounded worker and verifies unchanged outcomes, without claiming a measured production weather speedup.
