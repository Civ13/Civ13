# World-save regression world

## Ordinary roundtrip compatibility

`roundtrip.dme` includes `roundtrip_compat.dm` for the current loader's area
registry, roof base type and generated-snow declarations. It leaves shared
`stubs.dm` byte-identical because immutable character-return preparation pins
that file. The registry adapts the ordinary production membership operations
to this fixture's immediate `del()` lifecycle, including empty explicit areas.
The snow scalar/overlay defaults and icon projection match production; this
fixture has no weather worker and only exercises the loader's clear-ground
reset on `/turf/test`. It does not establish generated-snow gameplay coverage.
No roof objects or climate subtypes are introduced. Shared topology refusals,
the production loader, positive roundtrip assertions and omission controls remain
unchanged. The null-topology subtype below is selected only by roundtrip.dme.

```sh
python3 -B tests/world_save/test_roundtrip_compat.py -v
```

These offline tests execute only the existing runner's source-generation block
for the positive case and all three controls, with process entrypoints poisoned.
They check include closure, source parity, adapter scope and the unchanged shared
input pin; they neither compile nor run DM. The historical declaration-only
packet left `run-round-metadata.py` unchanged; its default still requires BYOND
**516.1681**. Master's opt-in `--byond-archive` profile (`current_runtime.py`) does not
retroactively change those receipts. Neither admits native execution or proves a
fixture pass; authorized isolated validation is still required.

### Null-topology import boundary

At published commit `2830578f131c3237b997dc2c6b26a28aa569db4b`, hosted CI run
`40683465662` compiled the fixture cleanly on 516.1688, then failed the unchanged
`legacy fixture import failed` assertion. The import wrapper unconditionally
calls `begin_zone_restore`, while the shared fixture stub always throws
`Topology needs the full-source fixture`. Production returns immediately when
validated zone state is absent; the later topology-restoration call is guarded.

The roundtrip-only `/map_storage/roundtrip_fixture` subtype admits **null state
only**, before accessing the operation, then delegates every present state to
the unchanged parent refusal. This is stricter than admitting false-like values
or empty lists and does not implement topology. Before the first assertion, the
fixture replaces its unused initial storage with that subtype, preserving its
game ID. A bounded probe requires null success and rejection of empty, schema-1
and schema-2 lists with the original exception. The positive legacy import and
all three exact metadata controls remain required.

`ROUNDTRIP_NO_TOPOLOGY_COMPAT` is defined only in `roundtrip.dme`; its two guarded
blocks select the subtype and define the probe. `string_path_roundtrip.dme`
shares `roundtrip.dm` without selecting these blocks. The floor-decal generator
omits `roundtrip.dm`, so it does not acquire setup or a new assertion dependency.
No shared stub, production source, engine rule, selector or saved-character pin
is changed. Offline tests check the source boundary, four deliberate guard/
delegation mutations, include isolation and positive/control source generation.
They do not execute the new probe or establish that the native import now passes.
The observed hosted failure remains the current result until new validation;
the saved-character/bed fixture remains preparation-only.

## Protected sleep transfers

Protected sleep sends a body to a different z-level while preserving scalar
return coordinates. A reciprocal `mob.buckled` / `bed.buckled_mob` relationship
must be released through the normal unbuckle method before that transfer. The
same release on wake supports a still-protected body left with the old distant
bed link. A mismatched occupant or refused unbuckle rejects the transfer; it does
not clear arbitrary pointers. A failed wake retains sleep protection for retry.

The focused sleep fixture extracts the actual entry/wake helpers, production
buckling methods and base forced movement, with narrow physiology/inventory and
startup adapters. It checks normal and old-state transfers, other-occupant
protection, refusal and persistence-busy paths, and a real format-3 save,
preflight and import with metadata aliases. Delayed verb/client ownership is
covered by source contracts; this headless fixture does not establish real
connected-client timing or full gameplay acceptance. Preparation alone does not
establish a native pass.

The serializer still fails closed on unsupported cross-z object fields and on
duplicate durable bindings. Diagnostics report only bounded source field/type,
save-entry identifiers and z-levels, never player names, client keys or live
native references in log messages. This draft uses bounded format-3 captures
and preserves the first completed spatial capture across later movement; it is
not an atomic world snapshot. Current readers retain format-2 compatibility.

For a rejected object reference, inspect the single admin VV field
`map_storage.last_save_reference_failure`: Game Panel, **View/Debug a Global
Variable, List, or Object**, enter `map_storage`, then open that field (requires
the existing debug permission). It snapshots source/target types,
process-local lookup references, native and turf coordinates, the saved level,
entry IDs and up to eight owning field frames. The duplicate-binding case also
records its first level/entry. It contains no field values, player names, client
keys or live object references. Cleanup preserves the snapshot; an accepted new
save clears it, while a rejected busy request does not. Capture time identifies
when it was recorded. A lookup reference can be recycled after deletion, so
verify the current type and location before acting. This diagnostic does not
authorize clearing a relationship or prove which relationship should be durable.

```sh
python3 -B tests/world_save/test_sleep_transfer_sources.py -v
python3 tests/world_save/run-sleep-transfer.py --prepare-only
# Only in an approved isolated native execution window:
python3 tests/world_save/run-sleep-transfer.py --run-native --byond-bin /path/to/byond/bin
for control in old-bed persistence-gate other-occupant wake-actor move-rollback inventory-gate diagnostic-record; do
  python3 tests/world_save/run-sleep-transfer.py --run-native --byond-bin /path/to/byond/bin --negative-control "$control"
done
```

Each control mutates only generated fixture source and must produce its exact
intended assertion. The old-bed control requires the real serializer's cross-z
bed rejection. Compiler errors, unexpected assertions, runtimes, unfinished
results, and timeouts are failures, not evidence that a control worked. CI has a
focused `protected_sleep_regressions` dispatch option and retains receipts,
source hashes, logs and temporary saves for every attempted run.

`run-cross-level.py` is an optional diagnostic scaffold for the broader snapshot
problem. Its `--expect-current-defects` mode characterizes existing traversal
defects; without that flag it requires ordinary `PASS` results. Mutation controls
retain their own exact expected failures. CI checks the ordinary `field-direct`
and `move-direct` cases with format-3 restoration, unique placement and durable
alias checks. The `first-capture` mutation reproduces the exact old duplicate
binding rejection. Broader cases outside this focused CI gate retain historical
characterization expectations and are not claimed as an all-cases passing suite.

`run-dimension-bootstrap.py --byond-bin <bin>` writes a temporary three-level
generation, then launches fresh two-level readers. It runs the production saver,
preflight, loader and shared building allocator. The runner stages the allocator
and sky definition verbatim from `building_levels.dm`; its later construction,
support and `Entered` gameplay methods are covered separately by
`tests/building_levels`. The tiny fixture checks upper-level typed references,
paid nested contents, unchanged mapped turfs, matching two-level saves, invalid
dimensions, missing levels, corrupt grids/generations/references and a mismatched
restart intent. Malformed saves must fail before the first allocation. Allocation
failure and a post-allocation exact-header mismatch must latch recovery, reject
retry and preserve the completed generation against saving. The `preflight`
negative control bypasses the prospective validation and must detect an unwanted
allocation for a missing level. `--prepare-only` stages source without running
BYOND and is not runtime evidence.

Expansion requires unchanged x/y, at most 32 total levels, at most eight levels
beyond the compiled baseline, and at most two million cells per added level.
All saved grids, entries, references and durable metadata are validated against
the prospective bounded dimensions before the shared allocator runs. Normal exact
dimension validation runs again afterward. Existing mapped levels are never
resized. A partial allocation requires restarting from the original compiled map;
the loader does not shrink or roll back a live world. This focused fixture uses
round-v1 metadata. `run-durable-world.py --dimension-bootstrap --profile gaia`
(and `--profile europe`) uses complete production sources with normal startup
disabled, then launches a writer and fresh reader of the same compiled two-level
DMB. It checks round-v2 metadata roots pointing to a third-level turf and player
entry, rejects out-of-bounds prospective graph roots before allocation, and
restores metadata aliases and environment state after shared allocation. These
are tiny offline fixtures; actual admin save/restart/same-body recovery remains
separate acceptance work.

This fixture includes the repository's actual persistence functions, saver and
loader, with isolated substitutes for game startup, chat, deletion, turf change,
and reagent hooks. It never starts a production game or accesses original saves.
It is offline integration evidence, not full playable-world acceptance.

`round_metadata.dm` additionally exercises actual disk metadata restoration of
`persistence`, `research_active`, `resourceresearch` and `perschadplus`, with both
boolean values, legacy nine-field and ten-field records, and malformed extension
rejection before map disposal. Legacy cases select the legacy completion format;
parser cases retain a matching modern digest. A separate modern digest-tamper
case verifies rejection before either preflight or the load wrapper mutates live
state. New records retain the existing nine fields and
timestamp, then append those four flags as `0` or `1`. Old records leave these
flags at their existing live/map defaults; they cannot recover omitted historical
values. This slice does not restore custom civilizations, faction research,
forge/leader state, saved-body ownership or derived runtime configuration.

`run-round-metadata.py --byond-bin <bin>` runs the same production fixture in
temporary storage. Its `--negative-control restore` and `--negative-control
preflight` options mutate one unique production loader guard in generated source
and require exactly the corresponding failed assertion. Engine errors, unexpected
results, timeouts and unclean child exits reject evidence. Its `--negative-control
integrity` removes only the production metadata digest comparison and must fail
the independent modern tamper assertion. CI runs the normal fixture and all three
controls and retains attempted-run logs/saves on failure. BYOND fixture success
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
temporary directory. Start that copy with DreamDaemon/DD using `-invisible -trusted
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

`-PlayerIdentity` selects `maps/nomads/nomads_gaia.dmm` only in the generated
environment. It requires Gaia's real human constructors and checks restored
identity after delayed customization; `-IdentityNegativeControl` removes the
restoration guard only in a generated source copy. Launch input hashes are
retained in `launch-inputs.json`. Non-visual runs retain stdout, stderr and
`daemon-exit.json` with the numeric exit code, elapsed time and timeout status,
including early exits before the DM probe can write a result. An early native
exit is failed execution, never a successful negative control.

`prepare-startup-trace.py` accepts a staged source root, explicit entrypoint,
new output directory and a JSON SHA-256 mapping for the entrypoint, `code/world.dm`,
base map metadata and Nomads metadata sources. It writes three instrumented
copies and a new `.startup-construction-trace.dme` directly in the staged root,
preserving the entrypoint's relative resources, map and local adapter includes.
It never compiles or launches. Existing output files and mismatched inputs are
rejected. The receipt records generated paths/hashes; run only through the
exclusive runtime owner. Markers append to `startup-construction-trace.log` in
the engine's runtime directory. Preserve previous marker logs before a new run.

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

### Clients waiting through restart recovery

`run-durable-world.py --recovery-reconnect --profile gaia` (or `europe`)
uses production disk save/load, generation validation, restart intent consumption
and player reclaim in temporary storage. Client enumeration, admission responses
and key transfer use explicit fixture adapters; no real account, HUD or native
reboot is exercised. The probe checks clients waiting before and arriving during
import, a failed intent-consumption boundary and safe retry without reimport,
exactly one transfer after release, preserved body health/inventory/metadata alias,
ban/guest restrictions, disconnected sessions and retained rejected claims.
`--negative-control reclaim-order` moves the readiness sweep back before intent
consumption, reproducing the stale lobby failure. It must fail specifically at
the waiting authenticated client's missing reclaim assertion.

Ordinary map loads finish player restoration after load. Restart transactions
finish it after the matching intent is consumed and the startup/save hold is
released. A client already in the lobby therefore receives the same normal
reclaim/Login path as one connecting after recovery completes.

### Serialization progress diagnostics

Saved account/body ownership and its isolated negative controls are documented
in `docs/saved-player-reclaim.md`. Offline lookup tests do not establish real
client transfer, HUD rendering or control after restart.

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

Current-source reconciliation (2026-10-16): the five offline tests pass on the
combined checkout; the four source-binding tests also pass with the persistence
sources from master `ed520998f8c8`. The fifth checks the actual result dispatcher:
expected phase-control failures are accepted without falling through into the
positive-result check, while unrelated failures remain rejected.
`run-string-path.py --prepare-only --progress --phase-profile
--phase-profile-clock-contract` prepares the combined fixture successfully.
These checks generate source only; they do not compile or run BYOND.

The current full-map Europe observation at gameplay `e6be0cc25` recorded
130.3 seconds inside the instrumented serializer and at least 148.281 seconds
after its completion observation while a pre-reboot receipt was still absent.
The latter interval includes validation, identity and receipt work; it is not
an isolated measurement of validator CPU. The workloads differ from the older
Gaia samples, so these numbers establish no speedup or regression comparison.
This profiler ends at the serializer marker and cannot attribute that interval.
Before a performance change, extend the generated-copy measurement boundary
to the transaction's repeated `current_identity()` calls, full
`validate_world_save()` calls, intent publication and return from native save
closure. Keep nested calls exclusive and preserve failure results and original
call counts. Retain raw save hashes and recursive path-restoration controls;
removing repeated `savefile.cd` restoration can corrupt recursive serialization.
Native timing, representative overhead and fresh-process recovery of that
extended measurement remain unrun.

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
# Full Gaia profiling packet (source only)

`build-gaia-full-packet.py` freezes the original full Gaia compile-save-path
source closure, retaining all original files and their inventory. It adds the
existing serialization phase wrappers, the reviewed host-callable SAVE wrapper,
and narrowly adapted non-atom constructor and composite appearance exclusions.
The actual Gaia map remains included. Its probe also checks all six recovered
crate transform coefficients, color and alpha, alongside the original nested
paid-state and authenticated SAVE/fresh VERIFY checks.

Use explicit `--source-root`, `--wrapper-dir` and a new `--output-dir`. The input
source must match the pinned legacy saver/functions/loader/tick/probe/DME.
Then run `audit-gaia-full-packet.py --packet <output> --original-manifest
<compile-inputs-save-path.json> --receipt <new-receipt.json>` to authenticate the
complete original inventory, every generated byte, the map and dispatcher probe
hash. This audit never launches a compiler or runtime.

This legacy full-map packet does not inherit current atomic fixture acceptance.
The frozen DME includes `tests/world_save/setup_instrumented.dm`, which already
sets `new_process_dispatch_init_complete` after the original final setup yield.
Authenticate that actual included file, not the unused `code/setup.dm`. The
marker observes the foreground setup tail; spawned background work and final
savefile flushes remain separate acceptance conditions.
The runtime owner must bind a compatible compiler, engine, host and resources,
await actual DreamThread completion through original yields, preserve natural
savefile close/dirty flush behavior, and verify the stopped generation before a
distinct fresh VERIFY. Logical wrapper return is not disk-flush completion.
Null-filter profiling includes all resources in the window; cap exclusions and
instrumentation overhead limit cost claims. No production profiler DM API is
introduced. Native execution remains exclusive to the runtime owner.

HUD migration coverage in `run-string-path.py` checks that client HUD fields and
screen/HUD objects do not enter new saves, old saved HUD fields are skipped and
old HUD entries are suppressed before their owner-dependent constructors run.
The human's dead status, name and nested paid item survive the native round trip.
`--hud-negative-control export`, `import` and `constructor` independently remove
each safeguard in generated source and require its exact failure. The constructor
sentinel models the owner requirement; full-game same-generation restoration is
separate acceptance. Use temporary storage and the sole live-test owner's executor.

# Round identity and phase recovery

The durable metadata graph also has native associative coverage:
`run-durable-graph.py --alist --byond-bin <516.1681-bin>`. Controls
`alist-values`, `alist-kind`, `alist-alias` and `alist-binding` verify numeric
associations, collection type, cycles and normal saved-entry ownership. These
use actual map squad defaults. `run-durable-world.py` checks strict root kinds,
invalid association edges before mutation, and a human identity shared between
the normal spatial import and squad/research metadata. Its human constructor
bypasses physiology startup, so full-game acceptance remains separate.

New generations store a `round.json` header bound to their completion marker,
map metadata digest, dimensions and a nonce in every level. Preflight rejects
missing, malformed or mismatched new headers before clearing the world. Backups
include the header. The header preserves game ID, ticker phase, active-server
elapsed ticks and round-start realtime. Restoration rebases the elapsed clock
onto the new process, excludes offline downtime, invalidates display caches and
synchronizes ticker playtime. Resumed rounds skip fresh character creation,
equipment, map seeding and round-start hooks. The time-of-day loop is idempotent.

Run `run-string-path.py --round-state` with the existing pinned BYOND and saving
hash arguments. Controls `--round-state-negative-control setup`, `clock`,
`generation`, `busy`, `tod`, `music-body`, `music-round`, `music-lobby` and `jobs`
must fail at the named regression assertion, with clean native
compilation and no unexpected diagnostics. `--prepare-only` generates sources
and input hashes without compiling or launching; it is source preparation only.
The probe imports the header from disk, checks process-clock rebasing, malformed
and partial header rejection, level-generation mismatch, setup side-effect
counters and legacy ownership decisions. It also extracts the actual pregame
orchestration with a one-second fixture countdown and delayed import completion,
round-duration formatters, TOD-loop ownership and lobby audio decisions. A
bounded visit counter prevents the deliberately unsafe busy control from hanging
the engine. Sound transport is injected: normal/restored living Login and active
round transition stop only channel 1, while a pregame lobby still plays and an
active round cannot replay it. These adapters do not prove a fresh
full-game process restart or connected-player acceptance.

The round-state fixture extracts production occupation construction, capacity
initialization, lookup, fresh-join availability and role assignment procedures,
using the production Nomad title and capacity defaults. Current disk imports
and owned legacy restores must admit a fresh Nomad; unowned legacy and pregame
restores must not initialize active capacity. Existing occupancy and round/world
state remain intact, disabled/missing/full jobs remain unavailable, and capacity
initialization is idempotent. The `jobs` control omits both restore initialization
calls in generated source and must fail `restored Nomad fresh-join gate unavailable`.
The probe checks the real availability/assignment gates with offline actors;
it does not create authenticated BYOND accounts or prove connected fresh joining.

Legacy timestamp markers retain compatibility. A successfully loaded legacy
world with a unique living durable-owned restored human resumes the active
phase without fresh setup. Its historical game ID and duration are unavailable;
the current session establishes continuity for subsequent new saves. Unowned
legacy worlds retain historical behavior. This header does not yet restore
map-specific faction/civilization controllers, day/night phase, station calendar,
vote state or every map timer. Startup messages/webhooks emitted before loading
are not retroactively rewritten. No faster world-save claim follows from this
correctness change.

# Native save/restart transaction

`run-restart-transaction.py --byond-bin <516.1681-bin>` checks the production
one-shot restart state machine in temporary storage with injected save/load and
restart effects. Run `--negative-control generation`, `consume`, `import` and
`deferred-reboot` too. The latter activates transaction ownership during the
production ordinary reboot callback's final yield and checks the shutdown guard.
`--prepare-only` stages source and hash receipts without launching BYOND.
See [the admin recovery guide](../../docs/world-save-restart.md). This fixture
does not establish full-map restart, client relogin or performance acceptance.

# Infinite area integrity

The contract fixture round-trips the production `INFINITY` artillery value through
JSON using a field-specific sentinel. `run-durable-graph.py --negative-control
infinity` must catch omitted sentinel restoration. Finite values retain their
original representation; malformed/wrong-field sentinels, negative infinity,
NaN and raw nonfinite wire values are rejected. The full metadata fixture audits
every inherited area subtype default and places a production invulnerable admin
area before the disk save. Its corrupt-sentinel checks reject before ClearMap.

# Lighting runtime graph recovery

`run-durable-world.py --lighting --byond-bin <516.1681-bin>` uses production
light-source, corner and overlay constructors, the actual world saver and loader,
and temporary disk storage. It checks customized and default light properties,
nested owner bindings, omitted runtime graphs, historical indirect graph entries,
source rebuilding, movement and switch-off registration cleanup. It preserves the runtime view singleton across map clearing and calls the production lighting queue through native view(). The recurring scheduler
and normal game startup are disabled; this does not establish full Europe import
or rendered illumination. Controls `lighting-export`, `lighting-legacy` and
`lighting-rebuild`, `lighting-opacity` and `lighting-view` each remove one production safeguard in generated source.
The legacy control must reproduce the ownerless `light_sources` constructor error.

The fixture also checks lazy corner source-list allocation with actual native
list identities, independent ownership, both propagation insertion/removal paths,
retained identity after removal, and nontrivial movement/obstruction changes.
Smart updates are compared with full recomputation. A coordinate-normalized
pre-save/post-load graph compares RGB, source membership and falloff strength.
`lighting-allocation-initial.json` records counts before the null assertion;
`lighting-allocation.json` records final allocated and distinct list counts.
These counts do not measure process memory or RAM savings. Controls
`lighting-eager` and `lighting-shared` change only generated test inputs and must
fail their specific allocation/ownership assertion. The offline
`test_lighting_corner_allocation.py` checks preparation and source preservation;
it does not compile or execute BYOND.

The native CI workflow accepts `lighting_recovery_regressions=true` for these
cases. The fixture closes its native port, rejects reopening and checks a
live OS socket census; a brief native startup listener can precede its entry.
Obstruction caches rebuild after contents/fields/hooks and before source updates.
On this Windows host, even the existing startup-only control exits
with `0xC0000409` before its entry marker. Clean compilation is separate evidence;
run the actual assertions on Linux CI rather than treating that exit as a pass.

## Restored input state regression

`run-string-path.py --input-runtime` runs the production saver/loader against
disk-backed v2 and unversioned legacy entries with old-process click/movement
deadlines and action locks. It checks export exclusion, import defaults, identity,
inventory and location preservation, and retention of existing live locks on a
replacement object. The actual early `ClickOn` gate and modifier dispatch run
against route counters, including ordinary/shift clicks and a live future
cooldown. This adapter does not prove rendered client input or gathering.

The input adapter also extracts the production fixed click-counter helper and
checks saturation, arbitrary-code rejection, no-client rejection, parsed icon
coordinates, and runtime trace export exclusion. It supplies the exact production
`isatom` macro and declares unavailable client rights/directory dependencies;
it creates no real client. Own-host authorization is checked separately by
`tests/nomads_lifecycle/test_input_trace.py`, including negative controls and
immutable pre-trace click-source parity with observational calls removed.

The existing authenticated `diagnose` action now arms a transient own-mob click
trace for 3000 world ticks on the first request for that client/mob. Reads do not
extend the window. Reconnects bind a fresh session token. Only fixed saturating
route counts are retained, never click targets or raw parameters. The same
response samples current click/move deadlines, remaining delays, action locks,
direction and facing lock. This changes diagnostic bookkeeping only; it does not
reset gameplay clocks or actions. Connected-client behavior still needs a normal
functional retest. The ordinary round-metadata fixture's job-limit initializer
is a pure no-op dependency adapter in shared `stubs.dm`, also used by the direct
round-trip fixture. Round-state mode defines `WORLD_SAVE_JOB_ADAPTER` and keeps
its production occupation adapter. This is not production occupation coverage.

Use the runner's required `--byond-bin` and `--expected-saving-sha256` arguments.
Run `--input-runtime-negative-control export` and `import` separately: each
removes only the corresponding runtime exclusion in generated temporary source
and must reproduce its specific failure. The export control bypasses these four
fields in both changed-variable selection and the final encoder, since either
guard alone prevents export. `--prepare-only` hashes and generates
sources without starting a compiler or game. Native execution requires the
current runtime owner's quiet window.

The standalone lifecycle fixture declares the fixed snapshot's operation/error
types with no active operation or collector. Its separate diagnose adapter
returns `fixture_diagnostics_unavailable`. Authentication, status and shutdown
controls still exercise the production endpoint; this fixture does not verify
live diagnostic collection.

The dimension and durable-world probes acquire production persistence operation
identities before bootstrap or import and pass the same identity to the backend.
They check nested direct-call rejection and final admission release. A manually
set busy flag does not authorize a positive save/load operation. Explicit busy
and concurrency rejection controls retain their original guards.


### Lost-limb wound recovery

`run-durable-world.py --wounds --byond-bin <516.1681-bin>` uses the production
wound constructor, encoder and loader with normal startup disabled and isolated
native savefiles. It checks 18 disk round trips: edged, blunt and burned wounds,
clean and unclean, through actual current-format export, explicit typed entries
and legacy flat entries. Assertions retain injury/stage/bleeding/treatment state,
helper arrays, embedded item identity and the cyclic organ/wound backlink.
Missing dynamic stage tables are rejected rather than reconstructed as healing.
The explicit entries model supported historical encodings; they are not the
incident Gaia save graph or full-world recovery evidence.

`--wounds --negative-control wound-restore` substitutes immutable wound and loader
sources from `d0ffbfb2335eb735756b998f3f2ff617c28f144b` in generated copies. Its
expected result is the original `Cannot read null.max_damage` constructor failure
at line 394 after the four ordinary-constructor checks. `--prepare-only` generates
and hashes inputs without compiling or running BYOND.

### Current admission boundary and CI (2026-10-19)

Current-source instrumentation leaves `Save_World` and operation admission intact.
Profiling starts only after `save_world_contents` accepts its operation token;
rejected or busy requests cannot restart the active serializer sample. Legacy
hash-bound inputs retain their original entry wrapper. Neither path measures
post-serializer validation or transaction/receipt work.

CI always runs `test_progress_sources.py` without native processes. The manual
`world_save_profile_regressions` option runs the positive profile, value-counter
control, clock contract and attribution control using the pinned trusted runner.
It is disabled by default. Source preparation accepts an existing `--byond-bin`
directory without installed native tools when `--prepare-only` is used.
Native parity, instrumentation overhead and end-to-end timing remain unverified
until those exact-source runs are actually completed and reviewed.
