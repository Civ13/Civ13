# Cable risers, bus tie switches and ladder pairing

```
python3 tests/cable_risers/run.py --byond-bin <pinned bin> --output <empty directory>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless on a 6 x 6 x 3 world. It checks that a pair of cable risers joins
the cables on the same x and y of adjacent levels into one grid, that a
consumer on level 3 draws from an engine on level 1 only through risers on all
three levels, that unfastening or destroying a riser and cutting a cable split
the grid without stale cross-level links, that riser links are runtime only,
that a bus tie switch joins two runs on its tile only while closed, and that
ladders pair through `multiz_level_above()` and `multiz_level_below()`.

Not covered: connected-client use, save and reload of a riser pair on a
multi-level map, and dug-cave or building-level maps (their level order comes
from the same helpers).
