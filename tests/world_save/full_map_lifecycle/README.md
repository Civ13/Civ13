# Full-size Europe recovery probe (candidate)

This test-only adapter targets frozen gameplay source
`b75564225f09153b006af97aa8229bbd38db421c`, including the reviewed lighting
runtime graph fix. It prepares a new source tree and
adds a fixed authenticated local control surface before normal Topic logging.
It does not modify the existing Europe host on port 18462.

`prepare.py --repository <checkout> --output <new-directory>` exports the pinned
Git tree, selects the actual Europe DMM, inserts a single Topic dispatch and
records source/adapter hashes and exact observer insertions. Existing output directories are refused. Its
private random token stays in the generated configuration, outside the tracked
source tree. Preparation neither builds nor launches a host. Exported config
still requires isolation review, including outbound integrations and listener
exposure, before an independently reviewed launch.

The adapter accepts exactly four query fields. It checks IPv4 loopback, a
private token and a fresh per-boot session for mutations. It exposes only:

- `status`: map dimensions, ticker phase, source/session identity, round clocks,
  completed generation and restart/import state. No token or player account data.
- `start`: the existing admin Start Now inputs (`round_progressing`,
  `pregame_timeleft`, `admin_started`). The ordinary pregame scheduler and
  `setup()` perform the state transition. No direct state assignment, fake
  client or replacement startup procedure.
- `restart`: the actual production `persistence_restart.execute()`, which saves,
  validates, publishes its intent and invokes native reboot. Ordinary startup
  imports the generation and consumes the intent. The test does not replace
  serialization or native reboot. A synchronous test receipt at the native
  reboot boundary inventories the completed generation and file MD5 hashes.

`query.py --run-root <directory> --port <separate-port> --action status|start|restart`
checks the source and current boot session before mutation. It excludes the
four protected existing-host ports. It never starts or stops a process.

Before native launch, obtain independent review and record a process lease,
isolated configuration, compiler version/log, binary hashes, PID/creation time
and port ownership. Check wrong-token and stale-session rejection before the
round start. PLAYING alone is insufficient: generated observers require real
setup/autobalance and all four delayed nature passes to finish. Then the adapter
creates one named crate with one nested knife and persists their coordinates and
identity. These are injected representative objects, not player acquisition.
Use an explicit
long save/recovery deadline (at least 20 minutes), preserving logs, saves and
intent on failure; a timeout must never be reported as recovery success.

Acceptance needs matching completed-generation hashes before/after native
restart, import completion, cleared hold/busy state, consumed intent, preserved
map dimensions/round identity/metadata and restored representative map objects.
`run.py --repository <checkout> --output <new-directory> --byond-bin <516.1681-bin>`
implements the supervisor with a default 1800-second save/reboot/import deadline,
separate port 18463, exact clean compiler gate, new-process handle ownership,
listener PID verification, authentication refusal controls and fail-closed
recovery comparisons. It always stops only its own newly created process and
preserves the entire output on failure. It never reloads a PID from disk to stop
a process. The test host rejects all player connections and uses native safe
mode, public exported config with hub/webclient/outbound settings removed, plus
startup webhook/Tor guards. No live configuration or saves are copied.

Preparation reuses the frozen `build-progress-probe.py` instrumentation and
helper. `save-progress.jsonl` samples actual serializer progress; diagnostic
replacement can be partial and never determines save success. Original tick
thresholds and `stoplag()` stay intact. Read the parent README for diagnostic
overhead and clock limits. This is observation, not a measured optimization.

`test_supervisor.py` runs offline protocol fragmentation/refusal checks,
reversible frozen-source observer checks, and corrupted/incomplete recovery
negative controls without a compiler or game process.

No full-size save/restart/import result is claimed until an actual run passes.
With no
connected player it cannot establish body, inventory, HUD or reconnect behavior.
The TEST1714 launcher/supervisor lifecycle remains a separate acceptance test.

The prior frozen42007/cb4 probe and its failed Europe generation remain unchanged.
This successor starts from a fresh temporary host and writes a new generation;
it does not overwrite or silently migrate the earlier failed save. Historical
lighting-entry suppression is also checked by the separate lighting fixture.
