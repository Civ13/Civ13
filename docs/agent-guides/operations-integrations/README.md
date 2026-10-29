# Operations integrations: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- 2026-10-25: shared hub community links -->
`code/world.dm` owns the shared Nomads/TDM hub renderer. Reuse DISCORDURL and
WEBSITEURL; keep literal metadata escaped and configured links HTTP(S)-only.
The `hub_status` CI baseline suite tests source-derived HTML offline, not native
DM execution or public hub rendering. Installing new procedures requires a
rebuilt world and separately authorized restart; source approval does not activate it.

<!-- 2026-10-20: passive production hang triage -->
`scripts/hang-watchdog` observes Linux process identity and status-file metadata
with monotonic deadlines. Its dedicated output is bounded and sanitized; it never
starts/stops/restarts a game, saves/imports, elevates, or attaches a debugger.
`tests/hang_watchdog` uses offline proc fixtures only. Keep the ordinary desktop
test installation on approved master; PR worktrees are not runtime installations.
Manual debugger/tracer examples require separate approval and confirmed detach;
an i386 syscall 0 is restart_syscall, not the host's 64-bit read syscall.
<!-- 2026-10-20: reviewed video upload boundary -->
<!-- 2026-10-20: deferred control-read capability -->
Deferred upload controls use a dedicated Variables/Environments/Metadata-read App,
installed only for Civ13/Civ13, through eight named variable GETs. Its ephemeral
token never substitutes for queue/actions GITHUB_TOKEN. Pinned create-github-app-token
v3.3.0 lacks permission-variables; omit all permission inputs only while that
installation retains exactly the three approved read permissions. Keep post-job
revocation and feature OFF until separately approved storage/activation. Create
and read back master-only youtube-controls before placing its key; a missing
workflow environment otherwise auto-creates without branch protections.
`docs/youtube-upload.md` defines the manual/default-off public YouTube uploader contract after explicit owner approval.
Only trusted default-branch code receives environment credentials; PR media stays
data, with decoder inspection in a secret-free job. Per-clip human approval binds
media/metadata/destination; durable reservations block ambiguous retries. Never
delete uncertain one-off receipts or create OAuth grants from source-PR approval.
The user-run `tools/youtube/authorize.py` checks only project
`calcium-circuit-384407`, uses manual Google PKCE consent and a separate stdin
secret-placement confirmation. Setup requires explicitly disabled repository
activation variables; uncertain secret writes require owner reconciliation even
when immediate metadata reads show absence. Tests use fake services/local loopback.
The owner selected sole required reviewer `valzargaming` (User ID `7202504`),
with self-review allowed and administrator bypass disabled. Keep explicit manual
environment approval; setup approval does not activate uploads or merge this PR. The exact PR3031 historical pilot has a pinned owner-approved material digest; original CI is never relabeled as its packager. Public uploads retain notifications off and cannot change old videos. Keep historical import parsing credential-free.

## Server deployment

- Linux-only for production (scripts use `sudo`, apt, systemd-style paths).
- `scripts/launch.py` - pulls from git, rebuilds, copies config, runs `DreamDaemon`.
- `scripts/paths.txt` defines server paths and ports.
- Config in `config/config.txt` controls gamemodes, ports, hub visibility, logging, etc.
- Discord integration via Civilizationbot (file-based IPC through `SQL/discord2*.txt` files).

## Local MCP tooling

<!-- 2026-10-23: private variable observability -->
Before asking an operator to manipulate native BYOND variables, inspect the
implemented structured paths in `docs/variable-observability.md`. Run
`scripts/nomads-lifecycle/agent_debug.py discover` offline first. For an already
authorized installed runtime, `agent_debug.py recovery --root <private-root>
--revision <installed-40-hex>` returns `data.variable_identity`; use its exact
session/round with `variable_observability.py --root <private-root> --revision
<installed-40-hex> --session <observed-32-hex> --round-id <observed-round>`.
Use a verified full Python executable. Each runtime command makes one existing
authenticated loopback status read with a 15-second/32-KiB limit and no retry.
The schema-1 status field is `debug.variables`; reader evidence is
`data.failure`, with active/last save/load ownership alongside it. There is no
generic runtime variable MCP tool or arbitrary ref lookup.
Check `data.failure_error`: stale, mismatched, partial or malformed retained
failure evidence is withheld without hiding independently valid current/last
operation ownership. `ok:true` is not acceptance of a rejected retained capture.
Null scalar throw fields mean unknown and remain distinct from numeric zero;
the reader does not invent a never-thrown default.

Collection/exposure and automatic local output remain default-off until a
separately authorized exact-build deployment/restart and local opt-in using
`config/variable-observability.txt` containing `enabled`, existing lifecycle
credentials/revision, and a separately provisioned operator-private runtime
`data/desktop-supervisor/variable-observability/` directory. Do not
activate them from source/PR approval or claim this tooling is already live.
The automatic path is runtime-relative
`data/desktop-supervisor/variable-observability/last-failure.json`; publication
must fail harmlessly if that fixed directory is missing or unwritable, with no
legacy-path fallback or automatic ACL/directory creation. Explicit old-file
reads remain supported. The reader's `--input <file>`
mode is offline and requires independently obtained expected revision/session/
round. Keep raw captures private. Unknown fields are stripped, but refs/types/
coordinates remain operational data requiring review before public sharing.

For an `original_target` save rejection, inspect source type/field/entry,
source/target physical turf z, fixed throw links, throwing flag, thrown-list
prefix membership, destruction flags and operation ID/stage together. A
truncated registry miss is unknown. `rejected_by_persistence_guard` describes
the rejection, while saturated runtime skip-decision counts observe the existing
`persistence_runtime_var` policy; neither authorizes nulling links or proves live
cleanup. The separate persistence fix owns that policy. Preserve guard failures.

Default reads expire after 60 UTC seconds and must match build, boot,
round and, for status failures, current/last operation plus tick bounds and a
realtime reversal check.
UTC uses the finer `world.timeofday` input with explicit UTC formatting and a
midnight rollover rejection. Epoch `world.realtime` is coarse metadata; only
reversal is checked there, while UTC and ticks enforce bounded age. Never relax
future-time rejection to hide epoch floating-point rounding.
Re-reading retained evidence does not refresh it. Explicit `--historical` is
allowed only with offline `--input` and
labels evidence `historical_only`; it cannot refresh or query live identities.
Native refs and pooled objects can be reused;
`capture_only`/`generation: unavailable` must never be treated as
durable or current identity, even when type/location match. Depth is eight,
owner frames eight, registry prefixes 256, output 32 KiB; missing, partial and
stale data are explicit unknown/error states. No eval, generic proc invocation,
mutation, credentials, relaxed protections or listener is introduced.
Offline synthetic reader/source checks and native-packet preparation are covered.
The `df639b1` tiny native attempt emitted 22 successful checks but failed overall
reader/ownership acceptance and logged a startup loopback bind; preserve that
failed verdict. The source UTC correction is not native-verified. Topic and full
save/load/gameplay acceptance remain unverified. Compilation CI is separate
evidence bound to its tested head. Observation
does not authorize save/load, restart, cleanup or other live mutation.

<!-- 2026-10-17: bounded own-host agent diagnostics -->
`docs/agent-debug-tools.md` documents schema-1 recovery/vision/3x3 tile reads on
the existing loopback/token/R_HOST lifecycle transport. Pair/trace/bundle are
offline and allowlist public summaries; raw query files remain private. Trace
is bounded cached observations, not an engine event log or rendering evidence.
The DM collector/status extension requires a rebuilt world restart.

<!-- 2026-10-15: archived combat histories -->
Combat history writers use `append_attack_log`; ghosts share the body's list.
Keep the mob history declared as `var/list` for native list method resolution.
Retire rows in place only after the private archive write succeeds. Archive
failure deliberately retains history, with scalar retry/warning cooldowns.
`tests/attack_history` checks writer coverage and isolated production contracts;
its row counts do not establish live process RAM or crash durability.

<!-- 2026-10-14: bounded runtime detail history -->
Error history keeps 1000 recent entries globally and 100 per file/line source,
including skip summaries. Retirement removes both memberships and clears entry
backreferences, captured usr locations and detail text before explicit plain-datum
deletion invalidates old holders. Source metadata and
world/Error cooldown dictionaries remain for the round; distinct synthetic
file/line identities are not bounded. `tests/error_history/run.py` checks real
logging, viewer bodies and retirement in an isolated native world, with an
immutable historical log_error control. `--prepare-only` runs no native tools.

<!-- 2026-10-11: Civ13 MCP integration -->
`tools/mcp/README.md` documents the bounded stdio server and Codex configuration.
Run `npm ci --prefix tools/mcp` then `npm test --prefix tools/mcp` for isolated
protocol/path/cancellation tests. Set `CIV13_DM_COMPILER` to a trusted absolute
DreamMaker path to additionally check its banner and a fixed temporary fixture.
Source discovery is lexical; include diagnostics do not replace compilation.
Both compiler tools create temporary storage/processes. No live game, Topic or
production administration tools are exposed. Never configure this server from a
worktree that will be archived while the MCP entry still points to it.


<!-- 2026-10-11: GitHub comment review -->
Tools under tools/comment-review provide an authenticated-gh local collector and a disabled-by-default Codex event workflow. Preserve ignored data/comment-review cursors/receipts across worktree cleanup; inspect current API data before acknowledging or posting. The local collector does not install a scheduler or consume API credentials. See tools/comment-review/README.md for event trust boundaries and activation settings.
<!-- 2026-10-11: dormant trigger approval boundary -->
Dormant comment-review listeners must be workflow_dispatch-only: GitHub can request approval before evaluating job guards. Keep automatic subscriptions in tools/comment-review/active-events.example.json until a separately reviewed activation.

<!-- 2026-10-15: player-facing changelog review -->
Meaningful player-facing PRs must include exactly one reviewed `changelog: text`
line in their opening description before being marked ready or merged, outside
comments, quotes and fenced code. Use concise player-facing text compatible with
tools/changelog/README.md so the existing GitHub Action can announce it to Discord.
Use one announcement route per change; do not also add a manifest for that change.
This requirement does not authorize manual posts, publisher settings changes,
deployment or claims that the change is running on a server.

<!-- 2026-10-11: shipped Discord changelog -->
The standalone publisher in tools/changelog supports an explicit `Changelog: text`
line in a PR opening description on merge into master. Missing or blank means no
post. Use player-facing bullets only, without headings or deployment/update-status
wording. The older manifest route still requires live confirmation or a trusted
successful production deployment event. A merge/CI pass is not shipment.
Preserve the discord-changelog-receipts branch; pending receipts
block uncertain replay. See tools/changelog/README.md before activation.

<!-- 2026-10-11: hosted API reference -->
Source docs publish from master via api-pages.yml to https://civ13.github.io/Civ13/.
The generator validates emitted links and search anchors; search covers documented output only.

<!-- 2026-10-12: OpenDream local controls -->
`scripts/opendream/control.py` owns only its launched local server. OpenDream
restart/map votes enqueue fixed requests with a ready marker; do not use shell
or native PID discovery. Reused temporary resources can make OpenDream `fcopy`
copy stale bytes. Write the final spool file before its marker and verify actual
disk bytes independently of DM resource reads. `verify-dm-controls.py` exercises
production request/reboot/whitelist bodies in a disposable OpenDream world.

<!-- 2026-10-19: bot helper contention -->
Bot control uses nonblocking flock and returns busy (75) without systemctl or
cooldown writes under contention. The draft unit remains disabled pending
independent game supervision and native bot-restart/game-survival acceptance.

<!-- 2026-10-11: cancellable voting -->
Votes expose terminal vote handles with generation-bound ballots and immutable
deadlines. Retain and cancel handles when a caller's lifetime ends; completion
callbacks run after detachment and may start another vote. See docs/voting.md
and tests/extraction/vote_probe.dm; adapters isolate restart/deployment effects.
