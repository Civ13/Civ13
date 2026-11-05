# Zombie city offline suite and probe

`build_base.py` generates `maps/zombie_city/zombie_city.dmm`, the blank 200 x 200
plain (with a level of open sky above it) the generator fills at round start (see
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
seeds differ), reachability of every insertion point, evacuation point, door,
staircase and loot spot from every insertion point (broken windows count as
passable, glass does not) and of every upper door and loot spot from a
staircase, marker and room counts, that every room is at least three cells each
way inside its building and every building's loot spots lie in a room,
insertion and evacuation spacing, generation time under 30 s and the absence of
runtime errors in the zombie city code. It writes `summary.json` and a PNG
preview per seed and level under `previews/`. Neither the suite nor the probe is real-client acceptance.

## Horde, loot and raid world probe

`horde_probe.py` appends `horde_probe.dm` to a temporary DME with
`maps/EFT/crossroads_mall.dmm` selected, runs it once headless and checks
`result.json`. It is developer evidence, not CI, and takes about three minutes:

- every loot table and tier at research ages 0, 5 and 9 (no guns at age 0,
  only age- and tier-allowed items, nothing saved);
- the horde stays inert until a block is registered and rejects unknown densities;
- zombies appear around a clientless anchor body, out of its sight;
- they chase and bite it, a kill lowers the block's total, gunfire noise turns
  idle zombies toward the sound, an anchor one floor up keeps them from folding
  away, and with no anchor left they fold back into the block count;
- evacuation points sort by ordinal, two are open at a time and the next turn
  opens two others, a closed one refuses, and arrivals use the city entry;
- wounds travel in a payload, impossible wounds are refused;
- a raid collapse removes living raiders and their gear and leaves corpses.

```text
python3 tests/zombie_city/horde_probe.py --byond-bin ~/byond-516.1688/byond/bin --output /fresh/dir
```
