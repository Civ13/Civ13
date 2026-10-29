# Single-file Windows launcher

The stable feed references launcher 1.0.7 with BYOND 516.1681. This source
prepares unreleased launcher 1.0.8 with BYOND 516.1688; publishing it requires exact-head packaging/CI, independent review
and the applicable acceptance checks. No HTTPS server directory or additional
backend deployment is required. See [SERVER-DISCOVERY.md](SERVER-DISCOVERY.md).
One successful status query alone does not establish prejoin or gameplay acceptance.

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
remains unchanged; public native choices do not download OpenDream.

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
join native BYOND servers. Experimental OpenDream remains an explicit separate
choice in `Civ13.exe`.

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
Transport resets and timeouts get at most three attempts, with 250 ms then 750 ms
backoff. The manifest has a 20-second total budget (six seconds per attempt).
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
{"schema": 1, "game_directory": "D:/GitHub/Civ13", "world": "civ13.dmb", "port": 1714, "public": true,
 "bot": {"php": "C:/php/php.exe", "root": "D:/Civilizationbot-local/bot", "profile": "D:/Civilizationbot-local/profile.json"}}
```

`H` starts the verified BYOND `dd.exe` with `-trusted`, `-public` (or `-invisible`),
`-close` and `-log logs/world.log` in `game_directory`, unless something already listens on
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
The launcher does not stop servers. `tests/LocalHostingTests.cs` injects process
starts, update steps and port probes, so it launches nothing.

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
5-8 existing community links, and 9 experimental OpenDream.

[The direct status and rollout checklist](SERVER-DISCOVERY.md) describes
bounded game-service queries, status details, Refresh/Back, selection revalidation,
provider hostname checks and fresh public IPv4 validation for both providers.
Each validated address is bound to its approved hostname for one join attempt
with a 15-second monotonic lifetime. Public choices reject `--server-port`.
No live availability is inferred from old website links,
static mode names, DNS alone, or a cached snapshot.

Experimental OpenDream still requires an explicitly verified operator
`--server-port`. It does not use the BYOND status query. Legacy OpenDream
shortcuts retain their historical packaged endpoints; they are not native BYOND
shortcuts. Local DreamDaemon verification still uses its genuine host receipt.
