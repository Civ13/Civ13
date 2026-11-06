# Trench climb

Players could not climb out of trenches with smooth movement. A smooth step
moves 2px at a time, so at the trench edge the body already overlaps the tile
outside. The trench exit check counted that body as a dense blocker on the
target tile and refused every attempt, leaving the player sliding along the
edge. Smooth steps now leave a change of trench level (bare trench versus
ground, bridge or frame) to the tile path, the exit check skips the climber,
and every finished climb places the body squarely on its tile.

- `test_source.py`: offline source checks (`python3 -m unittest discover -s tests/trench_climb -p 'test_*.py'`).
- `probe.dm` and `run.py`: a full-source native probe with real humans and
  trench turfs. It needs the pinned compiler:

```bash
bash scripts/cloud_byond_setup.sh
python3 tests/trench_climb/run.py --byond-bin "$HOME/byond-516.1688/byond/bin"
```

On master before the fix the probe fails at `climb_out_uses_tile_path`; with
only the eligibility check removed it fails at `edge_offset_climbs_out_aligned`.
