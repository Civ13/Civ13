# Seasonal terrain candidate lists

The fixture compiles the production helper and immutable baseline
`e3c8d02f31f1a23c1320eaec949fb4af56e964f3` with native BYOND 516.1681 in
isolated temporary storage. It rejects compiler warnings/errors and runtime
errors. Its world closes its port and refuses reopening.

Run with a verified full Python interpreter path:

```text
<python> tests/season_terrain_filter/run.py --byond-bin <516.1681-bin> --output <fresh.json>
<python> tests/season_terrain_filter/run.py --byond-bin <516.1681-bin> --large --output <fresh-largest.json>
<python> tests/season_terrain_filter/run.py --byond-bin <516.1681-bin> --negative-control --output <fresh-control.json>
```

Default geometry is 64x48. Largest geometry is 660x550x1 = 363,000 turfs,
matching `maps/nomads/nomads_persistence_beta.dmm`, the largest non-WIP
Nomads map. Its `/obj/map_metadata/nomads/persistence_beta` inherits automatic
season calls from `nomads/New()`. Geometry does not load the actual map.
Of 261 checked-in DMM grids audited by key width and row count, the largest
non-WIP standalone map is `maps/1013/whiterun_rp.dmm`, 355x355x3 = 378,075;
Whiterun metadata does not start automatic seasons. WIP nomads_western is
650x400x2 = 520,000. Current DME includes nomads.dmm, 155x225x2 = 69,750.

Ordered selection covers area path/text/instance, parent/subtypes, distinct
areas in deliberate order, predicates, unchanged unfiltered API, and native
turf replacement across 16 cycles. Inert distractors are 800 objects and 80
mobs, not connected players or production constructors. The generated-source
negative control omits the filter: typed parity remains valid while candidate
list bounds must fail. Source guards check exact turf arguments at base season
callers. No production source is mutated by controls.

Benchmarks alternate four baseline/candidate pairs for sparse match (12.5%),
dominant match (87.5%), and unfiltered API modes. Both filtered modes perform
the original native typed loop after selection; visits must match. Reports
contain list slots, peak per-list slots, coarse native wall time (deciseconds),
whole-daemon elapsed seconds, HEAD, patch and source hashes, and saved logs.
Slots measure candidate references, not process memory. Wall time is not server
CPU or latency; compare repeated pairs and do not infer CPU improvement from
slot reduction alone. Inert synthetic membership is not actual terrain mix.

Fresh per-pass snapshots and unchanged pass order matter. Native replacement
retargets saved turf refs. Caching across transitions or combining passes can
change membership and RNG consumption. Existing callbacks were source reviewed
for synchronous changes to later candidate types; current turf replacement and
neighbor icon updates do not establish generalized callback parity. This test
uses real native replacements but synthetic turf constructors. It does not
execute full seasons, weather, live players, persistence, or game constructors.
Never apply turf filtering to the existing object-on-turf-list loop. Predicates
used in this fixture are pure; filtering before predicates can change calls to
side-effectful predicates, so new filtered callers must use pure predicates or
none. Existing unfiltered calls retain their predicate behavior.

Each cycle replaces at most 256 turfs (4,096 total), even in largest mode.
Stored object/mob identities and retargeted locations must survive. Process CPU
seconds measure the whole daemon and include startup and assertions; per-mode
paired results report wall time only. Source guards also normalize added arguments
and compare the complete season procedure to its immutable baseline. Without
--output the runner chooses a fresh temporary evidence path.

The persistence-beta grid initially has 339,704 forest-family turfs. Within
those areas the main defaults are deep saltwater 152,126 (44.8%), grass 107,000
(31.5%), dirt 19,145 (5.6%), sand 13,238, deep water 10,689, water 9,401,
shallow saltwater 8,200, underground dirt 6,954, jungle grass 5,599 and jungle
dirt 3,779. These are source defaults before map generation/runtime seasons.
Synthetic sparse/dominant modes test opposite density extremes rather than
reproducing those defaults.
