# Spilled water puddles

Puddles from emptied containers (`/obj/effect/flooding`) draw their water and
edges as their own overlays. They used to paint them onto the turf, which wiped
the turf's own edges and left water drawn on dry dirt after the puddle dried or
was scooped up.

```bash
python3 tests/spilled_water/run.py --byond-bin <BYOND bin> --output <fresh dir>
python3 tests/spilled_water/run.py --byond-bin <BYOND bin> --output <fresh dir> --control turf
```

The runner extracts the production puddle body (minus the bucket-scooping
`attackby`) and its two edge helpers into a 5x5 fixture. Its 16 checks cover a
lone puddle, neighbouring puddles sharing an edge, two spills merging, and
puddles drying beside each other, with the turf's own overlay checked each
time. `--control turf` restores the old turf drawing and must fail.
Not covered: rendered appearance in a client and the 10-minute drying timer.
