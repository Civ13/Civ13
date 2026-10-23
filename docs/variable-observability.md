# Private bounded variable observability (schema 1)

Use structured diagnostics before asking an operator to manipulate the native
BYOND variable window. This extension observes save/load operations and captures
the objects already involved in a reference failure. It offers no arbitrary
reference lookup, variable selector, evaluation, proc invocation or mutation.
The stdio source MCP remains source-only; runtime access uses the existing local
lifecycle tooling described in [agent debug tools](agent-debug-tools.md).

## Availability and authorization

The collector is **default-off and not activated by this source change**. After
review and native verification, an operator must separately authorize the exact
rebuilt commit, deployment/restart and local diagnostic exposure. Activation
requires `config/variable-observability.txt` containing `enabled` (at most 16
bytes including a native line ending), plus the existing valid lifecycle token
and installed revision files. No activation file, credential or runtime change
is supplied here; `config/variable-observability.example.txt` contains only
`disabled`. The actual activation filename is Git-ignored. Before opting in,
separately provision the fixed runtime directory
`data/desktop-supervisor/variable-observability/` with private inherited file
permissions for the actual engine/operator account and administrator recovery.
Protect the opt-in file too. This does not require changing all of `data/` or
`config/`. The collector never creates directories, configures ACLs or attests
that existing ACLs are private; those remain the operator's responsibility.

No listener, Topic action, parameter or credential is added. The new status data
is reached only after existing IPv4 loopback/token/revision authentication.
Unlike the existing own-host camera diagnostic, status needs no connected client
or `R_HOST` account: it reads the configured supervisor's existing status surface.
Observation never requests save, load, restart, throw cleanup or a world update.
Those actions require their own applicable authorization.

## Inspect an authorized installed build

Use a verified full Python executable for `<python>`. These commands run from
the repository root. Keep output private; nothing uploads or publishes it.

```text
<python> -B scripts/nomads-lifecycle/agent_debug.py discover
<python> -B scripts/nomads-lifecycle/agent_debug.py recovery --root <private-supervisor-root> --revision <installed-40-hex>
```

`recovery` makes one existing status request. Its `data.variable_identity` gives
the current header only: `available`, `revision`, `session`, `round_id`, `tick`,
`realtime`, `utc`, `age_seconds`, `freshness`, `identity_validity`, `live_resolution`, `schema`.
Use its exact session and round in the next explicit read:

```text
<python> -B scripts/nomads-lifecycle/variable_observability.py --root <private-supervisor-root> --revision <installed-40-hex> --session <observed-32-hex> --round-id <observed-round>
```

This makes exactly one status request to existing `127.0.0.1:1714`, with a
15-second total transport deadline, at most 32 KiB and no retry. Read the result
before choosing another query; there is no watch loop. Existing lifecycle token,
config-directory and port prerequisites remain in force. The revision file is a
configured identity claim: verify the installed binary's provenance separately.
These read commands do not establish that the source checkout is deployed.

The native status extension is `debug.variables` (nested schema 1). The reader
returns `{schema:1, ok:true, read_only:true, data:{...}}`; runtime reads place the
retained capture in `data.failure`, active operation in `data.operation` and last
completed operation in `data.last_operation`. Inspect `data.failure_error` too:
`failure:null` with `failure_error:null` means no retained failure, which does not
prove every subsystem is healthy. A rejected retained failure instead returns
`failure:null` and its structured `failure_error`, while independently validated
current/last ownership remains available. Existing or disabled builds return
`unavailable` or `disabled`, not invented empty state.

## Automatic local failure file

When enabled, reference rejections and failed save/load completion replace the
single runtime-relative file
`data/desktop-supervisor/variable-observability/last-failure.json`.
It contains the capture itself, not the status wrapper. It contains no live
objects and remains historical after cleanup or deletion. A later accepted save
clears the in-memory reference record; the disk file remains historical until
another failure replaces it. File publication is best effort, is not atomic and
does not prove this is the newest failure. The fixed directory must already
exist. Its guard uses BYOND's [prefix directory listing semantics](https://www.byond.com/docs/ref/info.html#/proc/flist)
before any deletion or write. Missing storage, a refused deletion/write, or a
filesystem exception returns failure while preserving the in-memory capture;
none may replace the serializer's own rejection or strand operation release.
There is no fallback to the old path or a publicly inherited directory. A
replacement that deletes the old file and then cannot write can leave no disk
file; the authenticated in-memory status remains preferred. No append-only
incident history or public log is added.

The previous `data/variable-observability-last-failure.json` file is neither
moved nor deleted. Explicit offline `--input` reads remain path-independent, so
operators can still inspect an old private capture with the same identity,
freshness and optional `--historical` checks. Do not discover or expose old files
automatically. A file-only ACL under a broadly accessible parent is insufficient:
replacement recreates the file, inheriting the provisioned directory's ACL.

```text
<python> -B scripts/nomads-lifecycle/variable_observability.py --input <runtime>/data/desktop-supervisor/variable-observability/last-failure.json --revision <installed-40-hex> --session <observed-32-hex> --round-id <observed-round>
```

This is offline and returns the capture in `data` directly. It needs independently
obtained expected build/session/round identifiers; do not derive those expectations
from the file being checked. A file cannot establish the current live operation.
Neither mode resolves a native ref, even when a capture is recent.

The default reader rejects captures older than 60 seconds. To inspect an older
incident explicitly, add `--historical` to the `--input` command. The result is
always labeled `freshness: historical_only`, with its actual age; build/boot/round
pins, size/schema checks and future-clock rejection still apply. This option is
refused for `--root` before any query. It grants no live lookup or refreshed
identity and is never evidence that the captured state still exists.

## Interpret a reference failure

For a synthetic `original_target` rejection, inspect these fields together:

| JSON field within the capture | Interpretation |
| --- | --- |
| `kind = cross_level_object`, `saved_z = 1` | The per-level guard rejected a reference while exporting z1 |
| `source.type`, `source.field = original_target`, `source.entry` | Exact serializer field owner and entry, rather than a name-based guess |
| `source.turf.z = 1`, `target.type`, `target.turf.z = 2` | Physical source/target levels through bounded container paths |
| `source.throw.original_target.lookup_ref`, `target.lookup_ref` | Equality can correlate the two identities within this capture only |
| `source.throw.throwing`, `source.thrown_list.membership` | Distinguish inactive stale pointers from active throws; inspect both |
| `gc_destroyed`, `gcDestroyed`, `present` | Captured destruction flags or missing target; not a later deletion census |
| `operation.id`, `operation.stage`, `operation.owns_storage` | Save/load operation ownership when captured; not a completion percentage |
| `owner_chain`, `owner_chain_truncated` | At most eight schema frames that led to this field |

The raw scalar throw fields (`speed`, `range`, `dist_travelled`, `throwmode`,
`throw_speed`, `throw_range`) preserve JSON `null` as unknown, separately from
numeric zero. On this source's base `/atom/movable`, the first four default to 0,
`throw_speed` to 2 and `throw_range` to 7. Subtypes can override defaults and
runtime/imported state can differ. The reader does not manufacture defaults;
strings, booleans, containers and nonfinite values in these scalar slots reject
the failure evidence. The separate `throwing` flag is the producer's normalized
boolean observation.

`duplicate_durable_entry` additionally reports `first_z`, `first_entry` and
`current_entry`. An invalid or absent frame reports `unavailable` or a missing
source rather than inventing a field owner. `operation_failed` without a
reference record reports `operation_failed_without_reference_context`; it does
not invent a source/target or expose the raw exception.

Reference failures report `policy_classification = rejected_by_persistence_guard`.
This says the existing policy rejected the link; it does not classify it as
meaningful, transient, safe to null or safe to ignore. The separate persistence
policy owns transient exclusions and cleanup. Instrumentation counts the existing
`persistence_runtime_var` skip decision exactly where it is already made, without
calling that policy again:

- `operation.runtime_field_skip_decisions`: runtime field exclusions on export.
- `operation.runtime_reference_skip_decisions`: those exclusions whose current
  value is a direct datum reference; lists are not counted as direct references.
- `operation.legacy_runtime_field_skip_decisions`: runtime fields skipped on import.

Counts saturate at `skip_count_limit = 1000000000`; that value means at least the
limit. Repeated decisions can count the same field more than once. No field names
or values are retained in counters. They include all existing runtime exclusions,
not only throwing fields, and never claim live cleanup occurred. Use them only
when `skip_counts_available` is true. An admission rejected as busy has no new
operation or cleanup receipt and cannot erase another save's failure.

## Freshness, identity and bounded data

Snapshots bind the configured build, per-boot `session`, global `game_id` as
`round_id`, `snapshot_id`, operation ID, game tick, native realtime and UTC.
The reader rejects build/boot/round mismatches, partial/oversized captures,
clock reversal and, by default, captures outside a fixed 60-second UTC window.
Explicit offline historical inspection retains the capture-only restrictions. Status reads
also require capture-to-status tick/realtime differences in `0..600` and a
matching active or last operation ID. `stale_snapshot`, `correlation_mismatch`,
`partial_snapshot`, `schema_rejected`, `disabled`, `unavailable`, `invalid_input`
and `transport_or_file_unavailable` are structured errors without raw exceptions.
If only retained failure evidence is stale, mismatched, partial or malformed,
status returns `ok:true` with valid current ownership and `data.failure_error`;
it withholds the rejected capture and never rewrites its timestamp or identity.
An invalid/stale current status header or invalid current operation still rejects
the entire read. Whole-packet framing, valid-JSON, size and credential-safety
checks also remain strict before partitioning. Default offline `--input` inspection has no independent current
status and continues to reject an invalid or stale capture as a command error.
The producer formats UTC from `world.timeofday`, with an explicit zero timezone
offset; a midnight rollover during formatting returns unavailable. Absolute
`world.realtime` is coarse floating-point metadata and native JSON can round it
further. It is checked for reversal, not used as a 60-second age clock. UTC and
game-tick limits remain in force, including strict future-time rejection.
BYOND documents the epoch precision limit and recommends `world.timeofday` for
more accurate readings; `time2text` accepts it as the current date and uses the
explicit third argument for the timezone. See the [BYOND reference](https://www.byond.com/docs/ref/info.html#/proc/time2text).
UTC freshness assumes a trustworthy local clock. A frozen game clock, matching
round or identical type/coordinates does not prove current object identity.

Native refs can be reused after deletion and pooled datums can be reused. Every
identity is `validity = capture_only`, `generation = unavailable`; no construction
generation is instrumented. Never reconstruct a live object or durable identity
from these strings. Creation time, later deletion, engine event history and
changes between snapshots are unavailable. Re-querying status returns historical
failure evidence and does not refresh its object observations or capture time.

Each object has at most eight location links with `found`, `cycle`, `depth_limit`,
`no_turf` or `not_atom`; missing turf is unknown rather than z0 evidence. Only
three fixed throw links are captured, one level deep. Two registries
(`thrown_list`, `processing_objects`) inspect at most their first 256 entries per
object. `present` proves prefix membership at capture; `absent` requires a complete
scan; a truncated miss is `unknown`. No world enumeration, recursive field/list
walk, getter invocation or retained live object registry is introduced.

The automatic file is bounded to 32 KiB JSON plus a native LF/CRLF. Status reserves
8 KiB for its existing wrapper and omits oversized variable evidence with an
explicit error. Oversized automatic captures become a small partial envelope.
Types are capped at 160 characters, schema fields at 80, owner frames at eight.
The reader copies only allowlisted fields at every level and strips unknown
fields, names, accounts, credentials and raw errors. **The retained refs, type
paths and coordinates are still private operational data**, not a public report;
review and redact them before sharing. The existing public lighting bundle does
not export this private failure schema.

## Verification limits

```text
<python> -B -m unittest discover -s tests/nomads_lifecycle -p test_variable_observability.py -v
<python> -B -m unittest discover -s tests/nomads_lifecycle -p test_variable_publication.py -v
<python> -B tests/world_save/test_cross_level_sources.py -v
<python> -B tests/nomads_lifecycle/prepare_variable_probe.py --output <new-temporary-packet-directory>
```

The offline tests exercise the actual Python reader with synthetic packets and
scalar defaults read from the production movable declaration,
source guard omission controls, redaction, stale/reused-ref refusal, deleted/cycle/
depth markers, throw states, operation failures and bounded output. Preparation
copies the production collector, named base movable declarations and trim helpers
with source hashes and declares
`native_verified:false`. It does not compile or run BYOND. The native collector
probe has minimal data/auth adapters and is not full serializer/transport evidence.
The preparer's `--publication-mode` selects `writable` (default), `missing`,
`obstructed` or `unwritable`. The missing case leaves the fixed private directory absent. The
obstructed case creates a directory at the fixed output filename, then requires
both a direct native file-write refusal and failed collector publication while
preserving that directory and the in-memory capture. This changes no ACLs and
is **not** evidence of an access-denied condition. The collector may reject at
its deletion guard before reaching its write exception handler.
The
unwritable case only prepares the directory and declares
`unwritable_fixture_permissions_required:true`; it does not change permissions.
Before a separately approved native run, that case needs a reviewed temporary
fixture-only write/deletion denial. Without it the negative control must fail.
Do not apply that denial to a live directory. The writable probe retains
`native-reference.json` and `native-operation-failure.json` inside its private
fixture directory before its oversized negative control replaces the final file.
Read those native captures with the actual reader and independently fixed
build/session/round expectations; a DM-only assertion count is insufficient.
Offline source controls and preparation tests do not establish native I/O or
Windows ACL behavior. The new publication cases remain unexecuted until a
bounded native packet is reviewed and admitted.

`tests/nomads_lifecycle/run_variable_probe.py` is an offline-importable,
grant-gated Windows runner proposal. It creates no grant or reservation. Its
sealed packet must contain the reviewed Job adapter, an exact compiler/engine
identity, and the actual reader. A missing grant refuses before host queries,
native imports, output creation or a consumed marker. A future run requires a
fresh matching coordinator slot and allocator-consumed single-use claim. The
native baseline must be empty; the runner never stops Gaia to make it empty.

The proposed phases are preflight 10 seconds, compile 20, writable 15,
immediate retained-capture reads 10, missing-directory 10, obstructed-file 10,
and final verification 5. They share a 90-second work deadline, with up to 30
seconds for owned cleanup and 120 seconds overall. The four sequential children
are one compiler and three fixture daemons, with at most one active child.
Process memory is capped by the existing Windows Job at 512 MiB; watcher memory
is checked against 128 MiB, aggregate private memory against 768 MiB, and owned
CPU against 60 seconds. Wall/CPU/artifact checks are cooperative observations,
not new OS quotas. All packet files, compiled artifacts, isolated environment,
logs, captures and receipts count toward 32 MiB and 256 entries; non-binary
generated evidence shares 1 MiB. Cap failures retain evidence and cannot pass.

Each daemon starts only on fixed IPv4 loopback port 59474. The fixture closes
it immediately, writes a marker, and waits for the runner to confirm no owned
TCP or UDP sockets in either address family before acknowledging closure. The
closure deadline is five seconds; only that single startup listener is allowed
before acknowledgement, and no socket is allowed afterward. There is no client,
public probe or Topic request. Final owned cleanup must verify retained process
exits, empty Job membership and accounting, and port vacancy. The actual reader
validates both retained native captures immediately after the writable child,
before later negative modes, using unchanged 60-second freshness checks. The
ACL-denial, authenticated Topic and full serializer gaps remain open.

The separate `run_variable_probe_linux.py` wrapper selects this same tiny
fixture only on normal pull-request hosted Linux CI, using the existing
introduced-test selector. It never consumes or weakens the Desktop packet's
grant or empty-baseline restrictions. CI uses the existing installed 516.1681
engine, no account/session inputs and only fresh directories under RUNNER_TEMP.
Child environments exclude GitHub credentials.
Linux daemon logs use the fixed relative basename `native.log` within each
fixture working directory, respecting the engine's absolute-log-path refusal.
Process ownership follows the
existing extraction wrapper: a new session/group, WNOWAIT observation, owned
group cleanup before reaping the leader, and recorded birth ticks and exits.
Socket inspection extends the durable-world /proc approach to all owned TCP
and UDP sockets in both address families. A native-empty baseline is mandatory.
The same phase, artifact and socket-closure budgets apply; Linux enforces
512 MiB address space, 15 CPU seconds and 1 MiB per file per child, with core
dumps disabled. Watcher/combined memory checks use observed RSS, not Windows
private bytes. Evidence upload excludes config files and compiled binaries.
Successful hosted execution proves only this collector/file-reader fixture,
not Windows ACL behavior, authenticated Topic access or full save/load behavior.

The preserved native attempt at `df639b1` compiled cleanly and its tiny collector
reported 22 checks with zero failures. The overall run was **rejected**: its reader
rejected a future-rounded UTC stamp, child accounting was incomplete, and startup
logged a loopback bind before closure. This is not a passing round trip or
zero-listener run. The subsequent source clock correction is not native-verified.
Authenticated Topic integration, complete save/load round trips, full-game
performance and the other stated integration limits remain unverified.
Full-game BYOND 516.1681 compilation in CI is
separate, exact-head evidence; a passing build does not establish collector
execution or validate a later head. Do not relabel source tests as native acceptance.
No live world, save, native client or OpenDream process was used to develop this.
