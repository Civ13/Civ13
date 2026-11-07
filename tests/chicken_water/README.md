# Chicken deep-water navigation

Run `python3 -m unittest discover -s tests/chicken_water -v`, or the registered
CI suite with `python3 scripts/ci_baseline.py unit --suite chicken_water --output /tmp/chicken-water.json`.

The offline suite executes the complete production species predicate, wandering
direction filter, targeted-step dispatch, deep-water `CanPass`, and `iscovered`
bodies through the existing source adapter. Engine location, type inheritance,
and collision dispatch are explicit fakes. It checks hens, chicks, roosters and
descendants, all declared deep-water variants and Gaia's actual ocean types,
legacy saved `flying` values, shallow water, every existing cover category,
stranded birds stepping ashore, other fliers, humans, projectiles and smoke.
Negative controls remove each species override or restore either old call site
and reproduce admission of a flying chicken to deep water.

The change deliberately does not alter `flying`, spawning, egg hatching, or
Persistence restoration. Existing birds are not moved or deleted; a bird already
over ocean can step onto adjacent land or cover but cannot cross more open water.
The shared A* turf filter already excludes uncovered deep water and is unchanged.

These tests are source/control-flow evidence, not native BYOND movement, graphical
acceptance, or a live Gaia save/load test.
