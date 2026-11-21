# Launcher: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- 2026-11-21: up to 24 regions and missing Earth regions -->
Launcher 1.5.34: every list of regions reads up to `LocalHosting.MaxRegions` (32, the same as shard_group.py MAX_REGIONS
and shard_group.dm SHARD_MAX_REGIONS) instead of 16, and Ports and front door gains "Add missing Earth regions"
(`shard_group.py add-regions`): it plans, confirms, then adds the Earth lands and seas the group lacks
(EARTH_REGIONS: the Mediterranean and the five oceans on the live host) and sets them up stopped.

<!-- 2026-11-21: process safety and the experimental WMI check -->
After WMI broke on 2026-11-19 (tasklist hung, Gaia stayed down), Val approved the criticality plan (2026-11-21).
Launcher 1.5.33: `LocalHosting.RunCaptured` reads both streams asynchronously and enforces a per-step limit
(`WithLimit`; status 30 s, stop/kill/unlock/freeze/thaw/help 2 min, start/restart 10 min for the pager wait,
everything else 30 min), ending the step's tree and throwing `StepTimedOut` (an IOException), so a hung host
script no longer freezes the board. ProcessSafety.cs lists, inspects and ends processes through the kernel
(never tasklist, taskkill or WMI) and only ends a verified target; the bot's Force stop uses it, and
`--bot start` falls back to a direct `CreateProcess` when WMI's `Win32_Process.Create` fails or takes over 20 s.
All regions > More > **Windows process check (experimental)…** (WmiHealth.cs, Gui/WmiHealthDialog.cs) checks
WMI read-only and offers the five repairs, each elevated only on a click; its checkbox (`experimental.json`
`wmi_health_check`, off by default) turns on a 10-minute watch that warns on the board. `Civ13.exe --wmi check`
prints the same check. `tests/gaia_host/test_gaia_host.py` ProcessToolGuardTests fails on new process-tool
calls in host scripts and the launcher (WmiHealth.cs and BotCommand.cs are allowed).

<!-- 2026-11-19: Player records window -->
Val asked (2026-11-19) that admin notes and similar systems be visible on every region. All regions > More >
**Player records…** (Gui/PlayerRecordsDialog.cs, PlayerRecords.cs, launcher 1.5.31) runs `shard_group.py records`
[`--ckey K` | `--search T` | `--export F.json`], a read-only look at the shared player records in
`<group root>/coordinator.sqlite` (tools/transfer_storage/records.py report/export): a summary, one player's records,
a search (key, text or IP), each region's copy of its old notes/bans/memos files and its uncollected journal.
Staff add and remove records in game only. Admin tooling: no changelog line or wiki page.
A player lookup (`--ckey`) starts with that account's lifetime points and character slots
(records.py account_summary, docs/character-slots.md); `shard_group.py accounts --ckey K` answers the
summary alone as JSON (`points`, `spent`, `balance`, `claimed`, `slots`).

<!-- 2026-11-17: Civilizationbot log level -->
Val asked (2026-11-17) for the bot's logger level in the launcher, info by default instead of debug. The
Civilizationbot tab's **Log level** list (Gui/BotPage.cs, launcher 1.5.30) and `Civ13.exe --bot log-level [LEVEL]`
write `log_level` into the bot's portable profile (LocalBot.WriteLogLevel keeps every other field, no BOM, via a
temporary file). The bot reads it at start (Civilizationbot LogLevelSetting); a missing or unknown value is info
and never blocks boot. A running bot is offered a restart.

<!-- 2026-11-17: AI characters window -->
Val asked (2026-11-17) for Ada's controls in the launcher. All regions > More > **AI characters…**
(Gui/AgentRunsDialog.cs, AgentRuns.cs, launcher 1.5.29) runs `shard_group.py agents` (agent_runs.py), which
finds autopilot watchers (`--watch`) and runs (`--character`) by command line and shows each run's latest
needs and log tail, refreshing every 15 s. **Stop run** kills only an autopilot run (its watcher plays the
character again); **Restart watcher** needs the watcher.json that watcher wrote at start and never a raw token.

<!-- 2026-11-16: Player activity window -->
Val asked (2026-11-15) for player metadata: who is active and what they do. All regions > More > **Player
activity…** (Gui/PlayerActivityDialog.cs, PlayerActivity.cs, launcher 1.5.27) runs `shard_group.py activity`,
which reads new lines from every region into `<group root>/player-activity.sqlite` and returns the report text
plus which regions record (`PLAYER_ACTIVITY 1`). Read-only; see docs/player-activity.md.

<!-- 2026-11-15: Magic whitelist dialog -->
Val asked (2026-11-15) that magic and patrons be gated by a whitelist like the old TDM job whitelist. All regions >
More > **Magic whitelist…** (Gui/MagicWhitelistDialog.cs, MagicWhitelist.cs) runs `shard_group.py magic-whitelist
[--add K,..] [--remove K,..]`, which edits the one shared file (gate, else mainland `SQL/magic_whitelist.txt`) that
every world rereads within 30 s (code/modules/divine/magic_whitelist.dm). Staff can also use Admin > Magic Whitelist
in game. Hidden mechanic: no changelog line or wiki page.

<!-- 2026-11-15: Players dialog (Send Player to Region) -->
Val asked (2026-11-15) for tooling instead of hand-run call_proc transfers between regions. The selected
region's More menu has **Players…** (Gui/PlayersDialog.cs, RegionPlayers.cs): `shard_group.py players` and
`send-players` reach the world's loopback lifecycle Topic (`players`, `send_players`, region_admin_send.dm).
A send always shows the dry run first; Send is enabled only for the exact choice a dry run approved, and
only then is `--send` passed. Keep the argv checks in step with shard_group.py CKEY_LIST/SEND_LANDINGS.
See [docs/region-admin-send.md](../../region-admin-send.md).

<!-- 2026-11-09: --bot command line -->
Val asked (2026-11-09) that the bot be manageable through the launcher without its window, so a remote
helper can restart it. `Civ13.exe --bot ACTION` (BotCommand.cs) reuses LocalBot.Control; only start
differs from the window: CIM Win32_Process.Create detaches the supervisor, paths passed through env vars.

<!-- 2026-11-09: Start-menu entry -->
Val asked (2026-11-09) that agents can open the launcher later. The window keeps a per-user Start-menu
entry "Civ13 Launcher" (StartMenuShortcut.cs) pointing at the running Civ13.exe, rewritten only when
missing or pointing elsewhere; temp-folder copies and non-Civ13.exe hosts are skipped. Computer use
resolves apps from the Start menu, so a portable exe without an entry cannot be opened by name.

<!-- 2026-11-07: One region row -->
The Host server tab's One region row passes `--region` to shard_group.py for every group action,
including freeze, thaw, stage and setup (GroupActions). Setup is offered per region only; adopt,
enrol and config-migrate stay off the launcher, and handover runs only through deploy (since
2026-11-08 the One region row also has Save, update and restart: the deploy dialog with only that region ticked, whose ids stay explicit,
Val asked for the handover to be reachable per region; plain Restart's confirmation points to it). RegionDetails
adds the port, DescribeStage (stage and standby), the watchdog record, transfer_agent and region_view;
ParseGroup adds the coordinator. Keep them in step with RegionHost.status and gaia_host status.

<!-- 2026-11-07: Host settings -->
Val asked (2026-11-07) that the Windows host keep its own hosting config through the launcher, so master
(what a Linux host deploys) stays the default and pulls never clobber the host's files. HostSettings.cs
edits only the group config's overlay folders, offers a fixed list (config.local.txt, host.txt, existing
config/*.txt|json minus shard_group.py GENERATED and kept copies), and its rules mirror shard_group.py
merge_config and KEPT_COPY; change both together. Save and apply runs `config-apply` (no compile).

<!-- 2026-11-07: staged builds and handover in the Host tab -->
Since #3906 deploy.bat hands running regions over to the staged build instead of stopping them; the
deploy dialog (DeployQuestion) says so. The Host tab has **Build update** (`shard_group.py stage`, no
kick) and the group status line shows each region's `stage` phase and a `standby` world via
LocalHosting.DescribeStage; keep its wording in step with shard_group.py stage phases.
**Update offline regions** (All regions row, `update-offline`, launcher 1.5.17) stages and installs
every stopped region, stages asleep ones for the host service, and never touches a running region;
ParseGroup reads its `accepted`/`skipped` answer and DescribeStage shows a stage `install` refusal.

<!-- 2026-11-06: Save, update and restart -->
With control.group set, the Updates tab's server row uses `shard_group.py check-update` and its button
runs deploy.bat for the ticked regions (all ticked = whole group), the same as the Host tab button. Val
chose (2026-11-06) that it stages first and saves/stops only once every staged build is ready. Only
the "stop the server/region before updating" reason is passed over. deploy.bat exit 3 = a world did not
save and is still running; the window lists those (UnsavedRegions) and either kills them one by one and
runs `deploy.bat continue REGION...`, or starts the stopped ones again. Region ids reach argv only after
the launcher's region-id check.

<!-- 2026-11-05: Civilizationbot tab and Updates -->
Val chose that a bot started by the window stops when the launcher closes (control.php
stop, 90 s wait, then a kill-on-close job object). A bot started elsewhere is left
running. LocalBot.cs holds the control.php argv and parsers; check-update is a
shared read-only JSON contract with gaia_host.py (Civ13 #3790) and control.php
(Civilizationbot #66). Keep Gui/BotPage.cs and Gui/UpdatesPage.cs separate from the
Host tab so region work there does not conflict.

<!-- 2026-11-04: launcher window, OpenDream removed -->
Civ13.exe opens a WinForms window by default; `--console` or redirected input keeps
the numbered text menu, and every other option stays console-only. Only Build.ps1's
`-p:Civ13Gui=true` publish targets net8.0-windows and compiles `Gui/`; test projects
reference the plain net8.0 build so offline restores never need desktop packs. On
Linux the window build needs a Microsoft SDK (the Ubuntu source-built SDK lacks the
WindowsDesktop SDK) plus `-p:EnableWindowsTargeting=true`. The exe stays a console
subsystem binary for scripted exit codes; a double-clicked window frees its console.
Val removed OpenDream from Civ13.exe (menu key 9, client install, `--server-port`);
the legacy script ZIP is separate.

<!-- 2026-10-21: direct BYOND status discovery -->
Public native menus probe only the configured Civ13.com and ValZarGaming hostnames
on ports 1714 and 1715. These are candidates, never an online assertion or a mode
mapping. No HTTPS server directory, backend deployment, port ranges or arbitrary
public --server-port override is involved. Resolve the entire A-answer set and
reject any nonpublic member before opening sockets. Try literals sequentially
within one three-second total deadline per candidate, with fair remaining slices.
Each menu refresh checks only its provider's two candidates concurrently. Valid
integer players=0 is online; optional metadata is unknown when absent and rejects
the response when malformed. Before joining, validate fresh DNS against the exact
respondent. A <=60-second UTC/monotonic process-local response proof can avoid a
duplicate Topic request during cooldown; never reconstruct it from disk cache.
Reject changed or missing selected map/mode/round identity on new status queries;
bounded response reuse cannot observe a round change during that short window. Bind verified
status, literal and configured port together, validate freshness at dispatch,
and launch only the verified BYOND client. Never add a permanent IP pin or reuse
this query for OpenDream. Source merge does not activate the launcher feed;
exact-head packaging/CI, independent review and a genuine public join gate release.
See tools/opendream-client/native/SERVER-DISCOVERY.md.
A host doorman on fixed TCP 1713 (scripts/gaia-host serve) may report instances
asleep; those are listed from its cache, never queried directly, and Wake and
join wakes, polls the doorman, then verifies the game port directly. The
doorman's answer never becomes a GameServer, an address or join authority.
Public Topic writes use the fixed per-account status-requests lock/state,
independent of --root. Reserve before writing, retain failed reservations and
correlate validated IP aliases plus configured port. Spacing defers locally;
never sleep inside the three-second IO budget or silently retry after a write.
The 137-second reservation covers 130 seconds plus IO/clock margins; new instances
reuse system-wide monotonic anchors and cached result/age without adding another
startup wait. Legacy 1.0.5 wall-only history retains the 133-second migration guard
for its matching endpoint until its next reservation. A lower uptime waits only
through the new boot's first 133 seconds. Schema 2 caches bounded validated
metadata, never launch tokens; late results are tied to reservation IDs. Older
1.0.5 instances fail closed on schema 2. Clock/state/link failures pause locally. J explicitly rechecks a deferred selection; B cancels with no
background callback. Joining needs fresh safe DNS and an original-age recent proof
or one eligible new status response. Never extend status age or DNS token life;
recheck original monotonic and UTC60-second expiry at dispatch. Persisted cache
is display-only after process restart. See SERVER-DISCOVERY.md for join controls.
Wall time cannot prove game-time advancement or clear a server ban. Do not probe
the known banned Desktop source until owner-coordinated normal eligibility.

<!-- 2026-10-24: offline launcher social contracts -->
tools/opendream-client/native/Social is inert; production Main stays unwired.
tests/SocialContracts runs injected adapters/clocks/discovery/dispatch only,
separate from updater replacement tests. Reuse NativeStart and existing proofs;
dispatch is not connected gameplay or shard-travel evidence. See its README.
Keep player presence/native callbacks separate from DiscordPHP backend APIs.
SDK linking/distribution and native acceptance remain separate gates. Application
profiles are explicit per host; no application ID is a universal default.
PumpedSocialClient needs one explicit worker pump; Accepted/ClearIssued are local
evidence, not Discord UI/remote cleanup proof. No native transport is supplied;
CompanionPresenceTransport adds original bounded framing over an injected channel.
The companion/ C++ core and C-ABI backend use fake SDK functions for tests.
Concrete Windows parent process/pipe source is fixed off and tested through
injected OS stages only; native endpoint hosting, SDK loading and startup
composition remain absent. See SOCIAL-SDK-WINDOWS-PROVIDER.md and
SOCIAL-SDK-COMPANION.md in the native launcher directory for the boundaries.
Before an isolated .NET CLI home's first use, set
DOTNET_GENERATE_ASPNET_CERTIFICATE=false to avoid automatic development-cert setup.

<!-- 2026-10-15: native graceful shutdown boundary -->
Native BYOND `del(world)` can return before process exit. Yield before declaring
shutdown failure, or transaction cleanup can erase the published recovery intent.
The lifecycle disk fixture checks the intent after exit; its `shutdown-return`
negative control reproduces the old immediate cleanup.

<!-- 2026-10-19: bounded launcher transport retries -->
Launcher retry tests use injected HTTP handlers, never BYOND/accounts. Retry only
classified resets/timeouts with finite attempts and an overall body-read budget;
certificate/auth failures, untrusted redirects and bad hashes remain fail-closed.
Delete only a failed attempt's newly created staged file, never a pre-existing
path. Preserve TLS validation and redact errors. Proxy IsBypassed(false) alone
does not prove traffic used a proxy. Source changes do not activate a release.

<!-- 2026-10-14: native launcher packaging -->
`tools/opendream-client/native/Build.ps1` builds the single-file self-contained
Windows x64 launcher. Its offline console tests cover mock updates plus actual
EXE replacement after parent exit and BYOND prerequisite adapters, without accounts
or a game. Release publication builds the exact tag and verifies immutable asset
readback before advancing the separate native feed; prereleases do not activate it.
Preserve the existing client channel and distinguish package integrity/BYOND setup
from identity/gameplay acceptance. Never silently accept installer licenses.

<!-- 2026-11-16: Front door and ports dialog -->
Val asked (2026-11-16) that moving the gate and managing ports need no technical knowledge. All regions > More >
**Front door and ports…** (Gui/FrontDoorDialog.cs, GroupPorts.cs) runs `shard_group.py ports`, `set-gate --region ID`
and `set-port --region ID --port N` (scripts/shard-group/group_ports.py). The dialog always asks for the plan first
(no `--apply`), shows it for one confirmation, then applies and follows `<root>/port-change.json` through `ports`
every 3 s. It passes `--bot-profile` from host.json's bot and restarts a running bot itself when the change ends
with `bot.restart`. Keep the wording plain: the dialog says "front door", never "gate" or "relay".
