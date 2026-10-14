# World-save regression world

This fixture includes the repository's actual persistence functions, saver and
loader, with isolated substitutes for game startup, chat, deletion, turf change,
and reagent hooks. It never starts a production game or accesses original saves.
It is offline integration evidence, not full playable-world acceptance.

Use BYOND 516.1681. From the repository root on Windows:

```powershell
& ./tests/world_save/run.ps1 -ByondBin 'C:/path/to/byond/bin'
& ./tests/world_save/run.ps1 -ByondBin 'C:/path/to/byond/bin' -Large
```

On Linux, with the BYOND environment loaded:

```sh
bash tests/world_save/run.sh
bash tests/world_save/run.sh large=1
```

The normal fixture is 8x6x2. The large fixture is 500x500x2. Each writes to newly
created temporary storage and retains its runtime log, result and synthetic save
files. Success requires `result.txt` containing `PASS`. CI runs the normal fixture
after compiling the game; large-map verification is an explicit local check.

Replication covers two-level grids, the far boundary turf, nested objects,
instance-specific values, datum references, empty/default lists, associative and
nested lists, duplicates, shared/cyclic lists, references to turfs on another
level, and preservation of the existing metadata object. A second export tests a
completed backup. Corruption cases remove a turf reference, a referenced object,
the completion marker, or change the saved dimensions. The gameticker must reject
the corrupt save without deleting existing objects or retaining its operation lock.
The small fixture also restores a manually constructed unversioned legacy save,
including the old empty-list marker and a null `pixloc` field.

For visual evidence, compile the fixture and copy its `.dmb` and `.rsc` to a new
temporary directory. Start that copy with DreamDaemon/DD using `-invisible -safe
-params visual=1`. Connect Dream Seeker to the local port printed in the log. The
restored fixture and its actual test result remain open for capture. A screenshot
of this fixture does not prove normal game constructors, lighting, registries,
or deletion scheduling work correctly. Test those in a separate local game before
declaring the PR ready.

## Save compatibility and recovery

New saves use format version 2, dimension headers, sharded entry directories,
and typed variable/list envelopes. Area and metadata references resolve to the
existing map instances. Loading still supports complete unversioned legacy saves; it cannot
recover associative list values already discarded by the legacy exporter.
Both formats require matching map ID, complete grids and the completion marker.
Unsupported versions, missing references, or different dimensions are rejected
before clearing. The loader keeps the existing map metadata and lighting overlays.

Object references across z-levels cannot be represented safely in this per-level
entry namespace; the exporter now rejects them explicitly instead of duplicating
objects silently. Turf references across levels are supported. Shared list
identity is preserved within each level's file.

The entire previously completed generation is copied to `map_backups/` before
any active level is overwritten, including its completion marker. An interrupted
export leaves the active generation unmarked. To recover, stop the isolated/test
world, preserve both directories, restore the complete backup generation to
`map_saves/`, and start the matching map before importing. Do not mix files from
different generations. Production recovery/restarts require separate authorization.

Preflight detects structural damage but cannot predict arbitrary constructors or
`after_load()` failures. Such failures return failure rather than success; after
restoration has begun, restart from the original map before retrying. Restoration
is not transactional and cannot roll back arbitrary game hooks.

## Full game probe

`run-game.ps1 -ByondBin 'C:/path/to/byond/bin'` builds a temporary root environment
from the actual `civ13.dme`, appending `full_game_probe.dm`. It copies the binary,
resources and public checkout config/name/crafting assets to a fresh temporary
directory. It copies no live server configuration, credentials, SQL or saves.
Optional webhook and Tor hooks are explicitly disabled. The probe uses real
game startup, constructors, turf replacement and deletion scheduling, exports
the selected map, imports it, and verifies a named crate with a nested knife,
metadata identity and a boundary turf. It also restores a uniquely named tomato
on ploughed soil, its nondefault stage/water/nutrition/radiation and climate/season
lists, soil nutrition, and seven tomato seeds nested in the crate. The live crop
and seed state are deliberately changed after export so retaining the old state
cannot satisfy the assertions. The crop is frozen with its existing `vstatic`
flag to avoid elapsed growth or season timing; this tests persistence, not
post-load growth or an actual season transition. The result is in `full_game_result.txt`;
game exceptions are in `data/logs/runtime/`. The non-visual probe defaults to a
360-second timeout (`-TimeoutSeconds` overrides it), stops only its own launched
daemon on timeout, and retains diagnostics. `-Visual` keeps the world running
after the test for local Dream Seeker inspection and runtime capture.

`inspect.dme` is a standalone read-only entry inspector. Compile it and copy its
binary into isolated save storage, then run with `-params
'file=map_saves/2.sav&ref=20042'`. It logs only the requested entry and never
instantiates saved objects. Do not publish exported entries containing embedded
resources as diagnostic log excerpts.

The isolated human adapter uses production predefines for mob states and mirrors
production's initial stat value. Native disk round trips assert dead humans remain
DEAD without rejuvenation, while unconscious living humans rejuvenate once. The
fixture closes its port at startup and rejects reopening. These checks exercise
the actual saver/loader with an injected rejuvenation adapter, not human gameplay.

`string_path_roundtrip.dme` reuses the offline production saver/loader round trip
with a `text2file` adapter that rejects non-string paths and delegates string
paths to the native disk writer. This models the path contract in OpenDream
engine commit `3a20a7876a52513596edf195a75e08459afd4e9a`. Compile and run it in
temporary storage with the same process bounds and diagnostic checks as the
ordinary fixture. Its negative control restores `file("map_saves/map.txt")` for
`F0` in a generated copy of `saving.dm`; require the metadata-write failure and
absence of a completion marker. The adapter is a compatibility regression,
not proof of an OpenDream save or fresh-process recovery.

`run-string-path.py --byond-bin <516.1681-bin> --expected-saving-sha256
<reviewed-source-hash>` stages the fixture and production includes in temporary
storage and checks clean compilation, runtime diagnostics and the exact result.
Run again with `--negative-control` to restore the resource argument only in
the generated source. The negative requires the exact exception name and no
completion marker. The runner retains original/generated source hashes and
owned process exit records, with 120-second per-process bounds. Use the
coordinated aggregate memory/process guard as well; these per-process timeouts
do not supply an aggregate memory bound.

The fixture also requires the actual `icons/turf/floors.dmi` resource through
its `FILE_DIR`. Frozen source packets must include it; the resource at game
commit `cbf0ebb0a46c7dceb2be8bb02010f49db49cac72` has SHA256
`229e603ee10ce9dd4070a285674c733c3727004e647af2f1e0328e24d683c6de`.
The include inventory does not cover that resource or the final generated
`probe.dme`; retain their hashes and the runner hash in the outer job receipt.
A missing resource is a staging/compilation failure, not the metadata-write
negative control.

### Serialization progress diagnostics

`build-progress-probe.py` generates test-only copies of `saving.dm` and
`functions.dm`, plus `progress-probe.dm`. Supply both original paths and their
reviewed raw SHA256 hashes with `--saving-source`, `--functions-source`,
`--tick-source`, `--expected-saving-sha256`, `--expected-functions-sha256`,
`--expected-tick-sha256` and a new
`--output-dir`. A hash or insertion-anchor mismatch rejects the packet before
creating outputs. The pinned tick source must contain the supported production
tick-check definition. Replace only the saver include in an isolated DME and
append the generated helper; never add the helper to `civ13.dme`.

The helper overwrites `world_save_progress.json` and emits `SAVE_PROGRESS`
console records. It checks each 1024 completed turfs and writes at most once
per ten wall-clock seconds, except forced save/metadata/level/completion boundaries.
The clock uses `world.timeofday` with midnight wrap, for bounded runs shorter
than 24 hours. It is not monotonic; host clock adjustments can affect intervals.
The outer process guard's monotonic timer remains authoritative for timeouts.
Older helpers used `world.realtime`; OpenDream commit `3a20a787` returned only
its 0-9 decisecond component, preventing periodic reports. Those reports cannot
establish elapsed or yield duration, or prove traversal stalled.
Rows include actual map dimensions, the active level's completed turf and
entry/list counts, real elapsed deciseconds, world time, tick usage and
serializer-only `stoplag()` call/wait totals. The scoped tick-check wrapper
uses the same production threshold and calls the original `stoplag()` once.
The original thresholds,
sleeps, traversal, serialization and completion assertions remain intact.
Wait totals include engine flush time while a sleeping proc resumes; they are
not CPU measurements. Diagnostic JSON/deletion/write/log errors are caught:
progress disables itself and records unavailability, without changing the save
result. A save exception resets the active flag and rethrows the original
exception. Latest-state JSON replacement is not atomic; a reader must treat
missing/partial JSON as unavailable diagnostics, never as a failed save.
A level's serialization progress is not durable save
completion, and a completion marker alone is not fresh-process restoration.

Use the runtime owner's existing isolated process guard, finite phase timeout,
source/resource inventory and stopped-process receipts. The generator launches
no compiler or game and supplies no process/memory guard. Keep diagnostic
overhead explicit when comparing performance: baseline and candidate need the
same map, populated contents, engine, storage and instrumentation.

`run-string-path.py --progress` runs the original production round-trip controls
with generated diagnostics. Add `--progress-fault-stage` (`save_entered`,
`level_serialized`, `completion_marker`) and `--progress-fault-operation`
(`delete`, `write`, `json`) to inject a diagnostic exception before that
operation. Each must preserve the successful save and its marker, while reporting
diagnostic unavailability. `--progress-negative-control` deliberately propagates
the injected exception and requires its exact failure and expected marker state.
The native fixture retains its existing mutation-on-tick adapter; these checks
verify IO isolation and save semantics, not full-game timing or CPU performance.

Add `--progress-clock-probe` to verify the ten-second reporting boundary,
midnight wrap and the original stoplag return with a deterministic fixture
clock. `--progress-clock-negative-control` restores the 0-9 component defect
and requires the exact missing-periodic-report failure after a successful save.
Keep these separate from injected IO faults. The fake clock checks arithmetic
and throttling; verify the real engine clock separately before using runtime
duration reports.

### Opt-in Gaia phase profile

The generator's `--phase-profile` adds `phase-profile.dm` and generated wrappers
around the original `BuildVarDirectory` and `encode_saved_value` bodies. Append
both generated helpers to the isolated DME. No production file is edited.
Each wrapper calls the original once, forwards the arguments/return value and
restores its caller's phase on success or exception. Recursive calls change the
active phase rather than accumulating overlapping inclusive durations.
Before a save or after diagnostics disable themselves, wrappers delegate
directly to the original procedures and do not access timing counters. Existing
pre-save transfer/identity checks remain enabled in the measurement smoke.

`phase_wall_ds` partitions active wall-clock intervals into `traversal`,
`object`, `value`, `index`, `yield` and `other`:

- Traversal covers the turf iterator, level selection and skipped levels.
- Object covers entry validation, hooks, content discovery and variable
  selection, excluding nested value encoding and scoped stoplag waits.
- Value covers typed envelopes and list discovery/writes, excluding nested
  object work and scoped stoplag waits.
- Index covers the top-level turf-coordinate reference write and tick check.
- Yield covers the original scoped `stoplag()` wait, including native engine
  work performed before that sleeping proc resumes.
- Other covers metadata, level setup and finalization outside those regions.

The JSON also records cumulative visited/selected turfs, object calls including
reference hits and value calls including recursion. Counts reset per save,
not per level. A complete two-level map visits its entire turf inventory twice.
These are source regions, not six independent CPU or storage phases. Immediate
native savefile encoding belongs to the calling region. Hooks that sleep through
another API remain in that region; only scoped stoplag waits are excluded.
Diagnostic and clock/counter overhead is included. The clock has 0.1-second
resolution, midnight wrap and the existing under-24-hour/nonmonotonic limits.
Short intervals can measure zero; no per-object latency claim is supported.

The engine owner must separately measure dirty-tick whole-tree JSON encoding,
formatting and disk writes with a host monotonic stopwatch, recording flush
counts and bytes. Engine flush measurements can overlap the source `yield`
region, so never add them to the DM partition as additional exclusive time.
CPU needs a separate process/thread CPU metric; elapsed wall time is not CPU.
Compare the small smoke with instrumentation disabled/enabled before interpreting
overhead, then freeze one source-bound Gaia packet and retain original receipts.

`run-string-path.py --progress --phase-profile` exercises unchanged round-trip
controls, positive call counts, exact visited/selected counts and the wall-time
partition. Add `--phase-profile-negative-control` to suppress the value counter;
it must fail that exact assertion after preserving the successful save marker.
Add `--phase-profile-clock-contract` in a separate profile run to test known
exclusive category intervals, actual nested object/value wrapper returns,
original hook exceptions and inactive delegation with a deterministic clock.
`--phase-profile-attribution-negative-control` collapses value time into object
time and must fail the exact category assertion with the save marker preserved.
The fake clock validates accounting, not actual engine elapsed time or overhead.
This is a new measurement-contract smoke, not a rerun to recover inaccessible
original diagnostic cases. Actual OpenDream clock/phase behavior needs the
runtime owner's distinct small smoke before a full Gaia launch. A partial save
still rejects recovery; fresh-process VERIFY requires a complete stopped,
source-bound generation.
