# Canonical save/load updates

This explicit, default-off path keeps one named `master` hosting checkout and
one DMB at `D:/GitHub/Civ13/civ13.dmb`. It updates only between the completed
save/exit and next world load. Source preparation and offline tests do not
authorize deployment, player interruption, a native compiler or a real cycle.
There is no recurring updater, scheduled task or automatic retry in this path.

`canonical_update.py check --config ABSOLUTE_CONFIG` inspects metadata only:
it does not load a token, query a process, fetch Git, compile or launch anything.
The separate `update-once` action requires `canonical_update_enabled: true` in
a reviewed private configuration. The example remains disabled and contains
unavailable toolchain placeholders. Existing native ownership/admission must
cover the compiler's bounded work/cleanup and the independent save/startup
windows; a source merge does not supply that admission. Install pinned helpers
in durable ignored software storage, not a tracked path the update replaces.
Do not reuse a consumed native grant or treat this command as an allocation.

The operator must first satisfy any prerequisite on the requested real cycle,
notify affected players and establish the exact owned process. Connected clients
defer this updater. An unexpected exit, PID reuse, another native process
(including an unreviewed idle GUI), foreign listener or incomplete prior update
requires reconciliation; the updater never kills or adopts those processes.

## Transaction order

1. Under the existing `supervisor.lock`, verify the exact ready canonical world,
   map, process/session and local named branch. Local Git inspection uses
   `--no-optional-locks` and does not fetch. Refuse detached/PR/ahead source,
   unrelated dirty/staged/untracked files and hidden index flags. If configured,
   only the exact SHA-256 of an approved **unstaged** `config/host.txt` override
   is accepted; do not stage it, use index hiding or publish the private roster.
2. Submit the existing exact-session `save_shutdown` once. Require the matching
   operation, durable same-map round-v2 generation/intent and verified owned
   process exit. Preserve the existing independent 1800-second save window.
   Neither a completion marker alone nor disappearance of a listener is enough.
3. Validate and hash the save backup. Persist the stopped identity and recovery
   journal. Recheck exit/port, backup identity and configuration at every source
   mutation gate. Archive previous DMB/RSC with verified hashes; keep one raw
   canonical output pair, not another game installation.
4. Fetch expected origin, verify its default branch and fetched/advertised exact
   agreement, then fast-forward named `master` only. No reset, forced checkout,
   stash drop or clean. A conflict with the approved local host remains a
   conflict: retain it and stop rather than overwriting configuration.
5. Select the configured Gaia/Europe DMM in the canonical DME, generate the atlas,
   freeze tracked input hashes and compile in place with the pinned compiler.
   Require zero errors/warnings, nonempty DMB/RSC and unchanged frozen inputs.
   Restore only exact expected derived DME/atlas bytes, preserving originals
   in the transaction recovery metadata. Unexpected concurrent edits are kept
   for inspection. Compiler failure leaves the world stopped and backup intact.
6. Reverify current advertised master after compilation; advancement/offline
   failure prevents load instead of chasing updates or loading stale code.
   Preserve local configuration and the exact working/backup saved generation.
   Update the lifecycle revision while stopped, then use existing
   `launch_prepared` and the **real shared** `publish_ready` path at the same
   canonical directory. Require intended generation imported, intent consumed,
   exact revision/map/session/process, saved dimensions, zero runtime errors and
   an advancing heartbeat **before** publishing `ready` or `cycle_complete`.
   Continuity failure retains the owned process in `starting` with `HALTED.json`;
   it never publishes a successful cycle. Save/load format
   compatibility and native gameplay continuity remain actual-cycle acceptance.

`update-state.json` and `updates/<operation>.json` record recovery phases.
The backup receipt is fully hashed after save and immediately before load;
intermediate gates check its immutable identity and payload file stamps rather
than repeatedly reading gigabytes for every small source write. The working save
is rehashed against the backup before import. Tokens and session challenges are
not logged in update journals. Preserve these files and `HALTED.json` on failure.
An unfinished update is not replayable by rerunning the command. There is no
automatic old-build rollback, empty-world fallback, forced save/kill or startup
retry; recover through the existing owner with the retained generation/artifacts.

## Other entrypoints and verification

The legacy `Supervisor.cycle` and builder reject configurations with
`canonical_game_directory`; their separate Europe builds/runs are not this path.
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
