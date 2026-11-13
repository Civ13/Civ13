# Smart cable shapes and map wiring

```
python3 tests/cable_shapes/run.py --byond-bin <pinned bin> --output <empty directory>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless on an 8 x 8 world. Map wiring: cables placed while autolink is held
(as during compiled-map placement) read their shape from `icon_state`, stay
unjoined until the hold is released, then join end to end and attach the engine
and lamp standing on them; a straight crossing stays insulated until a secured
connector (`/obj/item/connector/secured`) joins it, and a nested hold (a runtime
map read) defers a mapped connector until its release. Laying by hand: a run
continues straight, turning onto a loose end from the side makes a corner drawn
with its `d1-d2` state, two loose sides, an overlap or a diagonal facing stay
straight, and a craft turn rotates a corner's ends.

Not covered: a connected client laying cable with a coil, a real compiled map
with cables (no shipped map has any yet) and a dmm_suite runtime read.
