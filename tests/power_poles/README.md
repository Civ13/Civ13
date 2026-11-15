# Wall outlets and utility poles

```
python3 tests/power_poles/run.py --byond-bin <pinned bin> --output <empty directory>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless on a 14 x 14 world. A wall outlet turns toward the wall beside it,
does not block movement, and once secured on a cable feeds a lamp three tiles
away but not one four tiles away. Two utility poles on separate grids join them
with an overhead wire: the lamp near the unpowered pole draws only after the
wire is strung, the wire is listed on both poles, links the two cables and is
drawn once. A second wire to the same pole and a pole nine tiles away are
refused. Unfastening a pole drops the cable link but keeps the wire; fastening
it again restores power. A simulated reload (runtime cable links cleared)
relinks from the saved `span_poles`. Cutting the wire refunds one cable piece
per tile and splits the grids; destroying a pole takes its wires down without a
refund.

Not covered: a connected client using the coil, wrench or wirecutters, how the
wire overlay looks in game, and a real save and load.
