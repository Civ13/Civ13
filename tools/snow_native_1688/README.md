# Snowfall module fixture: Linux BYOND 516.1688

This is an exact-source, synthetic module lane, not a game boot. It is separate
from historical 516.1681 acceptance harnesses. Preparation is the default; it
never launches BYOND. Native execution and the optional hosted workflow require
separate review of the exact controller source. Merely preparing this packet is
not evidence that the DM compiles or that a native assertion has passed.

## Source and runtime identity

- Production source HEAD: `47d788a306ae6b7e19327a0bdf7d388972d07b94`.
- Production source tree: `f2393bd7264b5d3b8aae553f80add05fa67e9bf7`.
- Optional controller commit's sole parent:
  `68a89db5c3d93afc486522e4d0a9be9351758a0e`.
- Target: Linux BYOND `516.1688`.
- Repository-release ZIP SHA-256:
  `16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9`.
- Unmodified retained-leader controller SHA-256:
  `41c9a029e5475a8bc98a423f2961ac782b067beaf34cf61fd857f4bce819a52d`.

`source-bindings.json` pins eight source inputs by Git blob, tracked mode, and
byte count. Native preparation additionally requires a real clean checkout with
exact HEAD/tree and tracked input inventory. Export preparation authenticates
these blobs without creating a Git repository or claiming a checkout.

The baseline includes the complete, unchanged production snowfall module and
process, the exact `icons/turf/snow.dmi` asset, and byte-extracted production
`/turf/floor/New()` and `/turf/persistence_runtime_var(key)` hooks. The historical
`native_probe.dm`, `AGENTS.md`, and `turf.dm` are authenticated reference inputs,
not extra compiled modules. The historical probe is not modified or invoked.

## Adapter and evidence boundary

The 18 x 18 x 3 world contains only generated synthetic turfs. Type scaffolding,
minimal parent methods, area/weather values, and required constants are explicit
in `fixtures/stubs.dm`. `get_temp` injects Celsius values and counts calls.
`GetAbove` follows only injected adjacent, upward, same-coordinate links, so its
fixture topology is finite and acyclic. Actual climate/heater services, elevation
providers, map content, game scheduler, floor materials, qdel/Destroy lifecycle,
and persistence serializer are not linked.

The baseline's 64 assertion IDs are enumerated in `expected-assertions.json`.
They exercise eligible types, weather/cold/melt boundaries, persistence holds,
exposure through synthetic topology, native appearance properties and ownership,
substrate preservation, finite stock and stale generation debit, native turf
replacement, swap removal, reload clamping/no sampling, saved-field and runtime
exclusion hooks, and bounded process cursor/batch behavior. The process case
requires two actual 256-candidate batches; early tick-usage yielding fails rather
than being silently counted as full batch evidence.

Six independently compiled controls each run only their relevant fixture case:

| Mode | Only accepted failed assertion |
| --- | --- |
| overlay-omission | appearance_present |
| melt-omission | warm_debit_rejects |
| generation-omission | stale_after_reaccumulation |
| reload-generation-omission | fresh_wait_invalidated_by_reload |
| reload-sampling | reload_zero_no_accrual |
| del-unregister-omission | replacement_registry_exact |

Each mutation changes one unique anchor in a scratch copy of the production snow
module and produces `mutation.diff`. Baseline must have no failed assertion;
each control must have exactly its named failure, not merely any failure. JSON
and native log assertion sets, integer values, counts, bindings, and result marker
must agree. Fatal diagnostics, unexpected listeners, missing/extra assertions,
or compiler warnings fail the entire lane.

This does not establish full serializer roundtrips, real save/recovery behavior,
real climate or multi-z wiring, scheduler/gameplay performance, shovel handlers,
client-visible appearance, reconnect behavior, or multiplayer behavior. No client
is admitted; no full game or real save path is used. Existing movement/WMI and
local/native access holds are unaffected.

## Pure preparation and offline tests

From a packet containing `source-inputs`:

```sh
python3 -B tools/snow_native_1688/run.py \
  --source "$PWD/source-inputs" --source-export \
  --output /absolute/fresh/snow-prepared
python3 -B -m unittest discover -s tools/snow_native_1688 -p 'test_*.py' -v
```

Use `SNOW_TEST_SOURCE=/absolute/exact/source` for the offline tests when the eight
inputs live in a separate real checkout. The workflow test belongs to the optional
workflow patch; the other two test modules work with tooling alone. No BYOND
binary, socket, signal, or live proc census is exercised by these tests. They use
synthetic callbacks/files and reject accidental native subprocess creation.

`--source-export` and `--reviewed-native` are mutually exclusive. Omit both for
pure preparation from a real exact checkout. Outputs must be fresh, non-symlink,
outside the source, and free of parent traversal. Preparation records all
compiler/daemon attempted, started, and completed flags as false.

## Reviewed execution contract, not authorization

The optional one-shot workflow is the proposed acquisition/execution route. It
has one exact branch-created push trigger, repository/ref/first-attempt gates,
pinned actions, Python 3.12, read-only contents permission, and separate controller
and production checkouts. It verifies the sole parent, approved change paths,
source HEAD/tree/cleanliness, and acquisition-script/manifest Git blobs. It uses
only the reviewed Ubuntu dependencies and repository-release archive, with no
fallback, global BYOND installation, byondsetup, or security-setting changes.
Publishing that controller branch would trigger native execution and therefore
must not happen before the main reviewer explicitly activates the proposal.

Compile phases are bounded to 180 wall seconds, 150 CPU seconds, 2 GiB address
space. Runtime phases are bounded to 30 wall seconds, 20 CPU seconds, 1 GiB address
space. The controller has a 600-second aggregate budget, with cleanup reserve;
the native workflow step is 11 minutes and the whole job 25 minutes. Output files,
counts, aggregate sizes, and logs are bounded and checked during each phase.

The controller retains the leader identity without reaping it until group cleanup,
tracks only owned descendants, and verifies process-group absence and observed
child cleanup. `attempted` records entry into a phase; `started` is set only by
the real post-Popen callback; `completed` means successful process termination
and cleanup, not semantic acceptance. Overall `status: passed` additionally
requires all compiler, listener, immutable-input, and exact oracle gates.

The daemon may briefly create its engine startup socket, bound only to loopback.
`world/New()` immediately closes it with `OpenPort("none")`; the override refuses
all reopening, including the explicit test request. Before semantic tests, the
fixture requires a source-bound controller acknowledgment after an owned-process
TCP/TCP6 listener census. The controller never connects to a port. Any remaining
owned listener, identity race, closure failure, or malformed bind log fails closed.
This is a closed-listener admission contract, not a claim that no engine startup
socket was ever created.

Evidence staging uses fixed allowlisted source/diagnostic paths, at most 8 MiB
per file, 64 MiB total and 256 files. It excludes binaries, compiled resources,
archives, arbitrary files, and save data. Missing/rejected files are recorded;
artifact staging alone is not native acceptance evidence. Hosted retention is
seven days.
