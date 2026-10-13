# Wall material appearance regression

Run `run.py --byond-bin <516.1681-bin> --output <fresh.json>` with a verified Python interpreter. Repeat with `--negative-control smoothing`, `duplicate`, and `overlay`. The runner compiles baseline and candidate production wall procedures, real wall constructors and update overrides together, using native turfs, images, cardinal adjacency and disk storage. External lighting requests use an isolated adapter. Native outputs live in temporary storage; reports and compiler/runtime logs remain beside the requested output.

## Measured work and parity

Windows BYOND 516.1681, 32x32x1 world, immutable baseline e3c8d02f31f1a23c1320eaec949fb4af56e964f3:

- 1,536 scenes, 4,608 ordered appearance comparisons, zero appearance or count failures.
- All 16 cardinal adjacency masks; ordinary, sub-bulkhead, abashiri and old-stone walls; dense/open states; damage 0/40/100; all four cardinal directions; material recolor/reassignment and null material.
- Four whole-world disk round trips use the actual production saver and two-pass loader, including native replacement. Restored baseline/candidate groups match.
- Smoothing omission: 3,000 appearance and 3,072 count mismatches. Duplicate restoration: zero appearance but 3,072 count mismatches. Reordered bulkhead overlays: 1,152 appearance mismatches and one restored-group mismatch.

| Dense wall, four joinable neighbors | Neighbor checks before/after | Overlay rebuilds before/after |
|---|---|---|
| Ordinary / sub-bulkhead | 15 / 10 | 16 / 11 |
| Abashiri | 20 / 15 | 21 / 16 |
| Old stone | 10 / 5 | 11 / 6 |

Only the final redundant `set_material()` refresh is removed. The final pass inside `update_material()` remains: removing it changes existing damage/open-wall appearance. No new cache, timer, deferred interaction, persistent field or art is introduced. Both variants populate the same existing finite 34-key fixture cache.

This is measured native work reduction, not a percentage server speedup. Timing/RSS benchmarks are omitted because the patch adds no retained state and the active Gaia owner controls live profiling; this fixture does not establish Gaia latency, multiweek memory behavior or 4x-scale readiness. Images and ordered appearance fields (including transform coefficients) match; unchanged DMI hashes cover the same animation resources, but connected-client animation is not exercised. Source and native parity resolve the uncertainty here, so no gameplay capture was required.

The save fixture compares existing reconstruction behavior, using the current production turf allowlist (icon_state/name). It does not claim newly durable wall material, damage or direction fields. Real production wall constructors are imported, while normal game startup, players and lighting execution remain isolated. Reports record source/support/resource/probe hashes and the local HEAD plus dirty patch; exact-head CI repeats every mode and retains its evidence artifact.

## Scaling and subsequent candidates

Gaia has two existing 500x350 levels: 350,000 tiles. Provisional fourfold area is 1000x700x2, or 1,400,000 tiles; no map expansion is implemented or validated by this PR.

- Floor updates clear/rebuild overlays and optionally update neighbors. Coordinate radiation edits with its current owner before changing that path. Audit the existing global flooring cache key against resource, direction and layer before extending it.
- Wall images already use a global state/color cache. New caching requires bounded cardinality and explicit invalidation; this patch adds none.
- getFlatIcon recursively composites native icons. Source call-site counts are not runtime frequency; vendors, human examine and telephone code are subsequent profiling candidates.
- Wall construction/deletion also refreshes lighting in view(21,src). Reuse the existing bounded lighting scheduler if actual queue measurements justify further work.