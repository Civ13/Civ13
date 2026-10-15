# World-save regression world

This fixture includes the repository's actual persistence functions, saver and
loader, with isolated substitutes for game startup, chat, deletion, turf change,
and reagent hooks. It never starts a production game or accesses original saves.
It is offline integration evidence, not full playable-world acceptance.

`round_metadata.dm` additionally exercises actual disk metadata restoration of
`persistence`, `research_active`, `resourceresearch` and `perschadplus`, with both
boolean values, legacy nine-field and ten-field records, and malformed extension
rejection before map disposal. New records retain the existing nine fields and
timestamp, then append those four flags as `0` or `1`. Old records leave these
flags at their existing live/map defaults; they cannot recover omitted historical
values. This slice does not restore custom civilizations, faction research,
forge/leader state, saved-body ownership or derived runtime configuration.

`run-round-metadata.py --byond-bin <bin>` runs the same production fixture in
temporary storage. Its `--negative-control restore` and `--negative-control
preflight` options mutate one unique production loader guard in generated source
and require exactly the corresponding failed assertion. Engine errors, unexpected
results, timeouts and unclean child exits reject evidence. CI runs the normal
fixture and both controls and retains attempted-run logs/saves on failure.
No local execution result is claimed for this candidate. BYOND fixture success
would not establish OpenDream behavior, coherent snapshot recovery, the 300-second
crash-loss bound, zero-loss clean stopping or a month of crash-free operation.

`Load_Entry` supplies a location only when constructing atoms. Non-atom datums,
including matrices, are constructed with no arguments before saved fields are
restored. The fixture records constructor argument counts without persisting
that runtime field, checks an actual saved-entry datum construction, and restores
all six non-default coefficients of both a standalone matrix and an item
transform. Existing atom placement, nested contents, typed lists and legacy
flat-entry loading remain part of the ordinary fixture.

The native composite `appearance` is excluded from both export and import:
its unsupported saved envelope restores null and resets independently restored
visual fields. Transform, color and alpha retain their normal field encodings.
The source transform is checked before export; restoration checks all six
coefficients plus color and alpha, and logs expected/actual coefficients on failure.
`run-string-path.py --appearance-negative-control` removes only this exclusion
in generated source and requires the original transform-coefficient failure
after a completed save. It cannot be combined with other controls.

The bounded `run-string-path.py --datum-constructor-negative-control` mode
restores the old location-for-every-type branch only in its generated loader.
It requires the exact `datum constructor received location argument` failure
before world export and rejects a completion marker. Keep this control separate
from metadata and diagnostic controls. The same runner without the flag must
pass the full ordinary fixture. Native tests require the current runtime owner's
exclusive execution window; source generation does not establish a runtime pass.

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

## Restore wrapper contract

`restore_wrapper.dm` invokes the actual `gameticker.loadmap()` with injected
storage and policy effects. Both normal and large round-trip runs include it.
Metadata must return exactly TRUE; FALSE, other truthy values and exceptions
fail restoration. The existing successful null-policy legacy/v2 path still runs
against the actual saver/loader after the wrapper cases.

The optional runtime `map_storage.restore_policy` must return an attempt bound to
the selected storage and policy. Its recovery reservation must return exactly
TRUE before ClearMap, with the binding rechecked after reservation. The default
policy has no provider and rejects before clearing. Once mutation begins, the
failure callback must return a typed, bound receipt confirming retained recovery.
Transient release runs at most once; cleanup errors remain separate from the
primary failure in `restore_cleanup_error`. Provider acquisition cleanup before
a bound attempt is returned remains the provider's responsibility. These runtime
handles are excluded from custom persistence, including inherited exclusions.

The fixture checks callback order, preflight/binding rejection, conservative
mutation-started status, clearing/world/metadata exceptions, metadata and world
FALSE returns, cleanup exceptions, invalid recovery receipts, single release,
and the busy gate. It proves wrapper invocation and receipt validation only.
There is no production provider, durable reservation, immutable reader, rollback
or complete restore admission proof. Transient release never authorizes recovery
release or publication. A failed restore still needs the recovery procedure above.

`run-wrapper.py` generates a temporary environment and changed source copy for
each omission control. It requires BYOND 516.1681, a clean compile, no engine
diagnostics and the intended failing fixture assertion. Production source stays
unchanged. CI's existing selected world-save step runs both controls:

```sh
python3 tests/world_save/run-wrapper.py --byond-bin /path/to/byond/bin
python3 tests/world_save/run-wrapper.py --byond-bin /path/to/byond/bin --roundtrip
python3 tests/world_save/run-wrapper.py --byond-bin /path/to/byond/bin --negative-control metadata
python3 tests/world_save/run-wrapper.py --byond-bin /path/to/byond/bin --negative-control recovery
```

On Windows use a verified full Python interpreter path with the same arguments.
The compiler and daemon each have a 120-second subprocess timeout. `--roundtrip`
includes the ordinary legacy/v2 disk checks after wrapper checks, within the same
daemon timeout; it cannot be combined with an omission control. The ordinary-map
fixture supplies fail-closed surface-service type adapters for compilation and
throws if that unrelated service is activated. Extraction probes cover real
surface-service behavior separately.
All daemon storage and generated outputs remain in a unique temporary directory;
the fixture closes its port and has no production startup or outbound adapters.
Source addition is not test execution; record actual exact-head results separately.

## Reader primitive experiment

`reader_contract.dm` is a standalone two-world savefile API experiment.
`run-reader-contract.py` uses pinned BYOND 516.1681, a unique temporary directory,
60-second compiler timeout and 45-second shared runtime deadline with bounded
owned-process cleanup. Positive and binding/close omission controls passed on
Windows BYOND 516.1681 at `12de059fad3d593bc2a4891a6867d7d5a0c7e8f4` with
zero compile errors/warnings. It never loads the production game or provides
host immutability; the retained same-world reader observed a second handle's write.

```sh
python3 tests/world_save/run-reader-contract.py --byond-bin /path/to/byond/bin
python3 tests/world_save/run-reader-contract.py --byond-bin /path/to/byond/bin --negative-control binding
python3 tests/world_save/run-reader-contract.py --byond-bin /path/to/byond/bin --negative-control close
```

On Windows use a verified full Python interpreter path. See
[the reader-contract probe](../../docs/extraction-reader-contract-probe.md) for
the exact native stages, receipt gates, fixture adapter limits, omission assertions
and unsupported outcomes. Same-world writes, other cooperating BYOND worlds and
arbitrary host writers are separate boundaries. OpenDream is not tested here.

## Windows read-only native-open candidate

`readonly_open.dm` and `run-readonly-open.py` are source-only and uncompiled/unrun.
They seed one synthetic savefile in a unique temporary directory, close the seed
world, set its Windows read-only attribute, and require a Python write attempt to
be refused before pinned BYOND 516.1681 opens and reads the original A value.
This tests compatibility with that attribute only; it creates no OS identities or
ACLs and cannot establish host ownership or immutable bytes.

The `writable` control omits sealing and must hit WRITABLE_BACKING_REJECTED before
a consumer starts. The `value` control changes one generated consumer expectation
and must produce paired UNSUPPORTED: READ_VALUE_MATCH with clean exit and the
actual seeded value `A` in the consumer receipt. Positive reads also require `A`. Seed
failures, engine diagnostics, cancellation, missing/mismatched results and cleanup
errors reject acceptance. Every compiler/daemon is recorded with PID, runner
parent, command, launch-request timestamp, exit and cleanup status. A timestamp is
not independently observed OS process-start attestation.

Compiler timeout is 60 seconds; seed and consumer each have 15 seconds, with
four-second terminate and two-second kill waits per owned process. There is at
most one process at a time. Logs/receipts are capped at 1 MiB when read; the
synthetic seed has a 1 MiB post-creation size guard. No OS memory or pre-write
storage bound is established. Preserve files/logs for review and run only in a
fresh bounded slot. Unsupported native read-only opens require consumer redesign,
not relaxed permissions or mutable-path fallback.

```powershell
& '<verified-Python-path>' tests/world_save/run-readonly-open.py --byond-bin '<516.1681-bin>'
& '<verified-Python-path>' tests/world_save/run-readonly-open.py --byond-bin '<516.1681-bin>' --negative-control writable
& '<verified-Python-path>' tests/world_save/run-readonly-open.py --byond-bin '<516.1681-bin>' --negative-control value
```

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

HUD migration coverage in `run-string-path.py` checks that client HUD fields and
screen/HUD objects do not enter new saves, old saved HUD fields are skipped and
old HUD entries are suppressed before their owner-dependent constructors run.
The human's dead status, name and nested paid item survive the native round trip.
`--hud-negative-control export`, `import` and `constructor` independently remove
each safeguard in generated source and require its exact failure. The constructor
sentinel models the owner requirement; full-game same-generation restoration is
separate acceptance. Use D: TEMP/TMP and the sole live-test owner's executor.
