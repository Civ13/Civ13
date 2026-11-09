# Trench climb

Players could not climb out of trenches with smooth movement. A smooth step
moves 2px at a time, so at the trench edge the body already overlaps the tile
outside. The trench exit check counted that body as a dense blocker on the
target tile and refused every attempt, leaving the player sliding along the
edge. Smooth steps now leave a change of trench level (bare trench versus
ground, bridge or frame) to the tile path, the exit check skips the climber,
and every finished climb places the body squarely on its tile.

Free movement now climbs from between tiles. A body walks freely up to the
first overlap with a tile at another level and the next input climbs there,
keeping its sideways offset when the tiles beyond allow it (otherwise it lands
on the nearer open tile). Climbing in takes 0.5 s and climbing out 2 s, as on
the tile path. Ground and bridges share a level, so walking onto a bridge is
smooth. Pulling a living body or being grabbed still settles on the tile and
takes the tile path's climb.

- `test_source.py`: offline source checks (`python3 -m unittest discover -s tests/trench_climb -p 'test_*.py'`).
- `probe.dm` and `run.py`: a full-source native probe with real humans and
  trench turfs. It needs the pinned compiler:

```bash
bash scripts/cloud_byond_setup.sh
python3 tests/trench_climb/run.py --byond-bin "$HOME/byond-516.1688/byond/bin"
```

On master before the fix the probe fails at `edge_offset_climbs_out_aligned`:
the body stays at the trench edge, 30px into its tile.
