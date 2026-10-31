# Nomads TEST1714 lifecycle

For the separate bounded read-only own-host diagnostics and offline sanitized
pair/trace/bundle commands, see [agent debug tools](../../docs/agent-debug-tools.md).
Their DM collector requires a reviewed rebuild/restart; discovery and offline
processing do not install or activate a runtime.

Default-off save/load variable evidence extends that same protected status path;
see [variable observability](../../docs/variable-observability.md) for the reader,
automatic runtime-relative failure file, explicit activation prerequisites and
unrun native acceptance. No new listener or generic variable access is added.

Normal native TEST1714 source is a clean checkout attached to master, tracking
origin/master from https://github.com/Civ13/Civ13.git. The master guard checks
both the cached and freshly advertised remote default branch, fetches master,
and requires exact commit agreement before staging. Detached or feature branches,
wrong upstream/origin, local changes (including untracked or hidden index state),
offline verification, stale source, and ahead/diverged commits fail closed.
Use `master_guard.py --repository ABSOLUTE_PATH --inspect-only` for local checks
without a fetch or index refresh. Standalone `--update` refuses ungated writes;
canonical hosting fetches and fast-forwards require the serialized save/load
mutation guard described below. It never resets, stashes, cleans or switches
branches. Experimental PR testing belongs in a separate checkout and explicit
operator path. Source verification does not establish a current running binary.

### Single canonical hosting directory

See [canonical save/load updates](../../docs/canonical-save-load-updates.md) for
the explicit, default-off canonical transaction prototype. Its same-process
coordinator confirms a successful same-map save and exact process exit **before**
fetching, fast-forwarding or compiling inside the named-master checkout. It
preserves one canonical DMB path and uses
the existing generation-bound startup and real readiness publisher. Failure
retains recovery; it does not start a fresh world, retry or force-kill. Native
admission and actual-cycle acceptance remain separate from source preparation.
The standalone update commands refuse mutation. The default-off canonical-only
owner starts a pinned existing save and holds the same child and lock through
typed maintenance; it cannot adopt an existing process. The combined bot
dispatcher remains unavailable until spool-writer authorization can be verified.

The older cycle below is for separate noncanonical runtimes. Canonical configs
are refused by that cycle and its builder, so it cannot compile before saving
or create a detached build/run copy underneath canonical hosting.

Windows supervisor for the separate native BYOND test server. It fetches the configured
branch every 300 seconds by default, stages and compiles a separate Europe build,
then requests the production authenticated save-and-shutdown operation. It never
pulls into the running directory. An unchanged revision only checks health.
Ordinary saves defer polling while busy. Once ready, a later ordinary save's
generation is allowed; the original startup generation remains the recovery
binding, rather than a permanent restriction on future saves. Errors, holds
and unconsumed intents still fail closed. Connected players defer updates, and
client count is checked again immediately before requesting save/shutdown.

The game must implement `nomads_lifecycle=1` status and `save_shutdown`, with a
32-character lowercase hex token in `config/lifecycle-token.txt`, runtime build
revision in `config/lifecycle-revision.txt`, and a process session challenge.
The API must reject non-loopback callers, replay and concurrent mutation, and
keep the current process alive after save failure. This supervisor submits each
mutation once, including when the reply is lost. It does not offer debug/eval.
Lifecycle restart intents bind `lifecycle_operation` and `lifecycle_session`
to the acknowledged request. An older internally consistent save is insufficient.

## Configure and install

1. Preserve the previous build and server configuration with their hashes. Use
   a new runtime root, leaving the previous installation and saves untouched.
2. Copy `config.example.json` to the runtime root, fill verified absolute tool
   paths, and place reviewed server configuration in `config_directory`. Create
   its secret token locally and restrict directory access to the server account.
   Never commit that directory. Disable other automatic reboot mechanisms.
3. Run `install.ps1 -ConfigPath <absolute-config>` under the server account. It
   installs a persistent polling loop at user logon,
   with no elevation, no task restart policy and overlapping instances refused.
   The account must remain logged in. Installation does not itself start it.
4. With separate runtime authorization, start that persistent task. No existing
   state means a fresh bootstrap unless `initial_save` names a validated generation
   with intent; this does not authorize discarding another server's progress.
   Keep the same supervisor process alive while checking state, events, build
   hashes and readiness. Do not transfer a running host to a new supervisor.
5. A save/restart/load acceptance needs a controlled update through that same
   owner and separate authorization. There is no supported one-shot acceptance
   handoff in this design. `--once`, including `--once --force-cycle`, is
   rejected before configuration or game startup.

Do not install from a temporary worktree that will be archived. Copy the reviewed
script into a durable installation and record its hash. No task or host is
installed by the offline tests or example configuration.

## Recovery and evidence

`HALTED.json` is persistent. Compile/fetch/save/recovery failures stop polling;
they never trigger forced termination, a fresh round, or an automatic retry.
Inspect the failure and actual process identity before any operator recovery.
The supervisor retains its launched child handle while that supervisor process
remains alive and checks its PID and creation FILETIME before treating it as
running. The lock serializes supervisors. An unexpected owned exit requires
operator action. A persisted PID and FILETIME are not a retained OS handle:
after supervisor termination, a later instance reports
`helper_lost` and refuses automatic adoption, status queries and updates. It
does not infer that the game exited. Direct launches remain independent of this
supervisor. The in-process state distinguishes absent, running, exited,
helper_lost, identity_mismatch, access_denied and unknown; inaccessible or
ambiguous observations never authorize a mutation.

An admitted save compares the current status session to the session retained
by this supervisor at readiness and rechecks the owned child immediately before
submitting. The server independently checks that session at admission. Before
readiness publication and mutation, the owner checks executable, working
directory, creation identity and a unique configured listener. Missing psutil,
access denial, unknown ownership or conflicting listeners fail closed. These
source checks do not prove Windows listener-table completeness or remove the
race after an observation. Do not enable the separately started canonical or
bot consumers: fresh supervisors cannot inherit a retained handle.

Both fresh and restored readiness publication require the same in-process
`Supervisor` with its retained child and listener observation. A manually
launched game is not adopted or published as supervisor-owned readiness. The
publisher checks the bound session, revision, map, owned state and generation;
fresh startup requires an empty generation and no completed import, while
restore requires the exact generation and completed import. Raw sessions are
not written to state or events. A healthy lobby with `ready: 0` remains
unavailable to the help observer.

The source-only owner dispatcher can serialize the typed canonical bot target
and `CanonicalCoordinator` under one held `supervisor.lock`, retaining the same
child and session. It revokes the old bot capability before a canonical update
and never converts v2 restart into an update. The default-off canonical binding
and initial start require explicit configuration and paired source review; the
unconditional spool-writer authorization refusal still prevents activation.
Separately started canonical updater commands cannot inherit a child handle.

Each update retains the old run, exact staged binaries, and a hash-verified copy
of the completed round-v2 save plus its matching one-shot restart intent. The
replacement must report the intended generation fully imported and intent
consumed. Never combine a build or intent with an unrelated save. A rollback is
an operator action using the retained previous build and matched backup in a new
run directory after resolving the stopped/failed host; no automatic rollback
loop is implemented. Preserve newer progress before selecting an older backup.

`events.jsonl` records build revision, process identity, operation and completion
status; `backups/<operation>/receipt.json` records generation and file SHA-256s.
Restart text identities follow BYOND `file2text()` CRLF normalization. Backup
copies and receipts still compare original raw bytes with SHA-256; a
text-equivalent newline rewrite does not match a retained raw-byte receipt.
No token is logged. Current tests exercise injected control flow and disk copies,
not a real DreamDaemon or Windows scheduled task. A successful full-game cycle
is separate required deployment evidence.

Run offline tests using the verified full Python executable:

```text
python -m unittest discover -s tests/nomads_lifecycle -v
```

## Optional player help observer

`help_manager.py` is a separate Windows process. It reads `state.json` every
five seconds and starts the reviewed `player_help_bridge.py` only for an exact
ready game PID/creation identity inside this root's `runs` directory. It never
calls the game API, modifies supervisor state, saves, stops or restarts the game.
Missing optional files or a failed worker do not prevent game startup.

Use a verified full interpreter path with these explicit arguments:

```text
<python> help_manager.py --root <runtime-root> --python <python> --bridge <durable-player_help_bridge.py> --config <private-help-config.json>
```

Copy the reviewed manager, its sibling `supervisor.py` and bridge into a durable
installation first, retaining hashes. The bridge must support `--stop-file`.
`install-help.ps1` registers an independent, limited, interactive at-logon task
with those same four arguments. It refuses to replace an existing task and does
not start the task. It does not alter the game updater's task. The account must
remain logged in. Installing or editing source does not update any running
Python process. Task registration and actual startup need separate verification.

The manager holds `help-manager.lock`. `help-manager.json` records a pre-spawn
intent, owned worker PID/creation identity, attempt count and status. It allows
at most three starts per run, with 10/30/90-second backoff after failures.
Restarting the manager preserves the attempt count. A retained worker or spawn
intent requires operator reconciliation; it is never automatically adopted.
`help-worker.log` retains worker diagnostics. It is local, private operational
material and should follow the installation's log-retention policy.

For graceful observer shutdown on Windows, create `ROOT/help-manager.stop`
(or the explicit `--stop-file` path). Remove that operator-owned marker before
starting another observer. This also works without a console; Windows process
termination does not deliver Python's signal handlers.
On a run change or requested manager shutdown, the manager creates its unique worker stop file.
The bridge stops accepting questions and drains its bounded in-flight requests.
After 150 seconds without exit, the manager records `stop_timeout` and exits
without forced termination or replacement. Reconcile that exact PID/creation
identity before another manager start. Stop markers and receipts are retained.

Any external `worker.lock`, including one from an older run observed by this
manager, blocks new workers. The manager never removes locks or stops external
processes. A known external worker clears only when its lock is gone and its PID
is absent; unknown/recycled identities require operator reconciliation. An
existing manually launched bridge therefore needs a coordinated shutdown before
automatic future transitions can be claimed. A fresh manager only knows the
current run and its retained receipt; inventory older manually launched workers
before its first installation. There is no automatic reboot/crash recovery.

Offline lifecycle tests inject process and clock effects and use temporary
storage. Bridge tests use mock transports, including publication failure controls.
These checks do not establish scheduled-task startup, model answer quality or
in-game delivery. Native game fixtures are unnecessary for this Python-only
observer and remain a separate acceptance boundary.

`test_startup_readiness.py` follows the actual public start and resumed paths,
including no-import and restored startup, and checks that the strict observer
starts only once after validated publication. Lobby, session/map/revision,
generation/import, stale-state and missing/recycled/denied-identity cases leave
state unpromoted. Sockets, processes and help transports are injected offline.
