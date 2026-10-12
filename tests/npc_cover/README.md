# NPC cover selection

Run from the repository root with BYOND 516.1681 and a verified Python interpreter:

```powershell
& '<verified-python>' tests/npc_cover/run.py --byond-bin '<516.1681-bin>' --output '<fresh-parity.json>'
& '<verified-python>' tests/npc_cover/run.py --byond-bin '<516.1681-bin>' --negative-control boundary --output '<fresh-boundary.json>'
& '<verified-python>' tests/npc_cover/run.py --byond-bin '<516.1681-bin>' --negative-control tie --output '<fresh-tie.json>'
& '<verified-python>' tests/npc_cover/run.py --byond-bin '<516.1681-bin>' --benchmark --output '<fresh-benchmark.json>'
```

The candidate uses original native searches for the first cover turf and gathers
allies once if a second cover turf is scored, without durable caches. Candidate
order, strict greater-than tie breaking, LOS
and scoring stay unchanged. A candidate within three tiles can see clumping
allies within four tiles of the caller and officers within eight. Those broad
lists are narrowed using the original one/five-tile candidate distances.

The fixture compiles both actual production cover bodies together, with actual
`is_good_cover`, `ai_check_los` and `getline2` bodies and native BYOND range,
distance, direction and turf/atom operations. The immutable baseline is
`1627730ecec53f385cbf1956b7a9e4385dffa675`. Simple actor/structure declarations
replace game constructors and startup; no player, production save, external
service or game process runs. The runtime closes its port and rejects reopening.
Temporary compiled files are removed even after failure; logs and provenance
are retained beside the requested fresh output.

One hundred scenes compare every evaluated candidate score and the selected
turf. They cover ties, bare ground, dense/opaque turfs, structures and oriented
barriers, allied/enemy factions, officers, edge positions, contained actors,
another z-level and a null enemy. Generated controls shrink officer distance
five to four or replace strict greater-than with greater-or-equal; each must
produce a detected mismatch. Helper drift fails closed rather than silently
testing old helpers against changed production behavior.

Benchmarks run uninstrumented production bodies in the same native process on
identical scenes. After warmup, five paired groups alternate variant order, with
1,000 complete decisions per variant and scene (empty/sparse/crowded). Every
measured choice must match the baseline. Native `world.timeofday` reports elapsed
deciseconds, including any engine stalls inside the measured loop. This is wall
time at engine clock resolution, not process CPU or whole-server latency. Sleeps
between groups are excluded. CI runs parity and controls, without noisy timing
thresholds; runtime suites stay opt-in after their introducing PR.

These checks establish native decision parity in controlled scenes. They do not
establish combat movement, client presentation, production latency or OOM fixes.

## Recorded native results

Windows BYOND 516.1681, 32x32x2 fixture, five alternating pairs with 1,000
decisions per variant per scene. `measurements.json` retains every timing sample,
source/probe hashes and provenance; full parity outputs and logs are preserved
under `D:/GitHub/civ13-preview-evidence/npc-cover-3109/` locally.

| Scene | Baseline median (ds) | Candidate median (ds) | Interpretation |
| --- | ---: | ---: | --- |
| Empty | 0.1875 | 0.2500 | About 6.25 microseconds/call overhead, near timer resolution |
| One cover | 0.3750 | 0.3750 | Tied at this resolution |
| Crowded cover | 5.8125 | 5.1250 | About 11.8% lower elapsed time |

All 100 parity scenes and 4,495 candidate scores matched. All 30,000 timed
decisions matched their baseline choices. The final boundary control detected
24 mismatched scenes and the tie control detected 21. These controls change
generated source only. Baseline and candidate have identical cold/LOS helpers.

The first broad-gather candidate improved crowded timing by about 20% but added
one-cover cost. The first delayed-gather implementation redundantly checked
already-filtered factions/roles and was slower in the crowded scene. Both were
rejected in favor of the explicit original first-cover path and filtered cache
path. The empty-scene overhead remains explicit; this patch targets repeated
cover scoring, not a universal improvement. No production CPU or latency gain
is claimed, and no screenshot was needed to resolve the native choice parity.
