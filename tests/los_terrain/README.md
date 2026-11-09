# Height-aware line of sight

`code/modules/visibility/los_terrain.dm` hides targets that ground between the
eye and the target rises above (see docs/terrain-height.md#line-of-sight).

`run.py` compiles that file and the height parser from
`code/modules/1713/terrain_height.dm` into an isolated world with `probe.dm`,
runs it on Gaia's height file for 300 random eyes (step offsets, standing and
lying, view radii 4 to 12) and compares every hidden ground cell with an
independent Python restatement of the sweep. It also prints the cost of a fresh
sweep and of cached lookups, checks that a height change clears the cache and
refreshes viewers, and runs the extracted 2D blocker query with heights: from
a hill, ground well behind a lower wall shows, ground right behind it and
anything behind a tree stays hidden, and indoors or on flat ground nothing is
seen over the wall. Finally it checks NPC sight (`los_terrain_ray_blocked`) for
3000 random viewer/target pairs against a Python reference, requires at least
90% agreement with the sweep and prints the cost per ray.

```
source /root/byond-516.1688/byond/bin/byondsetup   # or pass --byond-bin
python3 tests/los_terrain/run.py
```

It prints `LOS_TERRAIN PASS` and exits 0 on success.
