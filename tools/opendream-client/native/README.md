# Single-file Windows launcher

Run `Civ13.exe --help` to list launcher and operator options without starting the
normal launcher flow. The launcher is optional for ordinary BYOND gameplay.

The launcher targets BYOND 516.1688. The stable feed identifies the currently
published launcher; this source declares its build version in version.json.
Publishing requires exact-head packaging/CI, independent review and the applicable
acceptance checks. No HTTPS server directory or additional backend deployment is
required. See [SERVER-DISCOVERY.md](SERVER-DISCOVERY.md).
One successful status query alone does not establish prejoin or gameplay acceptance.

Opening `Civ13.exe` shows the launcher window. Its header shows launcher and BYOND
status with **BYOND sign in** (or **Set up BYOND** when setup is still needed). The
**Play** tab lists Civ13.com or ValZarGaming.com servers with Refresh and Join; a
deferred join becomes **Recheck and join** after the displayed wait. Community links
sit along the bottom beside links to the launcher data folder and read-only server
management, and the launcher log shows update and BYOND messages. A
**Host server** tab appears only when `host.json` enables local hosting.
`Civ13.exe --console`, or redirected input, keeps the numbered text menu described
below. Build.ps1 publishes the window build with `-p:Civ13Gui=true`; other projects
reference the plain `net8.0` build, so their offline restores need no desktop packs.

For native play, open `Civ13.exe`, sign into BYOND Pager with your own account,
then choose **Civ13.com servers** or **ValZarGaming.com servers**. The launcher
queries that hostname's explicitly configured candidate game ports, 1714 and 1715,
using BYOND status. Only responding valid game services are selectable. The menu
shows player counts (including zero), map, mode and round information where
available; unavailable metadata is labeled rather than invented. An unreachable
or invalid service does not become a zero-player server. Refresh/Back are available.
Before joining, DNS is checked again. A successful response from this launcher
process can be reused for at most 60 seconds, including monotonic time, so joining
does not send a duplicate rate-limited status request. The exact responding IP
must still be in the complete safe DNS answer set. DreamSeeker connects to that
verified literal and configured port. Status reuse cannot detect a round change
within its short freshness window. Public port overrides and
arbitrary scans are rejected. BYOND 516.1688 prerequisite verification/installation
remains unchanged. `Civ13.exe` no longer offers or downloads OpenDream.

Public status checks share conservative request spacing across launcher instances
for this Windows account. A check can be deferred for up to 137 seconds after a
request. Fresh history is checked immediately, and restarting keeps the actual
remaining cooldown instead of adding another startup wait. During cooldown the
menu displays cached results, their age and the remaining wait. A cached success
is last verified status, not a claim that the server is still online; cached
failures and checks with no result are distinguished. Persisted cache entries expire after
ten minutes and never contain a connection/launch token. The join proof is
process-local and keeps its original timestamp; cached display data after restart
requires one eligible status request. J then joins directly after a successful
check, without a new refresh/discovery cycle. Existing 1.0.5 history
has no cache or monotonic timestamp, so its affected endpoint retains one
conservative 133-second migration wait until a new reservation is recorded.
The menu stays responsive. For a
deferred join, press **J** after the displayed wait for its eligible check, or
**B** to cancel.
No countdown silently sends a request or launches a game. Refresh uses the same
limiter. Local timing-state problems are reported as paused checks, not an offline
game. Timing state lives in `%LOCALAPPDATA%/Civ13/status-requests`, independent of
`--root`; do not delete it to bypass spacing. Waiting cannot clear an existing
server ban or prove server game time advanced during lag. Known blocked sources
must wait for owner-coordinated normal eligibility before further public checks.

The script ZIP and its existing shortcuts are legacy OpenDream entrypoints.
New script-installed shortcuts include `OpenDream` in their names. They do not
join native BYOND servers. `Civ13.exe` no longer includes an OpenDream option
or the OpenDream-only `--server-port` operator override.

## Isolated operator verification

The pending isolated DreamDaemon test path accepts
`Civ13.exe --root D:\isolated\launcher --local-dreamdaemon D:\isolated\host.json`.
It reads and checks the host receipt before updater, client setup or menu work.
The receipt has schema 1, `port`, `pid`, `startTimeUtcTicks`, absolute `daemon`
and `world` paths, `worldSha256`, 40-character `sourceCommit` and `map`.
The trusted host owner supplies it after starting the isolated host. The launcher
checks the live PID/start time, executable path and the embedded requirement's exact 516.1688 PE version, and world
hash, then constructs only `byond://127.0.0.1:<port>` for the verified installed
Dream Seeker. This operator-configured test path is not automatic engine detection.
Source/map labels belong to the trusted host receipt; they are not inferred from
the game binary. The hash checks the current file on disk, not the loaded world;
the receipt's port does not prove TCP ownership by that PID. Before actual host
acceptance, the host owner must establish receipt provenance, the original frozen
world hash, immutable staging and process/port ownership. Receipts must identify the real serving process rather than a GUI parent.
Normal public Play continues to enforce the fresh DNS policy.
Local receipts accept the official BYOND `DreamDaemon.exe` and console `dd.exe`
hosts, with the same pinned version, process start, executable path and world
hash checks for both entry points.

Normal BYOND settings/cache are allowed under the current storage policy. The
launcher does not move accounts/cache or change preferences. `--root` can be any
absolute unlinked folder chosen with measured headroom; the prepared child uses
it for working directory and TEMP/TMP/TMPDIR. Normal launcher-owned update/client
files use that root, which is retained on update restart. This does not imply
third-party native client files stay there. The injectable strict-D source mode
still rejects unknown or C: user-data settings; it is not the normal CLI path.
Host admission requires the owner's genuine receipt, verified serving process
and sufficient output space, with monitoring and an owned-output cleanup plan.
Local compilation and 73 injected controls passed without accounts or game
processes. Actual dispatch remains pending runtime admission and a genuine host
receipt. The earlier 84 checks do not establish an actual DreamDaemon join.

`Civ13.exe` is a native .NET 8, Windows x64, self-contained console launcher.
Players need no .NET installation or companion scripts. Double-click the file
and select a server using the native player flow above. The
menu also offers numbered Website, Wiki, Discord and GitHub links, with their
full addresses visible. Enter 5, 6, 7 or 8 to open the selected resource in your
default browser. If opening fails, the launcher prints the address to copy.
The
published client remains selected by the existing `channel.json`; this packaging
change does not establish BYOND identity, server compatibility or game readiness.

The executable embeds the original client manifest, validates HTTPS Civ13 release
URLs and mandatory SHA-256 hashes, and installs clients side by side under
`%LOCALAPPDATA%/Civ13`. Cached installed clients work when update checks are offline.
Client settings and running client versions are preserved. `launcher.lock` is
shared with the script launcher. Failed staging is retained; older clients are
retained. No shortcuts, administrator access or machine-wide installation.

Executable updates use `native-launcher-channel.json` on the dedicated
`native-launcher-updates` branch. Its schema is `{ "schema": 1, "version": "1.0.1",
"url": "https://github.com/Civ13/Civ13/releases/download/<immutable-tag>/Civ13.exe",
"sha256": "<64 hexadecimal characters>" }`. Publish an accepted immutable EXE,
verify its downloaded hash, then activate the feed through the release workflow.
No native channel activates merely by merging this PR. A missing/offline channel continues the current
launcher. Only newer semantic versions update; the candidate PE product version
must match its manifest. Never point this channel at an unaccepted candidate.

Startup reports the installed/latest versions and check/download/restart stage.
Transport resets and timeouts get at most five attempts, waiting 1, 2, 4 then 8
seconds between them (250 ms apart was too quick to outlast a reset during the
TLS handshake). The manifest has a 60-second total budget (six seconds per attempt).
Downloads retain a ten-minute total budget, including the body, with 20-second
response-header deadlines. Each retry starts from the original URL and a new
empty staged file; only the failed attempt's own file is removed. Certificate
validation/native authentication errors, HTTP rejections, untrusted redirects,
and checksum/version mismatches do not receive transport retries. TLS validation
and the release redirect allowlist remain enabled. Diagnostic failures report
only bounded exception classifications/codes, never signed URLs or raw messages.

The updater stages and verifies the EXE, starts a copied native helper, and exits.
The helper waits for the original process identity to exit, reacquires the update
lock, rechecks the hash/version, and uses same-volume atomic `File.Replace` beside
the original launcher. It preserves `Civ13.exe.previous` and restarts the launcher.
A read-only launch directory or timeout leaves the original file intact. Staging
is preserved for manual diagnosis. Unsigned binary warnings are possible; this
build does not fabricate a signing identity.

Build with `Build.ps1 -Dotnet <verified SDK path>`. Run the offline production-code
tests with `dotnet run --project tests/Launcher.Tests.csproj -- <published-exe>`.
Tests cover successful mock updates, hashes/origins, archive traversal/duplicates,
offline cached clients, concurrency, version/downgrade controls, account retention
and actual executable replacement. `--version` and `--self-check` exercise the
single-file entrypoint without network, accounts or installation. Actual live
update-channel delivery and real client sign-in/gameplay need separate acceptance.

## Local DreamDaemon hosting (operators)

An operator can host a server from the launcher by placing `host.json` in the
launcher root (`%LOCALAPPDATA%\Civ13`, or the `--root` folder). Without that file
the menu is unchanged. With it, `H: Host local DreamDaemon server` appears:

```json
{"schema": 1, "game_directory": "D:/GitHub/Civ13", "world": "civ13.dmb", "port": 1714,
 "bot": {"php": "C:/php/php.exe", "root": "D:/Civilizationbot-local/bot", "profile": "D:/Civilizationbot-local/profile.json"}}
```

`H` starts the verified BYOND `dd.exe` with `-trusted`, `-public` (always; the
hosted world is listed on the hub), `-close` and `-log logs/world.log` in `game_directory`, unless something already listens on
`port`. When `bot` is present it also starts the Civilizationbot portable supervisor
(`control.php start <profile>`) unless the bot's `http_port` from that profile is
already listening. `bot` is optional. Paths must be absolute and exist, and `world`
must be a compiled `.dmb` inside `game_directory`; an invalid file disables hosting
with a message.

An optional `"update": {"git": "C:/Program Files/Git/cmd/git.exe", "branch": "master"}`
updates the server before starting it: `git fetch origin <branch>`, then
`git merge --ff-only FETCH_HEAD` (local uncommitted edits are kept; a diverged
checkout stops), then the verified BYOND `dm.exe -max_errors 0 <world>.dme`, which
must report `0 errors, 0 warnings`. Any failed step leaves DreamDaemon unstarted.
A server already listening on `port` is never updated, because it holds its `.dmb`.

An optional `"control": {"python": "C:/.../python.exe", "script": "D:/GitHub/Civ13/scripts/gaia-host/gaia_host.py", "config": "D:/private/gaia-host.json"}`
hands the server to Civ13's host control script, the same path the Discord bot
uses (see `scripts/gaia-host/README.md`). It replaces `update` (both together are
rejected). Start then runs the script's `start` (save checks, then the scheduled
task) instead of DreamDaemon directly, and the **Host server** tab adds **Save and
stop**, **Restart** and **Update** (each confirmed first except Update), an
**Open world log** link, and a status line (port, world ready, players, last action
and its phase) that refreshes every five seconds while an action runs. Only the
action name reaches the script. `tests/LocalHostingTests.cs` injects process
starts, update steps, control answers and port probes, so it launches nothing.

### One region and group status

With `control.group` set, the Host server tab has two rows of group buttons. **All
regions** runs each action for the whole group. **One region** has a region list (each with its game and travel port; the
list re-reads the group config whenever it opens) and the same `shard_group.py`
actions with `--region`: Start, Save and stop, Restart, Update, **Build update**,
**Save, update and restart** (the handover deploy, `deploy.bat REGION`: its dialog
starts with only that region ticked and deploys whatever is ticked when confirmed;
it builds the latest master beside the running world and moves players across once
the new world has loaded the save. A region still on a build from before handovers
is saved, stopped and started instead, once, so its players are kicked that time.
Restart always kicks them while it saves, stops and starts, and its confirmation
says so),
**Sleep now** and **Wake** (freeze or thaw an empty, saved world), **Apply host
settings** (`config-apply`), **Set up** (create or refresh the region's worktree and
config and enrol it with the running travel agents; refused while it runs, so a new
region is added without stopping the others), the forced actions, the lock-file
cleanups and **Open its world log**. Each is confirmed first. The status line lists,
per region, its port, a staged update and its phase, a handover's new build and
port, what the watchdog did (restarts, gave up, could not start it), a travel agent
that is down and a world that does not answer as that region, and whether the
travel coordinator runs.

### Advance epoch

The All regions row's **Advance epoch** moves the whole group to a chosen epoch
with no restart (`shard_group.py epoch --epoch N`). The mainland's world takes it
first through its lifecycle Topic (`set_epoch`) and must be awake; then every
running region does. A region asleep or stopped follows the mainland by itself
when it next runs. Epochs only move forward, and a world refuses while it saves.
The group status line shows each running region's epoch.

### Host settings

With `control.group` set, the Host server tab's group row adds **Host settings**.
It edits the host's own files in the group config's overlay folders: the group's
`overlay` (shared by every region) and each region's. Those folders are outside the
Civ13 checkout, so a pull or update never replaces them. Each folder offers
`config/config.local.txt` (only the lines this host changes in the repository's
`config/config.txt`; see `scripts/shard-group/README.md`, "Host config settings"),
`config/host.txt`, and the other `.txt` and `.json` files already in its `config`
folder. Files setup writes and kept copies are not offered. **Save** checks the
text (setting lines, valid JSON) and keeps the old version as `<name>.previous`.
**Save and apply** also runs `shard_group.py config-apply` for that folder's
regions, so they get the change without a rebuild; a running world uses it from
its next restart. **Bug report GitHub token...** asks for a fine-grained GitHub
token (Issues: Read and write) and puts `BUG_REPORT_GITHUB_TOKEN` into the shown
folder's `config.local.txt`, replacing an older token line; the editor shows that line as
`BUG_REPORT_GITHUB_TOKEN (hidden)` and saving keeps the real value. Save and apply then sends
it to the regions. The game reads the token only when an admin approves an in-game bug
report, so a running world uses it at once. `HostSettings.cs` holds the file rules and is covered by
`tests/LocalHostingTests.cs`.

### Civilizationbot tab and Updates

When `bot` is present the window adds a **Civilizationbot** tab. It drives the
bot through its own `scripts/windows/control.php`: **Start**, **Stop**, **Restart**
and **Update**, a status line from `control.php status` (falling back to the bot's
`http_port` for a bot checkout without that command), a live view of the bot's
output and error logs, an **Open log folder** link, and **Clear old stop request**
when a stop marker left by an exited bot blocks starting it. The window starts the
supervisor itself, including when **Start server** brings the bot up, and closing
the window first runs `control.php stop` and waits up to 90 seconds. A Windows job
object with kill-on-close ends a launcher-started bot if the launcher exits any
other way. A bot started outside the launcher is shown but left running on close.
The console `H` option still starts the bot detached.

### Player help tab

When `control.group` is set the window adds a **Player help** tab for the
group's "Ask for help" bridges, which the host service keeps running (the
group config's `player_help`; see `scripts/shard-group/README.md`). It shows
`shard_group.py help-status` every 5 seconds while open: every region of the
group, its bridge's PID, whether its heartbeat is fresh, and a region stopped on
request. **Stop all** runs `help-stop` (bridges finish their answers, then stay
stopped until **Start all**, which runs `help-start`). The region list chooses one
region for **Start region** and **Stop region** (`--region`; a region outside the
config's `regions` started this way keeps running) and for the log view below. The bridges belong
to the host service, so closing the launcher leaves them as they are.
`tests/LocalHelpTests.cs` covers the argv and answer parsing.

An **Updates** tab appears with `control` or `bot`. It has one row each for the
server (`gaia_host.py check-update`) and the bot (`control.php check-update`).
Both commands only fetch and print one JSON line with `current`, `available`,
`behind`, `can_update` and `reason`. The tab checks at startup, when opened and
every 30 minutes, and its title shows how many updates are waiting. **Update** is
enabled only when `can_update` is true: the server's runs its control `update`
(the server must be stopped first), and the bot's stops the bot, runs
`control.php update` (a fast-forward of a clean `main`) and starts it again.
`tests/LocalBotTests.cs` covers the argv, answer parsing and log tail without
starting anything.

## Discord activity

When the Discord desktop app is running, the GUI shows "In the launcher" and,
after a join, "Playing Civ13" with `MAP on host` and the elapsed time on the
player's Discord profile, then returns to "In the launcher" when DreamSeeker
exits. It writes to Discord's local RPC pipe (`\\.\pipe\discord-ipc-N`) with
only a public application ID: no Discord SDK, login, OAuth or token. The BYOND
key, character and location are never sent. The built-in ID is
VZGCivilizationBot's (`PresenceSettings.BuiltInApplicationId`), so Discord shows
that application's name; `discord.json` beside the launcher
(`{"application_id": "...", "show_activity": true}`) can override it. The footer's
**Show on Discord** box saves the player's choice there.
`tests/DiscordPresenceTests.cs` replaces the pipe with an in-memory stream.

## Release deployment

Publishing any GitHub release triggers `native-launcher-release.yml`. It checks
out that release's exact tag, records its resolved commit, and builds the version
declared in that tag's `native/version.json`. Tags `vX.Y.Z`, `X.Y.Z` and
`launcher-vX.Y.Z` must agree with that configuration. Dated existing release names
use the exact-tag configuration. Bump the version before publishing a new stable
launcher; the stable feed rejects downgrades and same-version changed bytes/URLs.
Tags predating this implementation cannot generate it; do not move an old tag.

Build, startup, isolated updater tests, and simulated release controls must pass
before uploading `Civ13.exe`, `Civ13.exe.sha256`, and `native-launcher-release.json`.
Every existing asset must match; reruns never overwrite different bytes. Every
uploaded asset is downloaded and hash-checked. Only then does a stable release
atomically advance the dedicated feed branch with a non-forced commit. Prereleases
generate downloads but never activate the stable feed. Partial uploads/readback
failures leave the prior feed intact; verified matching partial uploads can resume.
The release's tag is rechecked before activation. A concurrent feed write fails
without forcing over it. An ambiguous final GitHub API write requires readback
before retrying; never assume it failed and overwrite the feed.

The release job has `contents: write`; PR checks have read permission. A feed
commit created with `GITHUB_TOKEN` does not trigger another workflow, and this
deployment does not depend on such a trigger. The workflow creates no release,
tag, client channel change or game deployment. A release published through
`GITHUB_TOKEN` does not itself trigger this workflow: publish manually, through
the GitHub UI, or an appropriately authorized release token. The stable feed
branch must permit the workflow's non-forced write; a protection rejection fails
activation rather than bypassing protection.

Run `test_release.py` with a verified Python interpreter. Its injected API tests
exercise metadata/tag mismatch, idempotence, interrupted uploads, immutable assets,
readback/commit corruption, stable/prerelease policy and compare-and-swap failure
without creating a live release or feed.

## BYOND prerequisite

Launcher release versions (for example 1.0.8) are independent of BYOND engine
versions. Launcher 1.0.7 bundled an exact 516.1681 requirement, so an installed
516.1688 was rejected even when discovered correctly. Build from the shared
compiler contract below to accept 516.1688. Do not loosen detection to accept
unreviewed future builds or edit a published executable/feed in place.

`../../byond/version.json` is the shared compiler/server/client requirement, embedded
as the resource `byond.json`. It targets **516.1688**, separately from the minimum
compiler 516.1681 and the savefile major 516. A source upgrade is not runtime or
client compatibility acceptance; see [the upgrade matrix](../../../docs/byond-5161688.md).
The official [BYOND build archive](https://www.byond.com/download/build/516/)
provides `516.1688_byond.exe`. Its SHA-256 and size were observed from an official
HTTPS download on 2026-10-24. They provide exact-byte reproducibility, not a
BYOND-published or independently authenticated checksum. The
installer's PE version and NSIS format were checked without executing it.

The accepted client version is the exact compiler target, not `minimumCompiler`.
Both client executables must have canonical matching PE metadata. Older builds,
mixed/malformed versions, and unknown future builds remain unsupported. A future
engine upgrade changes `tools/byond/version.json` with its reviewed installer
URL, SHA-256 and size. That same file is embedded at build time; startup never
fetches a mutable engine requirement and remains usable offline.

`Civ13.exe --byond-contract` only prints the validated embedded contract, before
network requests, registry discovery, setup or sign-in. `Build.ps1` compares that
data from the produced artifact with the complete source contract. Both PR and
exact-tag release workflows call this build guard. `release.py` repeats the
comparison before uploading any asset, binds the contract identity to its plan,
and records its version and canonical SHA-256 in release metadata. A compiler
bump without rebuilding the launcher therefore fails before publication. Existing
immutable asset readback and stable-feed version guards still apply: shipping
different launcher bytes requires a new launcher semantic version.

The offline release tests include compiler-bump, stale artifact, hash/size/URL
drift and malformed-contract controls. Run the focused detection fixture with
`Launcher.Tests.exe --byond-only`; optionally pass an installed BYOND bin folder
for read-only Windows PE/discovery checks. The fixture uses injected setup and
transport adapters and never downloads, installs, starts a game or signs in.

Detection checks both BYOND and DreamSeeker PE versions through the managed
install receipt, 32/64-bit HKLM/HKCU Dantom registry locations, known program
folders and BYOND_BIN. Users can identify another existing portable folder.
Missing/wrong versions offer a verified official installer, with no silent switch
or license/Windows prompt bypass. NSIS's [documented /D option](https://nsis.sourceforge.io/Docs/Chapter3.html#installerusage)
suggests a separate `%LOCALAPPDATA%/Civ13/BYOND/516.1688` directory; incomplete
existing directories cause a new suffix rather than being overwritten. User
changes to the installer's directory remain under their control. Installed PE
versions are checked again before recording success; failure/cancellation can be
retried, and cached downloads are rehashed. Actual BYOND installation/UI was not
run during offline verification.

This prerequisite prepares the BYOND binaries. It neither logs a user into BYOND
nor validates or implements the separate PR18 BYOND-derived identity handshake.
The current published client's authentication flow remains unchanged.

## Player server selection and discovery

Main-menu order: 1 BYOND sign-in, 2 Civ13.com, 3 ValZarGaming.com, 4 Exit,
5-8 existing community links. Key 9 (experimental OpenDream) was removed.

[The direct status and rollout checklist](SERVER-DISCOVERY.md) describes
bounded game-service queries, status details, Refresh/Back, selection revalidation,
provider hostname checks and fresh public IPv4 validation for both providers.
Each validated address is bound to its approved hostname for one join attempt
with a 15-second monotonic lifetime. There is no port override for public choices.
No live availability is inferred from old website links,
static mode names, DNS alone, or a cached snapshot.

Legacy OpenDream
shortcuts retain their historical packaged endpoints; they are not native BYOND
shortcuts. Local DreamDaemon verification still uses its genuine host receipt.

## Mobile host access

The optional [mobile LAN companion](../../../scripts/gaia-host/MOBILE.md) uses
the Host tab's existing control backend. A configured `mobile_url` in `host.json`
displays its HTTPS LAN address in the Host tab. This does not start a listener;
certificate pairing, trusted HTTPS and explicit operator setup are required.
