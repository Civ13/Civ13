# Dynamic callback ownership

Run `run.py --byond-bin <516.1681-bin>` using a verified Python interpreter.
Compiles the complete production callback source in a closed-port isolated world.
Checks invocation-local targets, missing-target calls, stored argument stability,
ordinary reusable callbacks and overlapping sleeping asynchronous invocations.
`--baseline` checks the committed pre-fix source and must fail the target-release
assertion. This establishes callback semantics, not whole-game memory bounds.

The baseline source is pinned to commit f556e39b93fc97f41020b2d8c5f2abed63fab497.
With --baseline, exit success means the exact expected ownership failures were
detected without compiler warnings or runtime errors; the old production code
is still defective. Optional --evidence-dir <directory> retains compile/runtime
logs, tested production/fixture sources and JSON provenance with source hashes,
HEAD, dirty-tree status and expected/observed control failures. Dirty checkout
results are source-hashed evidence rather than an exact clean-commit claim.
