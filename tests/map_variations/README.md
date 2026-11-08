# Map variations

Per-round battle map variations (idea after CM-SS13's "nightmare" inserts,
AGPL-3.0; reimplemented). Before each round the pregame lobby lays one weighted
variant over each slot listed in `maps/zones/variations/<map id>/variations.json`;
`code/modules/map_variations/map_variations.dm` is the loader.

- `build_inserts.py` generates every slot, variant and insert. Change it and
  regenerate instead of editing the DMMs. Changes only land on open ground in
  the base map and are mirrored across the slot's north-south centre.
- `test_map_variations.py` (offline, CI) checks the generator is current, slot
  bounds and overlap, open-ground placement against the base maps, mirroring,
  defined types and the loader rules.
- `native_probe.py` (developer evidence, not CI) compiles the game with a map
  selected, lets pregame pick its variants, then lays every variant and checks
  each cell in DreamDaemon.

```text
python3 -I -B tests/map_variations/build_inserts.py [--check]
python3 -I -B tests/map_variations/test_map_variations.py
python3 tests/map_variations/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --map maps/1903/hill_203.dmm --output /fresh/dir
```

To add a map: add an entry to `SLOTS` in `build_inserts.py` with the map ID,
base DMM and slot rectangles, regenerate, and add the base map and its
metadata file to the `map_variations` entry in `scripts/ci_baseline.py`.
Insert files are overlays, so `scripts/maplint.py` skips them.
