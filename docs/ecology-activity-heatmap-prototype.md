# Inactive activity heatmap datum

Status: source candidate only. No process, singleton, player hook, spawn/delete
path, live telemetry, startup action or server configuration is added. Including
the declaration in civ13.dme makes it available for future compilation; it does
not construct an instance. No compile or native execution has been performed.

## API and ownership

`/datum/ecology_activity_heatmap` owns only anonymous cell-score pairs. Its caller
must explicitly instantiate it and supply a monotonic elapsed-seconds clock. The
constructor validates max_cells (integer 1..4096), interval (1..3600 seconds),
half_life (1..86400 seconds) and increment (0.0001..1). Invalid configuration leaves
the instance unconfigured; all admission/query operations fail closed. DM TRUE
is numeric 1, so DM cannot copy Python's distinction between boolean and integer
policy values. Bounded positive comparisons follow Civ13 durable numeric checks;
native NaN/infinity comparison behavior still requires an actual engine test.

`sample(now, occupied_cells, complete = FALSE, expected_epoch = null)` takes at most 256 rows of exactly
three bounded positive integer coordinates `(physical_z, cell_x, cell_y)`. It
validates the complete snapshot and stages unique keys before touching any score.
Rows are anonymous already-filtered active physical occupancy; no client or mob
references, names, ckeys or histories enter the datum. Caller is responsible for
physical-z/map validity, deliberate activity classification, exclusion of AFK and
observer pressure, and truthful complete coverage. Associative/alist input is not
a supported interchange format. The normal list macro excludes alist in Civ13.

Duplicate cells contribute once per sample bucket, regardless of crowd size.
An incomplete/oversized/malformed snapshot or capacity overflow invalidates the
whole heatmap, including a repeated bucket's incomplete report. A later complete
sample cannot clear a missing-history hold. Query `pressure(now, row, expected_epoch = null)` returns
null for UNKNOWN and zero for a known unobserved cell. Callers must distinguish
null from zero explicitly; neither result is a visibility permission.

Each touched score decays by `0.5 ** (elapsed / half_life)` then receives one
increment clamped to one. Query calculates decay without growing the registry.
There is no world scan, timer, RNG, automatic pruning or full-registry update.
Snapshot work is bounded at 256 rows plus at most 256 staged updates; stored cell
count is at most 4096. A 257-row complete input is rejected even if rows duplicate;
the upstream adapter must aggregate within its own bounded work policy rather
than truncate. The model's max 256 input rows is an explicit conservative limit,
not a measured production capacity.

`reset_epoch(now)` clears data and validity hold with a new epoch, provided the
clock and configuration are valid. Epoch is capped at one million; elapsed time
at one billion seconds. At exhaustion replace the runtime-only datum under a
future owner policy, do not wrap counters. BYOND numeric precision near clock
limits has not been tested: use a suitably short elapsed-clock lifetime and
validate bucket/decay boundaries natively before integration. No offline elapsed
time or wall-clock input is inferred. Reset does not implement the design's
warm-up requirement; a future integration must hold recruitment separately.

The datum is `should_save = FALSE`; all ten custom fields explicitly opt out of
custom persistence (tmp alone is insufficient). Destroy drops the local lists
and calls the parent. No custom save payload or restore hook is provided. This
is not a tested disk-save round trip; a future owner must not embed copies of
these fields in its own payload.

## Validation and release boundaries

From the repository root, after applying the candidate:

    python -B -m unittest discover -s tests/ecology_heatmap -v

Twelve source-contract tests include twelve deliberate source mutations. These
check inclusion, field exclusions, hard guards and inert declaration shape;
they are not a parser, interpreter, DM compile or behavioral proof. Separate
Python reference-model behavior is background design evidence only, not this
DM source executing. No claim is made that floating point, native list behavior,
partial mutation safety, clock edge cases or native persistence work correctly.

The candidate adds the file to civ13.dme so a future authorized hosted build of
that exact patched revision would actually compile it. An unreferenced-file
build must never be reported as candidate compile evidence. This preparation
runs no DreamMaker, DreamDaemon, native fixture or connected client. A future
compile success still would not prove gameplay or visibility. No feature is
activated by applying this patch or by compiling it.

Before wiring: review source; compile the included exact revision on pinned
516.1688; separately authorize and exercise actual proc tests for invalid numeric
values, boundary clocks, duplicate and associative lists, all-or-nothing staging,
overflow, reset and persistence; then review the upstream bounded activity and
visibility adapters. The broader ecology system remains default off.

## Epoch-bound payloads

Every sample and pressure query must supply the epoch captured when its payload
or query geometry was prepared. The default null refuses; do not substitute the
current epoch at dispatch for an old queued payload. Both procedures reject a
missing/mismatched epoch before accept_time, coverage changes or score writes.
An old-map call therefore cannot advance or rewind the new map clock, poison
fresh validity, or heat coordinates belonging to unrelated geometry. Reset is
an explicit synchronous owner operation; no production callbacks are wired.
The caller must cancel/rebuild old work and distribute the new epoch after reset.

Source checks establish only guard text/order. Native DM tests must demonstrate
stale input leaves clock, validity, cells and bucket unchanged. In particular,
the two `var/key` declarations in separate loops still require actual included
DM compilation to establish scope legality; Python checks do not prove this.

## Bounded CI registration

scripts/ci_baseline.py explicitly registers only
`tests/ecology_heatmap/test_source_contract.py` as ecology_heatmap. Reviewed
imports are pathlib, ast, re and unittest; no subprocess, engine, network or
external tool is called by the registered test file. Work reads the candidate,
DME, registry and test source, with bounded fixed mutation cases. Existing
30-second per-suite/6-minute job bounds remain unchanged. No workflow admission,
permissions or native selection is changed. Shared DME changes retain the
existing conservative all-suite fallback; they are not narrowed to this suite.
The tests assert exact file registration and safe imports. Offline checks ran
the actual registry impact function and unit entry point with 12 passing tests;
this is not a hosted-CI result or exact committed-head aggregate receipt.
