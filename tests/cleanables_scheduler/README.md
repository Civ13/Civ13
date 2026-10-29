# Cleanables scheduler source preparation

Run `-B -m unittest discover -s tests/cleanables_scheduler -v` with a verified
Python interpreter. This suite extracts actual production fire/reset/location
completion/subclass finished and shared finished bodies into an explicit,
restricted translator. It preserves their control flow and rejects unsupported
instructions. Iteration, subtraction, atom identity/location, qdel and tick budgets
are Python adapters. No native compiler, daemon, OpenDream or game is invoked.

The count snapshot and location-count map persist across returns. Before the final
count entry checks its budget, it installs a pending location snapshot; an empty
count result releases aggregation immediately. Shared finished normalization thus
sees nonempty deletion work when cleanup is still owed. Deletion copies one
location's contents and consumes one candidate per budget checkpoint, including
noncleanable/deleted/moved entries. Each checkpoint can perform at most one qdel.
Copy allocation and individual callbacks remain indivisible; no hard wall-time or
whole-server performance bound is claimed.

The original count minus one caps deletion per location. A retained candidate is
deleted only after another live cleanable is found at that same location, leaving
a survivor if earlier counts became stale during a yield. Without interleaved
mutation this preserves original deletion order and quota. With external deletion,
it deliberately avoids blindly consuming the last survivor based on stale counts.
Moved candidates are skipped. Additions after a location-content snapshot wait for
another pass; additions before that copy can be selected only within the original
count-derived quota. All state is released on completion and normal cancellation,
including a paused process that finishes without calling fire.

Fifteen offline cases cover early/final count budgets, final deletion completion,
ordered multi-location cleanup, quota preservation, pending deletion, retained
survivor deletion, movement, population additions, noncleanable checkpoints,
empty/deleted-only populations, destroyed locations and cancellation in both
phases. Actual audited-source, per-fire aggregate-reset and late-phase-transition
controls reproduce their named loss without treating runtime failures as success.
These are source-derived algorithm checks, not proof of native list/GC behavior.

After parent review, prepare an isolated 3x1x1 BYOND 516.1681 fixture using the
established process-loop extraction pattern. Include actual count/removal phases,
subclass/shared finished and production macros; use production qdel/GC with
external effects and normal startup disabled. Verify the list-variable handoff
inside native for iteration, associative location keys, native nulling/deletion,
location-content snapshot iteration, real qdel cleanup, paused cancellation and
state release through scheduler and member entry points. Force budget checks
after each scan/content entry and at each phase's final entry, then compare a
noninterrupted pass and immutable baseline/mutants. Proposed per-case limits are
60 seconds compilation and 20 seconds runtime, with closed/refused ports,
client rejection, zero-listener verification and parent-reviewed containment.
Require zero compiler warnings/errors, zero engine diagnostics, exact assertions
and confirmed process exit. This plan is not an executable native fixture or a
grant to run one. No follow-up branch is published before source review.
