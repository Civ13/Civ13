# Nomads TEST1714 lifecycle

For the separate bounded read-only own-host diagnostics and offline sanitized
pair/trace/bundle commands, see [agent debug tools](../../docs/agent-debug-tools.md).
Their DM collector requires a reviewed rebuild/restart; discovery and offline
processing do not install or activate a runtime.

Windows supervisor for the native BYOND test server. It fetches the configured
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
3. Run `python supervisor.py --config <absolute-config> --once` with the verified
   full Python path. No existing state means an explicitly authorized fresh
   bootstrap, unless `initial_save` points to a validated generation with intent.
   This does not authorize discarding another server's progress.
4. Verify `state.json`, `events.jsonl`, build hashes and runtime readiness.
   Exercise one real save/restart/load with `--once --force-cycle` before claiming
   runtime acceptance. Keep users out of the test during this verification.
5. Run `install.ps1 -ConfigPath <absolute-config>` under the server account, then
   start its scheduled task. It runs a persistent polling loop at user logon,
   with no elevation, no task restart policy and overlapping instances refused.
   The account must remain logged in. Installation does not itself start it.

Do not install from a temporary worktree that will be archived. Copy the reviewed
script into a durable installation and record its hash. No task or host is
installed by the offline tests or example configuration.

## Recovery and evidence

`HALTED.json` is persistent. Compile/fetch/save/recovery failures stop polling;
they never trigger forced termination, a fresh round, or an automatic retry.
Inspect the failure and actual process identity before any operator recovery.
The PID and creation FILETIME must match; PID reuse refuses ownership. The lock
serializes supervisors. An unexpected owned exit also requires operator action.
Reclaiming a supervisor stopped during startup requires the same expected
generation, completed import and consumed intent checks before any next update.

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
