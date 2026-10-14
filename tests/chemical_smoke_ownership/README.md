# Chemical smoke source ownership

The two active callers (`Chemistry-Recipes.dm` smoke reaction and `magic_recipes.dm` Welsh darkness powder) each construct, attach, set up and start a fresh system. Neither reuses it or calls `spawnSmoke` directly. The historical system creates a locationless atom with a reagent holder and never retires that source. Its atom/reagents back reference survives after particles have copied their mixture. This is a concrete ownership cycle in OpenDream manual reference counting; source review alone does not quantify live-server memory impact.

The system now owns retirement. `start` queues the same emissions and waits for every callback to finish copying reagents before `qdel(src)`. `Destroy` clears its hidden atom reference and uses the actual atom/reagent cleanup, including chemistry membership removal. Repeated start is ignored. Explicit cancellation is idempotent and queued callbacks skip emission. Particle constructors, copied amounts, duration arguments, movement and fades remain production code. Other smoke system types are unchanged.

`run.py` includes the real game definitions but disables global/world startup and map loading in generated source. It runs production constructors, setup, start, spawnSmoke, qdel, reagent cleanup and particle/pool cleanup in a temporary offline world. The single observation hook follows the real reagent copy; it checks water amount and constructor lifetime without replacing either. Thirty-two transient systems must release hidden holders and chemistry membership after their queued emissions. Additional cases cover multiple emissions, no location, and cancellation before emission. Assertions deliberately retain test-owned handles until inspected; they establish lifecycle state, not CLR root counts, RSS, full-world chemistry or combat behavior. Production particle fade and cleanup can yield; the daemon timeout is bounded at 180 seconds.

The historical negative control is the exact `chemsmoke.dm` blob at `3ce4ece2327a9a80bb94a6752138ceb48188ea22`, SHA256 `450eadc7a7090082d1a60fdaf91fe0d9339f930f6a2450b4210afed3446192af`. It runs the same repeated workload and must fail only `automatic systems release hidden holders`. Runtime errors, missing/duplicate completion and unrelated failures invalidate the control. Its raw bytes are protected by a narrow `.gitattributes` rule. The historical workload is cleaned explicitly after its failing measurement.

On Linux, after sourcing the pinned BYOND 516.1681 environment:

```sh
/usr/bin/python3 tests/chemical_smoke_ownership/test_harness.py
/usr/bin/python3 tests/chemical_smoke_ownership/run.py --byond-bin "$PWD/BYOND/byond/bin" --output /tmp/chemical-smoke-fixed
/usr/bin/python3 tests/chemical_smoke_ownership/run.py --byond-bin "$PWD/BYOND/byond/bin" --output /tmp/chemical-smoke-historical --negative-control
```

Use fresh output directories. `--prepare-only` writes generated sources and receipts without launching BYOND. On Windows, use a verified full Python interpreter path and the actual BYOND bin directory. The runner records source hashes, commit/dirty state, complete compiler/runtime logs and accepted mode. CI selects this suite when newly introduced on this PR, or when extensive regressions are explicitly selected. Local native execution is reserved for the parent coordinator's full Gaia queue; pure preparation does not establish runtime success.
