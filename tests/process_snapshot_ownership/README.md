# Process snapshot ownership

Run `run.py --byond-bin <516.1681-bin>` with a verified Python interpreter.

The native fixture extracts production `finished`, `process`, `fire_as_member`,
`relayProcess`, scheduler startup/deferred queue procedures, the mob process's
actual registry-copy reset, and the scheduler macros. Fire and bookkeeping hooks
are isolated adapters. The actual reset has only an added observation counter;
it uses production `PROCESS_USE_FASTEST_LIST` and `living_mob_list` unchanged.

Checks cover hook access before cleanup, completion accounting, copied/aliased
snapshot release without modifying source membership, and budgeted continuation.
Three members execute exactly once across three scheduler passes. Early returns
retain remaining entries without rebuilding their snapshot. Successful completion
leaves no snapshot and removes the process from the relay queue.

Fresh scheduler/member runs build the real registry snapshot immediately before
work. A subsequent fresh relay sees replacement registry membership. Startup
creates no idle snapshots; deferred processes retain unfinished entries without
resetting. These fixed-only fresh/deferred cases do not pretend that the historical
baseline supported the new lazy behavior.

`--negative-control` deliberately removes the completion-result guard in a generated
copy. Successful control execution requires exactly the scheduler/member early
continuation failures. `--reset-control` deliberately restores post-completion
reset and requires exactly the copied-snapshot release failure. Neither control
accepts compiler warnings, runtime errors, unexpected assertions or a pass marker.

`--baseline` pins all extracted process/scheduler/reset/define sources to commit
`f556e39b93fc97f41020b2d8c5f2abed63fab497`. The unmodified historical callers use a
real initial registry reset, matching their startup contract. Successful control
execution requires only the historical copied/aliased release failures; early
continuation remains correct. Control success means the known defect was detected.

Optional `--evidence-dir <directory>` retains compile/runtime logs, full sources,
extracted production/fixture sources, hashes, HEAD, checkout dirtiness and exact
expected/observed failures. Dirty checkout results are source-hashed observations,
not clean exact-commit evidence. All four modes compile on native BYOND 516.1681
with zero warnings/errors and no engine diagnostics.

This fixture isolates ownership and continuation contracts. It does not launch
Civ13 or establish full-game scheduling performance or user acceptance.
