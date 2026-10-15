# Process replacement ownership

The native fixture compiles actual scheduler replacement/state/priority procedures, base configuration copy and chemistry setup/fire/continuation procedures. It executes 39 replacements spanning completed, queued and running states. Checks distinguish ownership before deletion from actual native retirement afterward, preserve ordered work and history, and forbid setup replay. Chemistry's first pass deliberately yields after one holder; replacement must resume the remaining snapshot.

Run `run.py --byond-bin <516.1681-bin> --evidence-dir <fresh-directory>`. `--baseline` reads immutable pre-fix commit `112e80ba4bc0f5af417b46532a4718aba9601ca5`. Separate `--negative-control bookkeeping`, `configuration` and `chemistry` omit actual fixes in generated source. Controls succeed only when their specified fault categories occur with no unexpected faults or runtime diagnostics.

`--prepare-only` writes source/hash provenance without invoking a compiler or runtime. A prepared fixture is not native evidence. The runner closes the native port, refuses reopening, uses isolated storage and requires BYOND 516.1681 with zero compiler errors/warnings and clean runtime diagnostics. Evidence retains production originals, extracted source, dirty patch, exact HEAD and logs. Counts describe scheduler membership and work continuity, not a proven lasting memory leak or measured server performance improvement.

Restart remains idle and does not replay setup. Other subtype restart contracts, real hung sleeping callbacks, full-game acceptance and deployment are outside this regression.
