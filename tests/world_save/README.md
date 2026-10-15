# World-save regression world

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
`generation`, `busy`, `tod`, `music-body`, `music-round` and `music-lobby`
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
restart effects. Run `--negative-control generation`, `consume` and `import` too.
`--prepare-only` stages source and hash receipts without launching BYOND.
See [the admin recovery guide](../../docs/world-save-restart.md). This fixture
does not establish full-map restart, client relogin or performance acceptance.
