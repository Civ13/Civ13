# Canonical save/load updates

This explicit, default-off path keeps one named `master` hosting checkout and
one running DMB at `D:/GitHub/Civ13/civ13.dmb`. It updates only between the completed
save/exit and next world load. A separate, never-launched staging checkout validates
the candidate binary before replacing that pair. Source preparation and offline tests do not
authorize deployment, player interruption, a native compiler or a real cycle.
There is no scheduled task or automatic retry in this path.

The separately started `watch-admin` mode polls only the existing authenticated
loopback lifecycle status for a typed in-game maintenance request. It uses the
same updater and `supervisor.lock`, not a second server owner. It is not installed
or enabled by this source change. It requires the existing reviewed canonical
configuration and `canonical_update_enabled: true`; keep the private configuration
and operational state on D:. Do not run this mode until the source and native
admission have been reviewed. If it is not running, the game expires an
unaccepted request after five minutes and tells admins. The game issues a
one-minute warning before making the request visible to the supervisor. An
`R_SERVER` admin must confirm it, including the warning that gameplay during
serialization may not be preserved. This explicit request permits connected
clients; ordinary `update-once` retains the existing connected-client deferral.

The game supplies only an operation identity bound to its current session; it
does not supply a command, path, branch or revision. The watcher records an
exclusive per-operation receipt before submitting the save, then rechecks the
session and request at the save boundary. The supervisor submits the distinct
`maintenance_save_shutdown` action; the game atomically verifies that the same
request is still pending after its warning and reserves it before yielding. An
expired request can never fall through to the ordinary `save_shutdown` action.
An existing receipt prevents replay,
including after a crash or an ambiguous response. Failures are recorded in the
receipt and, if the original world is still reachable, a fixed failure signal
notifies admins. An interrupted watcher requires operator inspection; it never
automatically retries an accepted identity. A completed receipt is written only
after the updater's mode-specific restore or fresh-start and readiness checks succeed.

On compilation failure retain `HALTED.json`, the update journal, the hashed save
backup and the archived previous DMB/RSC. The updated checkout is not reported
as a successful update and no automatic rollback or launch occurs. An operator
must reconcile the journal, binary/source provenance, process ownership and
matching save before a separately authorized recovery using the existing owner;
do not delete the retained generation or launch a fresh world as a substitute.

`canonical_update.py check --config ABSOLUTE_CONFIG` inspects metadata only:
it does not load a token, query a process, fetch Git, compile or launch anything.
`canonical_update.py dry-run --config ABSOLUTE_CONFIG` prints the same offline
plan; it cannot know the running world's persistence mode or prove readiness.
Invoke either with the reviewed absolute Python executable. After a separate
scoped live-cycle authorization and installation of a compatible game build,
the single operator trigger is `REVIEWED_PYTHON canonical_update.py update-once
--config ABSOLUTE_CONFIG`; it retains the ordinary connected-client deferral.
The bounded heartbeat observation defaults to 60 seconds and can be configured
from 1 through 300 seconds using `continuity_timeout_seconds`.
The separate `update-once` action requires `canonical_update_enabled: true` in
a reviewed private configuration. The example remains disabled and contains
unavailable toolchain placeholders. Existing native ownership/admission must
cover the compiler's bounded work/cleanup and the independent save/startup
windows; a source merge does not supply that admission. Install pinned helpers
in durable ignored software storage, not a tracked path the update replaces.
Do not reuse a consumed native grant or treat this command as an allocation.

Before an authorized cycle, review `save_timeout_seconds` and
`startup_timeout_seconds` against measured save and load times with sufficient
margin. Both supervisor defaults are 1800 seconds, shorter than the approximately
40-minute save and 43-minute load reported in issue #3411. The actual private
configuration and current timings must be verified; neither is established here.
A save timeout can leave the owned world running and later exiting without the
updater completing its backup. A startup timeout can leave the owned process in
`starting` with the update halted. Preserve the process and transaction evidence
for owner reconciliation; do not automatically kill, retry or start a fresh world.

The operator must first satisfy any prerequisite on the requested real cycle,
notify affected players and establish the exact owned process. Connected clients
defer this updater. An unexpected exit, PID reuse, another native process
(including an unreviewed idle GUI), foreign listener or incomplete prior update
requires reconciliation; the updater never kills or adopts those processes.

## Transaction order

1. Under the existing `supervisor.lock`, verify the exact ready canonical world,
   map, process/session, current persistence mode and local named branch. The
   existing authenticated status must report a numeric mode; older worlds that
   lack it are refused before save. The mode is bound to the save request and
   rechecked by the game through the final shutdown boundary. While the bound
   request is reserved, the normal persistence admin toggles and transition votes
   are refused. The game also checks the serialized mode before publishing its
   restart intent. Privileged direct edits are outside this normal-writer guard;
   this is not an atomic snapshot of all gameplay. Local Git inspection uses
   `--no-optional-locks` and does not fetch. Refuse detached/PR/ahead source,
   unrelated dirty/staged/untracked files and hidden index flags. If configured,
   only the exact SHA-256 of an approved **unstaged** `config/host.txt` override
   is accepted; do not stage it, use index hiding or publish the private roster.
2. Submit the existing exact-session `save_shutdown` once. Require the matching
   operation, durable same-map round-v2 generation/intent and verified owned
   process exit. Use the independently reviewed save timeout window.
   Neither a completion marker alone nor disappearance of a listener is enough.
3. Validate and hash the save backup. Persist the stopped identity and recovery
   journal. Recheck exit/port, backup identity and configuration at every source
   mutation gate. Archive previous DMB/RSC with verified hashes; keep one raw
   canonical output pair, not another game installation.
4. Fetch expected origin, verify its default branch and fetched/advertised exact
   agreement, then fast-forward named `master` only. No reset, forced checkout,
   stash drop or clean. A conflict with the approved local host remains a
   conflict: retain it and stop rather than overwriting configuration. Refuse
   upstream changes anywhere under `config/` or to `SQL/admins.txt` before the
   fast-forward; reconcile those changes separately without overwriting local settings.
5. Create a distinct non-running staging checkout at the exact updated revision;
   select its configured Gaia/Europe DMM, and generate its atlas into a retained
   operation-specific file outside the checkout. Verify the selected DME and
   tracked inputs before validating and installing the generated catalog. Freeze
   their hashes and compile with the pinned compiler. Require zero errors/warnings,
   nonempty DMB/RSC and unchanged frozen inputs. The canonical DME, atlas and
   old binary pair remain unchanged if staging or compilation fails.
6. Reverify current advertised master after compilation; advancement/offline
   failure prevents switching instead of chasing updates or loading stale code.
   Copy and hash the staged pair, journal `switching`, revalidate the archived old
   binaries, then replace the canonical pair while the same stopped-owner and
   backup gates still hold. Recheck the archive before each replacement. A partial switch
   halts and leaves the previous archived pair for operator reconciliation.
   If the prior world was nonpersistent, journal and move its complete working
   save directory to a retained operation-specific location, then create an empty
   save directory. Never discard the validated backup. Update the lifecycle
   revision while stopped, then use existing
   `launch_prepared` and the **real shared** `publish_ready` path at the same
   canonical directory. Require exact revision/map/session/process, zero runtime
   errors, the same persistence mode and an advancing heartbeat observed within a
   bounded deadline **before** publishing `ready` or `cycle_complete`. Nonpersistent
   startup requires no imported generation; persistent startup additionally requires
   the exact intended generation, saved dimensions and consumed intent.
   Continuity failure retains the owned process in `starting` with `HALTED.json`;
   it never publishes a successful cycle. Save/load format
   compatibility and native gameplay continuity remain actual-cycle acceptance.

`update-state.json` and `updates/<operation>.json` record recovery phases.
The backup receipt is fully hashed after save and immediately before load;
intermediate gates check its immutable identity and payload file stamps rather
than repeatedly reading gigabytes for every small source write. The working save
is rehashed against the backup before import or isolation. Tokens and session challenges are
not logged in update journals. Preserve these files and `HALTED.json` on failure.
An unfinished update is not replayable by rerunning the command. There is no
automatic old-build rollback, empty-world fallback, forced save/kill or startup
retry; recover through the existing owner with the retained generation/artifacts.

## Other entrypoints and verification

The legacy `Supervisor.cycle` and builder reject configurations with
`canonical_game_directory`; their separate Europe builds/runs are not this path.
Only the canonical updater owns the new per-operation staging checkout; it never
launches that checkout. Staged files, retained saves, archived old binaries, and
incomplete checkpoints are operator recovery evidence and are not cleaned up
automatically.
The master guard's standalone `--update` refuses ungated writes. On repositories
containing `data/desktop-supervisor`, even fresh fetch verification requires the
save/load mutation guard. Use `--inspect-only` for local read-only checks while
running. Noncanonical prepared feature runtimes keep their separate behavior.
For an approved local host override, local inspection additionally accepts
`--approved-host-sha256 REVIEWED_DIGEST`; this is limited to that exact unstaged
file and never permits an ungated update or another local change.

Offline tests use real local Git remotes and synthetic saves, with inert
compiler/process transports. They cover operation ordering, save/exit failures,
dirty/detached/staged source, interrupted transactions, compile failure,
source advancement and changed working saves. Their successful path calls real
canonical readiness publication; they do not establish a real BYOND save/load,
production permissions, CI success for a game build or deployment readiness.
Report exact-head CI and later native receipts separately. No firewall, router,
DNS, Discord credential, ACL or bot activation is part of this updater.
