# Weak reference ownership

Run `run.py --byond-bin <516.1681-bin>` with a verified Python interpreter.
The fixture compiles the complete production weakref source and checks cached
identity, nonforced deletion veto, forced detachment without target destruction,
replacement handles, queued targets and native target deletion. The qdel adapter
records attempted deletion; startup and external services are not included.
`--baseline` compiles the committed pre-fix source and must fail the target
preservation assertion. Temporary files and the closed-port daemon are isolated.
These checks establish handle semantics, not full-world memory or gameplay.

The baseline source is pinned to commit f556e39b93fc97f41020b2d8c5f2abed63fab497.
With --baseline, exit success means the exact expected ownership failures were
detected without compiler warnings or runtime errors; the old production code
is still defective. Optional --evidence-dir <directory> retains compile/runtime
logs, tested production/fixture sources and JSON provenance with source hashes,
HEAD, dirty-tree status and expected/observed control failures. Dirty checkout
results are source-hashed evidence rather than an exact clean-commit claim.
