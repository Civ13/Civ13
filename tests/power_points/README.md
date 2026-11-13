# Power points (distribution transformer)

```
python3 tests/power_points/run.py --byond-bin <pinned bin> --output <empty directory>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless on a 12 x 12 world. A secured transformer placed while map autolink
is held joins its cable and feeds a lamp on release. A transformer secured on a
cable feeds the lamp in reach with a clear line, not one behind a wall turf or
one six tiles away, and leaves a lamp with its own cable alone. A lamp built in
reach joins by itself; moving out of reach releases its reservation and moving
back rejoins; a stale lamp out of reach is refused at draw time. A simulated
reload (machine links kept, transformer links dropped) is adopted again by
`after_load`. Unfastening, cutting the cable under it and destroying it release
every fed machine.

Not covered: a connected client using a wrench or coil, real movement events
(the fixture places lamps directly and calls `power_point_moved`), and closed
doors or windows on the line (only the opaque wall turf is exercised).
