# Native pooled effect regressions

Run with pinned BYOND 516.1681:

```
<verified-python> tests/pool_effects/run.py --byond-bin <516.1681-bin> --output <fresh-evidence-directory>
```

The fixture compiles complete production sources and constructs real lighting overlays, steam, sparks, smoke, projectile effects, blood splatters and rods. Normal world/global startup and map loading are disabled. A chemical-smoke walk adapter counts calls and delegates to native walk_to without changing delays or movement. Public name configuration is copied to temporary runtime storage. The test world closes its network port and refuses reopening. No normal game services or external effects run.

Checks cover retirement/live state markers, constructor reuse, scalar reset, lighting turf/registry release, blood list reset, smoke helper cancellation, fallback expiry, effect/system sleeping spread callbacks, scheduled sparks expiry, scheduler phase/peer cancellation, chemical smoke delayed movement, projectile updates, per-type/global pool caps and bounded idle expiration. The actual scheduler.fire() processes source expiry, pre-process deletion and cancellation of another task in its copied snapshot; this does not prove production scheduling latency or client rendering, whole-game memory use, or OOM remediation.

`--negative-control` (or `--negative-control lighting`) retains one lighting registry entry in a generated source copy. `--negative-control fallback` restores the stale smoke fallback timer. `--negative-control chem` removes the chemical smoke walk lifetime guard. Controls must detect only their expected ownership assertion and still compile/run without errors; exit success describes detection, not production acceptance.

Evidence retains compiler/runtime logs, compiled fixture, source-hash manifest, pre-generation checkout HEAD/dirty state and patch. Dirty-worktree evidence is identified explicitly; run after committing for clean exact-commit provenance. Generated root sources are removed in finally. Use fresh output directories to preserve prior evidence.

Effect/system identity tokens are runtime-only, released on Destroy and replaced by constructors. Existing sleeping callbacks retain only their old tokens until their existing bounded waits wake; they cannot mutate reused activations. Spark expiry uses production source-bound scheduler tasks; actual destroyed-event cancellation releases the scheduled task and target immediately.
