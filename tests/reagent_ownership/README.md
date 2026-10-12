# Reagent holder ownership

Run `run.py --byond-bin <516.1681-bin>` using a verified Python interpreter.
The isolated fixture compiles the production holder Destroy and delete procedures and checks
owned reagent disposal, chemistry registry removal, release of the atom backlink
and preservation of a replacement holder association. Adapters replace startup,
qdel and unrelated parent cleanup. `--baseline` must fail backlink release.
These tests establish cleanup semantics, not live chemistry or full-world memory.

The baseline source is pinned to commit f556e39b93fc97f41020b2d8c5f2abed63fab497.
With --baseline, exit success means the exact expected ownership failures were
detected without compiler warnings or runtime errors; the old production code
is still defective. Optional --evidence-dir <directory> retains compile/runtime
logs, tested production/fixture sources and JSON provenance with source hashes,
HEAD, dirty-tree status and expected/observed control failures. Dirty checkout
results are source-hashed evidence rather than an exact clean-commit claim.
