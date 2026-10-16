# Nomads TEST1714 lifecycle

Windows supervisor for the native BYOND test server. It fetches the configured
branch every 300 seconds by default, stages and compiles a separate Europe build,
then requests the production authenticated save-and-shutdown operation. It never
pulls into the running directory. An unchanged revision only checks health.

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
