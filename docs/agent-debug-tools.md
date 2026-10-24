# Bounded agent debug commands (schema 1)

For default-off private save/load variable evidence and automatic sanitized local
failure snapshots, see [variable observability](variable-observability.md).
`recovery` additionally discovers its current header as `data.variable_identity`;
it does not resolve or export retained object evidence. The separate reader pins
the expected build/session/round and rejects stale data. No runtime MCP capability
or deployment is implied.

These commands investigate the configured Host's own current view through the
existing lifecycle transport. They provide cached state, not rendered pixels or
a lighting repair. There is no eval, arbitrary variable/coordinate/target access,
new credential, listener, save mutation, restart command or model inference.

## Commands

Use a verified full Python executable for `<python>`. Run from
`scripts/nomads-lifecycle`, or prefix the script names with that directory.

| Command | Input and result | Runtime access |
| --- | --- | --- |
| `agent_debug.py discover` | Versioned command schemas and fixed limits | None |
| `agent_debug.py recovery --root <private-root> --revision <40-hex>` | Readiness, recovery hold, classified failure, save/load stage and sanitized cached error source prefix | One authenticated status request |
| `agent_debug.py vision --root <private-root> --revision <40-hex>` | Own camera, vision, three plane masters, five named HUD fields | Status then one own-host diagnostic |
| `agent_debug.py tiles --root <private-root> --revision <40-hex>` | Own 3x3 lighting neighborhood, bounded owners/corners and cached lighting worker state | Status then one own-host diagnostic |
| `debug_bundle.py pair --input <tiles.json> --black-slot 4 --visible-slot 5` | Two existing local slots from one capture; labels are supplied by the operator | Offline |
| `debug_bundle.py trace --input <first.json> --input <later.json>` | Two to eight ordered cached observations of the same runtime, body and neighborhood | Offline |
| `debug_bundle.py bundle --input <snapshot.json>` | Explicit opt-in sanitized reproducible summary | Offline |

All JSON command outputs use schema 1. Query errors are `invalid_input`,
`transport_unavailable` or `snapshot_rejected`; offline errors are
`input_rejected`. Raw exceptions and responses are withheld. `read_blackout.py`
is the lower-level private reader, not a public report generator. It retains
account identity, object references and coordinates; keep its output private.
The `agent_debug.py` query outputs also contain private runtime identifiers,
positions and body information. Only the separate offline bundle command makes
the allowlisted summary. Nothing uploads or publishes a file.

## Authentication and fixed bounds

The handler retains existing loopback (`127.0.0.1`) token and installed-revision
authentication. `diagnose` adds exactly `session`, `operation`, and `target` to
the status request keys. The configured `config/host.txt` account must match
the target, be connected, and already hold `R_HOST`. The server selects that
client's current body. There is no fallback to another client or admin.

Each boot admits at most 64 diagnostics at least 100 game ticks apart (ten
seconds at the normal game clock). Nonces and cooldown are reserved before
target lookup. The existing save/shutdown admission remains separate. Only
diagnostic protocol bookkeeping changes. Copying scripts never changes a live
world, its credentials, configuration or supervisor hold.

Each diagnostic is synchronous and bounded: nine turf slots, at most eight
location links, four corners per turf, 64 local atoms per turf, 256 registry
prefix entries, 20 color entries and 160 text characters. Responses are at most
32 KiB; transport deadline is 15 seconds, fixed at `127.0.0.1:1714` with no
automatic retry. Missing bodies, changed targets/ticks, truncated local atoms,
capture errors and omitted oversized samples are marked partial. The pair,
trace and public bundle helpers reject partial tile/view snapshots.

The cached status extension reads the current save/load operation kind, z-level
and backend/contents/mutation/player-restoration flags. There is no completion
percentage. Error metadata examines only the first eight cached source slots;
it emits allowlisted repository `code/*.dm` paths, line and counts. Raw runtime
messages, proc names and stacks are unavailable. An older installed status
without debug metadata explicitly reports `available: false`; do not infer idle
or healthy state from unavailable fields.

## Paired tiles and actual screenshots

The nine tile slots are ordered `dx = -1..1`, then `dy = -1..1`; slot 4 is the
own turf. Pick two distinct present slots after matching their private
coordinates to a genuine client capture. `black` and `visible` are operator
observations, not classifications made by the tool. If a suitable visible tile
is outside this neighborhood, the comparison is unavailable. Never expand the
sample or substitute another player's coordinates.

Capture the real client with a separate authorized capture tool. Record the
capture's UTC, SHA-256, reviewed build, map/reproduction steps, and nearby query
request/ticks privately. Match the client/body and position across the capture
and diagnostic. The JSON's unchanged tick is not evidence of what rendered.
Supply only the external file's hash and strict UTC to the sanitized bundle:

```text
<python> debug_bundle.py bundle --input vision.json --input tiles.json --black-slot 4 --visible-slot 5 --screenshot-sha256 <64-lowercase-hex> --screenshot-utc 2026-10-17T12:00:00Z
```

This timestamp is an example. The tool never reads an image, captures pixels,
verifies the supplied hash against pixels or proves screenshot correlation.
Both screenshot hash and UTC are required together. The output states these
limits and does not include the screenshot or its path.

## Observed lighting lifecycle trace

Collect at most eight separately authorized tile snapshots while standing at
the same position and respecting the diagnostic cooldown. Trace checks the
revision, session, current client/body fingerprint, increasing ticks and exact
nine-slot neighborhood privately, then emits fixed numeric/enumerated summaries.
It can show observations of overlay presence, owner/prefix state, luminosity,
startup/created flags, daylight setup/updating/revision and queue length changing
between samples. A missing registry entry beyond the prefix is unknown.

This is a sampled cached trace. Engine lifecycle events and changes between
samples are unavailable; there is no retrospective constructor/deletion event
log. A genuine engine event trace remains unsupported. Sampling does not
refresh lighting, invoke appearance getters or establish the cause of a black
view. A changing body, moved neighborhood, mixed boot/build or partial snapshot
rejects the trace rather than comparing unrelated samples.

## Sanitized reproducible bundles

Bundle creation is an explicit separate offline action. Input files are each
bounded to 32 KiB and the command accepts at most eight. The output allowlists
build revision, tick, local slot numbers, fixed vision/lighting numbers and
flags, enumerated registry state, recovery stage and optional external capture
hash/UTC. It strips accounts, session/request/body fingerprints, object refs,
absolute coordinates, type/resource labels, health, file paths, raw errors and
unknown fields at every copied level. Invalid numeric/enumerated fields reject
the input rather than copying free text. It includes a repeatable command
procedure; add only reviewed, nonprivate map and interaction context when
preparing an actual public report.

The versioned `agent-debug-examples.json` and tests are synthetic illustrations,
never incident or gameplay evidence. No private captures, saves, tokens, runtime
receipts or user paths belong in the repository or public CI artifacts.

## Verification and restart

Run `<python> -B -m unittest discover -s tests/nomads_lifecycle -v` from the
repository root. Tests inject transports, sockets, temporary configuration and
synthetic snapshots; source mutation controls check auth, bounds and forbidden
effects. The existing CI compiles the exact PR head with BYOND 516.1681 and
selects this offline suite when new tests are introduced. Offline checks do not
execute native authentication or prove game/rendering behavior.

Restart required: **yes** for the DM collector and cached status extension,
after an explicitly authorized reviewed build/deployment. Offline discovery,
pair/trace/bundle commands need no restart. There is no DM hot reload. An older
installed build may have none of these fields or commands. Source/CI acceptance
does not establish installed availability, native fixture acceptance or client
capture acceptance; report each separately. This patch contains no daylight
repair or updater/runtime change.
