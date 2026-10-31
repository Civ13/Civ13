# Bot-mediated native Nomads consumer

This held source prototype defines the receiving half of
`civilizationbot.native-supervisor.v2`. It reuses the existing
authenticated save/shutdown, snapshot validation, process ownership and startup
readiness code. It does not install a task, activate a profile, compile or update
a game, remove a halt latch, create credentials, or contact remote production.

The older Civilizationbot adapter at `d26f12aa09f0081c85392c3d5f68009bfd73f70a`
speaks v1 and is **not compatible**. The paired v2 producer
`6e6e92fa41cb28fabae3581f788ea0c119660fa0` supports the explicit canonical
binding and remains a draft for review. Live bot control fails closed until
authorized spool writers can be verified.

## Preparing a reviewable installation

Use the same explicit portable profile for the bot and consumer. The example
`scripts/nomads-lifecycle/bot-profile.example.json` has no credentials and is
intentionally incomplete. Operator private destinations and a separate bot
environment file remain required; this consumer never reads that environment.

The default `prepared` target must already be beneath the supervisor's `runs`
directory. An explicit `target_type: "canonical"` instead requires the exact
repository as game directory, its `data/desktop-supervisor` root and `config`
directory, loopback TEST1714, and both `canonical_bot_enabled` and
`canonical_update_enabled` explicitly true. The prepared path rule is unchanged.
Both types pin exact master DMB/RSC, map and completed generation; requests never
select a target. Any binding change requires review.

Install these reviewed files together in `<root>/software`:
`supervisor.py`, `master_guard.py`, `bot_consumer.py`, `prepared_backend.py`.
The supervisor config must include `bot_control_files`, mapping exactly those
four filenames to reviewed SHA-256 values. It must also specify `root`,
`repository`, `branch: "master"`, `map`, `bind: "127.0.0.1"`, `port: 1714`,
`daemon`, `git`, private `config_directory`, and
`bot_control_protocol: "civilizationbot.native-supervisor.v2"` for the proposed
contract, after the producer and complete ownership design are reviewed.
The portable profile additionally pins that config, supervisor entry point,
guard, daemon and DMB/RSC. The module manifest prevents an unpinned imported
consumer/backend from weakening the pinned entry point.
The canonical target additionally pins `canonical_update.py` in the manifest and
uses the canonical preservation backend, never the prepared-run backend.

Use a verified Python executable with `psutil` available for the live Windows
process adapter. It uses documented executable, working-directory and TCP
connection inspection, bracketed by native creation-FILETIME checks. Missing
dependency, access failure, conflicting owner or public listener fails closed;
there is no admin/elevation, alternate inspection route or implicit installer.
The synthetic tests do not establish that Windows exposes a complete listener
table or prove race-free attribution under the intended account. Those platform
properties need independent review and authorized evidence before activation.
See the [psutil process API](https://psutil.io/api-reference.html).
Pure tests inject these effects and do not require psutil or a game installation.

Create the private `bot-control` directory as part of reviewed deployment.
Its cooperating consumer and bot use the shared short `adapter.lock`; all game
operations additionally use the existing `supervisor.lock`, also used by normal
manual/scheduled updates. The lifetime `bot-consumer.lock` prevents duplicate
consumers. This change creates no schedule or service and grants no new access.

## Read-only check and eventual explicit activation

With exact paths, the metadata-only check is:

```powershell
& $VerifiedPython -B '<root>/software/supervisor.py' --config '<root>/supervisor.json' --bot-profile '<private>/profile.json' --bot-check
```

It verifies nonsecret local paths, source/config/build pins and profile binding;
it reports platform/dependency availability. It does not read a token, inspect a
process, fetch Git, contact a world or write a spool request. It is not native
readiness evidence. The command without `--bot-check` currently fails closed
before constructing an owner or publishing capability: the source has no
verified authorization check for spool writers. It is not an activation path.

At startup the consumer refuses HALTED, surviving pending/request/inflight
records, or an unresolved consumer failure. It advertises only after verifying
the guarded master and actual world ownership/readiness or a conflict-free
stopped state. Heartbeats update locally; canonical origin is fetched again
before every requested mutation and before starting a replacement. Idle polling
does not repeatedly fetch or advance source. Dirty, diverged, stale or offline
master prevents a launch; neither branch switching nor destructive sync occurs.
First canonical start additionally requires explicit
`canonical_initial_start_enabled` and a matching `canonical_initial_generation`.
The existing save and intent are validated and snapshotted, and the binary pair
archived before launch; no absent save becomes a fresh round. After saved-stop,
the new binding must match its retained journal. There is no automatic live repin
of an owner holding a running child.

## Fixed operation and recovery behavior

Only `start`, `save-stop` and `restart` are accepted. The protocol matches exact
binding hash, epoch, sequence, nonce and observed before-process record.
The v2 packet additionally requires integer `issued_unix` and `expires_unix`;
the maximum age and lifetime are five minutes, with at most two seconds of future
clock skew. Expiration is checked both before acceptance and immediately before
the first native effect. It does not interrupt an already admitted save/restart.
Expiry after acceptance leaves the journal and failure latch for
reconciliation. V1 packets are rejected, never assigned an invented timestamp.
Producers must emit and preserve those exact fields in pending/request records;
receipts echo them. The producer's response timeout is not cancellation.
Publication is serialized with the bot. An exclusive inflight journal and nonce
receipt precede any native effect; the consumer consumes the request once,
then releases the adapter transition lock before saving/loading.

The consumer rechecks the native owner under `supervisor.lock`. It never chooses
an executable, map, revision, save path or PID from Discord input. A prepared
start uses the existing supervisor's fixed argv with explicit `-ip 127.0.0.1`.
Application readiness, generation/import completion and creation identity must
agree. A listening port alone is insufficient. No command shell or kill route
exists in the consumer.

Save-stop uses the existing one-use authenticated process session/operation API,
then waits for the owned process to exit and validates its completed save and
intent before snapshotting. Failure preserves the process and evidence; no
forced termination, automatic fresh round or rollback occurs. Restart verifies
the copied save receipt against the fixed prepared run, rechecks master, starts
that same binary/cwd, and verifies restored generation and readiness. The
canonical target uses its own journaled backup/archive/restore transaction:
v2 restart never updates master, builds or replaces the pinned binaries. A
separate canonical update revokes the old capability before any update; queued
bot records prevent admission and remain intact. Generation or build changes
require explicit reconciliation and repinning; stopping a live owner merely to
repin would lose its handle.

Completed results are synced to a unique temporary file and exclusively
published by hard link. The final filename never exposes partial JSON and never
overwrites evidence. State/generation transition is recorded before completion.
The consumer does not clear the bot's pending file; the bot validates and
acknowledges its own exact pending record. Both sides block reuse of an older
generation until an operator reviews and updates the binding.

On failed, interrupted or uncertain work the consumer latches its own private
blocked state, retains pending/inflight/nonce evidence, and never replays it on
restart. It does not clear the installation's HALTED or save locks. Reconciliation
is an explicit reviewed operator action. File sync/atomic publication establish
process-interruption behavior; physical power-loss durability and real native
save/restart acceptance remain separate evidence requirements.

## Verification

`tests/nomads_lifecycle` includes pure transport/backend controls, Gaia versus
Europe intent validation, fixed prepared-start argv/readiness, atomically
published results, lock contention, unknown outcomes and generation transitions.
The cross-language fixture uses the proposed v2 PHP adapter and checks a normal
round trip and expired-packet refusal with temporary files and injected effects.
Canonical pairing additionally requires `CIV13_BOT_CANONICAL_ADAPTER=1` and the
matching producer; explicit selection fails if adapter inputs are absent.
It verifies hashes/path serialization, locking, request consumption and
completion parsing without a daemon, bot bootstrap, credentials or network.

The proposed `native-consumer.yml` CI pins the exact draft v2 bot source at
`6e6e92fa41cb28fabae3581f788ea0c119660fa0` and requires canonical coverage.
CI does not run BYOND, start a
consumer service, compile/install a game or activate any live profile.
