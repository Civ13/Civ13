# Track laying

Players lay railway track one tile at a time (`code/modules/1713/track_laying.dm`,
[docs/track-laying.md](../../docs/track-laying.md)): sleepers, then rails, then a
hammer spikes them down. A crowbar takes track apart in reverse.

```sh
python3 -B -m unittest discover -s tests/track_laying -v
python3 tests/track_laying/run.py --byond-bin <pinned bin> --evidence-dir <fresh dir>
```

`run.py` compiles the full DME without maps through the existing
`isolated_startup` adapter and runs `probe.dm`, which calls the real shape,
spike and pry procs on a 40x12 map: lone tiles, straight lines, corners in
sleepers and in finished track, parallel lines, gap-closing curves, crossings,
unfinished track not counting as rail, step-by-step deconstruction, wagons
blocking it, and switches returning iron. The `do_after` wrappers, item use and
messages are not driven.
