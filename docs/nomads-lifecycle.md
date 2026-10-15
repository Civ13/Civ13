# Local Nomads lifecycle interface

The Windows test supervisor can request a validated save and graceful shutdown,
replace the game binary, and start the existing one-shot recovery path. This
endpoint does not install a supervisor or establish successful recovery itself.
The actual supervisor cycle must verify the restored world and account reclaim.

The endpoint is disabled unless the isolated host has these runtime files:

- `config/lifecycle-token.txt`: a private random 32-character lowercase hex token.
- `config/lifecycle-revision.txt`: the exact 40-character lowercase Git commit
  used for the installed binary. This is a configured identity claim; the
  supervisor must independently verify build provenance and binary hashes.

Restrict the token file to the host operator and supervisor. Never commit its
contents or include it in command logs, status receipts, PRs or crash reports.
The endpoint accepts only IPv4 loopback, including BYOND's address-with-port
format. Its dispatch precedes generic Topic logging to avoid logging credentials.

Send a BYOND Topic query with exactly these keys:

- Status: `nomads_lifecycle=1`, `token`, `action=status`.
- Mutation: `nomads_lifecycle=1`, `token`, `action=save_shutdown`, `session`,
  `operation`.

Status returns `ok`, `revision`, `session`, `map`, `maxx`, `maxy`, `maxz`,
`ready`, `busy`, `operation`, `error`, `generation`, `clients`, `restart_hold`,
`restart_import_complete` and `restart_intent`. It never returns the token.
The session is a per-process challenge; echo it on mutation and omit it from
receipts. An operation is a fresh 32-character lowercase hex identifier.
Unknown fields and actions are rejected. A maximum of 64 admitted operations
is retained per process, including failed saves. Capacity refuses further
operations without eviction, so old identifiers cannot become valid again.
A new process has a new session and rejects requests from the preceding boot.

Mutation admission reserves the operation before yielding. An accepted reply
means work started, not that a save completed. Poll status and the known process
identity; do not resend an uncertain mutation. Concurrent saves, startup holds,
unresolved intents and incomplete dimension allocation refuse the request.
Failed saving or validation leaves the process running. Successful saving uses
the existing completed-generation validator and publishes
`map_saves/restart_intent.json`, with exactly `version` (1), `generation`
(`round-v2:` prefix), `metadata` (MD5 of `map.txt`) and `round` (MD5 of
`round.json`). Those hashes are existing generation ownership checks, not
authentication credentials. The final shutdown boundary validates ownership
again and checks the intent and completion marker after the yielding validator.
Only then does native `del(world)` close the process.

Preserve the complete save generation, intent, configuration and known-good
binary before replacement. On restart the ordinary production startup hold,
dimension bootstrap, import and intent consumption apply. `ready` stays false
until recovery and the waiting-client reclaim sweep complete. The yielding
serializer does not provide an atomic snapshot of all ongoing gameplay.

`tests/world_save/run-lifecycle.py --byond-bin <516.1681-bin>` runs production
endpoint and transaction code in temporary offline storage. The serializer and
identity reader are injected fixtures; denied requests and generation failures
must not reach the shutdown effect. The final positive request invokes actual
native world deletion after durable intent publication. Authentication and final
generation negative controls must produce their exact assertion failures.
This fixture is separate from full production disk round trips and the actual
Windows supervisor recovery cycle. It does not use real account sessions.
