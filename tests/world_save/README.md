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
