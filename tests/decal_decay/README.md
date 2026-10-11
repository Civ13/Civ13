# Timed decal lifecycle

Run `run.py --byond-bin <trusted BYOND516.1681bin>` for production-source regressions, and add `--baseline` to reproduce the historical cleanable source from master4e88bbf623a8de7b7182e9912f2d3c26745f6e57. The declaration-only baseline shim allows the unused new process to compile; baseline executes the original sleeping timers.

The fixture disables normal startup/maps and uses temporary saves, outputs and owned processes. It checks early-qdel retention, expiration bookkeeping, unchanged lifetime, idempotent scheduling, native save exclusion/restoration, rawDel, blood registry cleanup and20cycles of1024decals with a256-candidate cap. Historical timer expiry callsDestroy directly and the historical early-qdel object remains alive until its sleeping callback wakes.

Production lifetimes remain unchanged, including blood6hours and uncovered-water1second. Processing adds backlog latency up to a sweep (ceil(N/256)seconds for a stable population), plus scheduling delay. Existing duplicate/weather cleanup remains intact. Runtime deadlines reset on load; no per-object sleeping decay callbacks remain. RSS is separate short-run evidence and does not prove multiweek full-game memory stability. No production actions are performed.
