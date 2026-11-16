# Window fittings

`python3 tests/window_fittings/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 12x12 world with
real humans, walls and window frames, checks
`code/game/objects/structures/window_fittings.dm` and its hooks in
`tile_occupancy.dm`, `door_fittings.dm` and `window.dm`:

- a casement goes only in an empty window frame with the square opening it is
  drawn for, shutters on any frame, one per tile, and an ordinary door can't go in a frame;
- a shut casement is solid and see-through, and walking into it does not open
  it;
- an open casement lets thrown things through but not people, who climb
  through it both ways unless the far side is blocked;
- closers are refused; a spring latch fits on the fitter's side and catches
  when the casement shuts, keeping it shut from outside;
- shutters are opaque shut and step aside open, ignore bumps, and take bar
  brackets and a bar from the inside;
- glass used on shutters glazes the frame behind them, and a frame with a
  casement refuses a fixed pane;
- iron shutters are tougher;
- no runtime errors.

It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).
