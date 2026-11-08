# LOS blocker grid parity

`blocks_target()` in `code/modules/visibility/los_context.dm` finds candidate
blockers through a per-tile grid built by `index_blockers()` instead of
scanning every blocker in the target's bounding box. The grid only narrows the
candidates: the exact `los_target_blocked()` test still decides, and blockers
with a step offset (or a second cell on one tile) stay in a loose list that is
always scanned.

`run.py` extracts the geometry procs into an isolated world with `probe.dm`
and checks, natively, that the grid answer equals the flat scan over every
blocker for about 25,000 queries: indoor wall scenes, eye step offsets,
moving blockers, fractional targets, both footprint sizes and two view sizes.

```
source /root/byond-516.1688/byond/bin/byondsetup   # or pass --byond-bin
python3 tests/los_blocker_grid/run.py
```

It prints `LOS_GRID PASS` and exits 0 on success.
