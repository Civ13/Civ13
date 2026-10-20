# Passive Linux hang detection and operator triage

`watchdog.py` is an independent Python 3.10+ process. It observes an explicitly
identified native Nomads process and the existing `serverdata.txt` producer. It
does not supervise, launch, update, stop, signal, save, import or restart the game.
It makes no game/HTTP/TCP requests and starts no subprocesses. It never attaches
GDB/strace, reads process memory, collects core dumps, or elevates itself.

This is separate from the Windows TEST1714 lifecycle supervisor and help worker.
It does not install or change either of them. The ordinary desktop test server
must remain on its approved master installation; never point it at this PR.

## Detection contract

The game currently rewrites `serverdata.txt` about every ten seconds. The observer
reads only file metadata: device, inode, nanosecond mtime and size. It never reads
the player/server-status contents. After an initial grace period, no change for
120 seconds by default is `heartbeat_stale`. Elapsed time and cooldowns use
`time.monotonic()`, not wall time or `now - mtime`. An old/future mtime at observer
startup cannot immediately establish a hang; initial presence is unconfirmed.
Two different observed versions establish `healthy`. Missing, unreadable and
invalid heartbeat files are separate outcomes, not proof of a hung game.

Wall time is used only for UTC evidence labels. A wall-clock adjustment that
changes file mtime can look like one producer update, delaying detection once;
it cannot indefinitely extend the monotonic deadline without further changes.
A backwards monotonic sample rearms grace without duplicating a captured episode.
After observer restart, grace starts again. Same-boot cooldowns survive restart;
if boot identity is unavailable/changed, a previously used cooldown starts anew.

Every sample checks PID, Linux `/proc/PID/stat` start ticks, and the exact command
prefix `DAEMON GAME_ROOT civ13.dmb PORT`. A missing/recycled/different process is
reported separately and never adopted. Configure a newly approved identity after
an operator restart. This observer deliberately does not discover or own unknown
processes. PID/start ticks bind to the current boot; review identity after reboot.

The listener observation comes from bounded local `/proc/net/tcp{,6}` reads.
It includes queued unaccepted connections and, when permissions allow, verifies
socket inode ownership through the target's file descriptors. Unknown ownership
and incomplete tables remain explicit. The kernel table does not expose the
configured maximum backlog; that field is null. No peer addresses are retained.
An open listener is not game readiness, successful protocol login or remote
reachability. A stale heartbeat with an open listener is still an incident.
Progressing heartbeat with a definitely absent listener is `listener_missing`;
unavailable listener evidence is `listener_unknown`. `heartbeat_state` keeps
these observations separate. Even a `healthy` observation does not verify login.

This file-based check assumes the game is the sole writer of its status file.
Another writer can mask a hang. Long startup/save work, intentional suspension,
storage failures and filesystem timestamps can affect detection. It is a triage
signal, not proof of a deadlock or cause. Choose thresholds using observed startup
and save durations; don't silence an incident by touching the heartbeat.

## Configuration and proposed deployment

There is no automatic installation. Deployment/service creation requires the
operator's authorization, an identified runtime owner, and a durable reviewed
copy of this script. Do not run a deployment/updater script as a restart shortcut.

1. Copy `config.example.json` to a private operator location and replace every
   example path/PID/start-tick value with a freshly verified existing process.
   Match its game directory and port, not an obsolete updater template. Start
   ticks are field 22 of `/proc/PID/stat`; the process name in parentheses can
   contain spaces, so do not extract this with a naive whitespace field number.
   This observer's `proc_stat()` shows the bounded parse used by the tests.
2. Set `expected_revision` only from an operator-reviewed source receipt. It and
   `expected_byond` are claims, not verification of the loaded executable. Bundle
   hashes identify the current on-disk DMB/RSC only; files can differ from the
   running image. `config/lifecycle-revision.txt`, if present, is also labelled a
   claim. No Git command or executable version probe is run.
3. Choose a new dedicated output directory outside both the live game directory
   and source checkout. On Linux it must be private (mode 0700); new files are
   created mode 0600. An existing nonempty unmarked directory, symlink, special
   file, mismatched state or lock refuses startup. No security setting is changed.
4. Start under the existing unprivileged server/monitor account, with a verified
   interpreter. Denied process reads produce partial evidence; they never cause
   a sudo prompt, retry with privilege, or security-policy changes.

```sh
/usr/bin/python3 -B /opt/civ13-watchdog/watchdog.py --config /etc/civ13-watchdog.json
```

`--once` writes a single observation and exits; it cannot establish heartbeat
progress/staleness by itself. Output/state errors stop with exit status 2 and a
generic stderr message, not private exception text. Observe that exit externally;
a stopped observer cannot detect a game hang. No watchdog self-restart or game
restart is configured by this change. On approved systemd deployment use a separate
unprivileged unit, no game dependency/restart hook, read-only game paths and write
access only to this output directory. Run with no capabilities/NoNewPrivileges;
do not grant ptrace, broaden sudoers, or alter a production service to enable it.

## Evidence, privacy and retention

`watchdog-status.json` is an atomically replaced latest observation, including
UTC/monotonic timestamps, health, identity, heartbeat metadata and listener status.
Only state transitions and new bundle names are printed to stdout. Route these
to the installation's existing bounded local journal/alert intake if desired;
this tool does not send notifications or create an external integration.

One `incident-NNNN.json` bundle is collected per continuous failure episode.
Heartbeat recovery closes the episode; a later failure can collect another bundle
after the configured monotonic cooldown. A permission/process failure becoming a
stale heartbeat without recovery remains the same episode. Dedup state is retained
across observer restarts. Collection admission is durably reserved before reading
diagnostics; interrupted/failed collection is not silently repeated. Reconcile
that status/state and preserve existing evidence before an operator-authorized
retry. There is no automatic stale-lock removal or reset command.

Bundles contain at most 32 thread states/CPU counters/wchan symbols, numeric
process memory/context-switch counters, local memory/filesystem totals, bounded
artifact hashes, source/build claims, and save/backup file metadata (up to 32 level
names). No save or restart-intent contents are opened. The status-file body,
process command line, environment, history, credentials, player/chat/admin logs,
network payloads, memory and kernel/userspace stacks are never stored.

For `civ13.log` and at most two timestamp-named runtime logs, at most 16 KiB of
tail bytes per file are classified against fixed patterns (open, shutdown, bad
reference/sequence warnings, null damage runtime, save/import failure, recovery
hold). Only classification counts, file sizes and mtimes survive; raw lines,
unrecognized messages, arguments, paths and player text are withheld. A log tail
or file mtime cannot identify the exact incident time or establish causation.
Directory scans stop at 256 entries; partial/unavailable evidence is explicit.

Default storage caps are eight bundles, 64 KiB per bundle and 1 MiB total regular
file bytes, including state/status/lock/marker and atomic-write headroom. Old exact
`incident-` names are pruned oldest first within this dedicated output directory.
Unknown files are preserved and counted against the byte quota; an impossible
quota stops collection without deleting existing evidence. No game/save directory
is pruned. A single locked observer is required. The caps limit bytes/entries, not
an absolute filesystem I/O deadline; an underlying blocked disk can block this
observer too. Hashing reads at most 128 MiB per DMB/RSC and verifies stable size/
mtime; hashes are unavailable for larger/changing artifacts. Keep the observer
output on healthy local storage with enough real disk space; do not run as root.

## Operator incident runbook (manual, opt-in)

1. Preserve the bundle and its UTC/monotonic labels. Verify the real current PID,
   start identity, exact game directory/build and listener before any operation.
   Keep shared screenshot/terminal leases and existing SSH tunnels untouched.
2. Check the latest heartbeat after a short interval, listener ownership/queue,
   and bounded application/system logs around the last progress time. No journal
   entries are not proof that no OOM/clock/crash event occurred. Missing access
   stays unknown; stop denied reads rather than weaken host policy.
3. Review completed save receipts and metadata without altering them. A forced
   stop discards the in-memory world; the last completed save can be many hours
   old. Preserve both save/backup generations. Current RP configuration and an
   absent restart intent do not establish automatic restoration. Import always
   needs the matching map/build and generation validation; this observer does
   not validate world contents or select/restore a save.
4. If passive evidence is insufficient, obtain separate explicit approval before
   each GDB or strace attachment. Use the existing isolated SSH terminal; the
   human enters any sudo password directly at its hidden native prompt. Never
   collect passwords in chat, arguments, environment, files, screenshots or logs.
   Do not run a root shell. Below are reviewed command forms, not automatic code.
   Refresh `VERIFIED_PID` immediately before use and compare exact argv/start
   identity. If access is denied, stop with no bypass or repeated attach.

For a separately approved bounded native backtrace (GDB 15.1-compatible):

```sh
sudo -- /usr/bin/gdb -nx -q -batch -iex 'set auto-load off' -iex 'set debuginfod enabled off' -iex 'set print frame-arguments none' -iex 'set print entry-values no' -iex 'set print frame-info location' -ex 'attach VERIFIED_PID' -ex 'thread apply all bt -no-filters -frame-arguments none -entry-values no 40' -ex 'detach'
```

Attach pauses the process, may disturb timing, and can take longer than expected.
No locals/arguments, memory dump, automatic scripts, network symbol downloads,
breakpoints, stepping or function calls are requested. Confirm explicit detach
before proceeding. Missing native symbols may prevent causal identification.

A separately approved roughly ten-second main-thread wait trace can use:

```sh
sudo -- /usr/bin/timeout --foreground --signal=INT 10s /usr/bin/strace -tt -T -e trace=futex,futex_time64,restart_syscall -e signal=none -p VERIFIED_PID
```

No `-f` or payload syscalls: INT targets the tracer for detach, not the existing
game. Confirm detach; timeout exit 124 is expected. Attach can interrupt a syscall
and change behavior, so it is not a passive check. Empty output does not prove no
activity, deadlock, or bad timeout: an already-blocked/other excluded syscall may
remain silent. A manual read of `/proc/VERIFIED_PID/syscall` can show the current
syscall number/registers without dereferencing memory. Decode the correct ABI:
on i386 syscall 0 is `restart_syscall`, not 64-bit `read`. Registers alone do not
reveal the underlying resumed wait's timeout or the original trigger. Never keep
reattaching simply because the evidence is inconclusive.

Any recovery/restart/save/import/deployment, external report or private evidence
upload requires its own authorized scope. This change enables none of them.

## Offline verification and acceptance boundary

```text
<verified-python> -B -m unittest discover -s tests/hang_watchdog -v
```

Tests use fake Linux proc files and temporary game/output directories: healthy,
stale/missing/unreadable heartbeat; open listener with stale game; identity reuse;
wall/monotonic changes; observer restart dedup; cooldown/recovery; denied evidence;
privacy canaries; no signals/subprocesses; unchanged game/save bytes; singleton
locks, symlink/special-file refusal and disk/entry/output caps. The CI step runs
for introduced tests or existing extensive-regression opt-in. These tests do not
establish live Linux proc permissions, service installation, production alert
delivery, native hang causation or the validity of a save. Those remain explicit
operator acceptance steps in a separately authorized environment.
