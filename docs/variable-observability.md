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
`disabled`. The actual activation filename is Git-ignored. Restrict the runtime `data/` directory and captured output to
the authorized operator before opting in; file privacy depends on host ACLs.

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
single runtime-relative file `data/variable-observability-last-failure.json`.
It contains the capture itself, not the status wrapper. It contains no live
objects and remains historical after cleanup or deletion. A later accepted save
clears the in-memory reference record; the disk file remains historical until
another failure replaces it. File publication is best effort, is not atomic and
does not prove this is the newest failure. A failed file replacement never alters
the serializer's rejection or operation release. Prefer the authenticated status
record when available. No append-only incident history or public log is added.

```text
<python> -B scripts/nomads-lifecycle/variable_observability.py --input <runtime>/data/variable-observability-last-failure.json --revision <installed-40-hex> --session <observed-32-hex> --round-id <observed-round>
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
