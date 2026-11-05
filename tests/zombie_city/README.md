# Zombie city offline suite and probe

`build_base.py` generates `maps/zombie_city/zombie_city.dmm`, the blank 200 x 200
plain the generator fills at round start (see
[docs/zombie-city-generator.md](../../docs/zombie-city-generator.md)).
`test_zombie_city.py` regenerates the base map, checks the generator's type
names and contract names against the source tree, and tests the checker's grid
functions on small fixtures. `native_probe.py` appends `native_probe.dm` to a
temporary DME with the base map selected, compiles once, runs DreamDaemon once
per seed and then runs `check.py` over the evidence; it is developer evidence,
not CI.

```text
python3 -I -B tests/zombie_city/build_base.py --check
python3 -I -B -m unittest tests/zombie_city/test_zombie_city.py
python3 tests/zombie_city/native_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir --seeds 1 1 2
python3 -I -B tests/zombie_city/check.py /fresh/dir
```

The checker verifies determinism (a repeated seed gives the same city, different
seeds differ), reachability of every insertion point, evacuation point, door and
loot spot from every insertion point, marker counts, insertion and evacuation
spacing, generation time under 30 s and the absence of runtime errors in the
zombie city code. It writes `summary.json` and a PNG preview per seed under
`previews/`. Neither the suite nor the probe is real-client acceptance.
