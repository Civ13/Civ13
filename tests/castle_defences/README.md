# Castle defences

`python3 tests/castle_defences/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 16x16 world,
checks `code/modules/1713/siege/castle_defences.dm`:

- a stone wall takes a slit, cut only from a tile square on to it; the slit
  opens away from the cutter, can be seen through, stays solid, weakens the
  wall by 20%, is drawn, and refuses a second slit;
- shots from the tile right behind it pass out about 95% of the time, also 45
  degrees off; shots from further back, and along the wall, use the usual
  rules; shots from outside are blocked about 95% of the time;
- filling the slit restores opacity and health; a gun loop works the same way;
  straw walls refuse a slit;
- a mapped crenelated wall keeps two-way cover; a player-built one faces its
  builder's direction, lets shots out freely, stops most shots in, and fully
  covers someone lying behind it; plain barricades are not battlements;
- no runtime errors.

It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).
