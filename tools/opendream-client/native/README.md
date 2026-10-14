# Single-file Windows launcher

The pending isolated DreamDaemon test path accepts
`Civ13.exe --root D:\isolated\launcher --local-dreamdaemon D:\isolated\host.json`.
It reads and checks the host receipt before updater, client setup or menu work.
The receipt has schema 1, `port`, `pid`, `startTimeUtcTicks`, absolute `daemon`
and `world` paths, `worldSha256`, 40-character `sourceCommit` and `map`.
The trusted host owner supplies it after starting the isolated host. The launcher
checks the live PID/start time, executable path and 516.1681 PE version, and world
hash, then constructs only `byond://127.0.0.1:<port>` for the verified installed
Dream Seeker. This operator-configured test path is not automatic engine detection.
Source/map labels belong to the trusted host receipt; they are not inferred from
the game binary. The hash checks the current file on disk, not the loaded world;
the receipt's port does not prove TCP ownership by that PID. Before actual host
acceptance, the host owner must establish receipt provenance, the original frozen
world hash, immutable staging and process/port ownership. This scaffold accepts
only `DreamDaemon.exe`; an actual `dd.exe` host or GUI parent requires a reviewed
executable policy and the real serving process identity before testing.
Normal public Play continues to enforce the fresh DNS policy.

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
Players need no .NET installation or companion scripts. Double-click the file,
let it obtain the complete verified client, and use its sign-in/play menu. The
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

`byond.json` embeds the project-required **516.1681**, from the repository's
explicit BYOND toolchain requirement, rather than the newest available version.
The official [BYOND build archive](https://www.byond.com/download/build/516/)
provides `516.1681_byond.exe`. Its SHA-256 is pinned from a read-only official HTTPS
download on 2026-10-14, not represented as a checksum published by BYOND. The
installer's PE version and NSIS format were checked without executing it.

Detection checks both BYOND and DreamSeeker PE versions through the managed
install receipt, 32/64-bit HKLM/HKCU Dantom registry locations, known program
folders and BYOND_BIN. Users can identify another existing portable folder.
Missing/wrong versions offer a verified official installer, with no silent switch
or license/Windows prompt bypass. NSIS's [documented /D option](https://nsis.sourceforge.io/Docs/Chapter3.html#installerusage)
suggests a separate `%LOCALAPPDATA%/Civ13/BYOND/516.1681` directory; incomplete
existing directories cause a new suffix rather than being overwritten. User
changes to the installer's directory remain under their control. Installed PE
versions are checked again before recording success; failure/cancellation can be
retried, and cached downloads are rehashed. Actual BYOND installation/UI was not
run during offline verification.

This prerequisite prepares the BYOND binaries. It neither logs a user into BYOND
nor validates or implements the separate PR18 BYOND-derived identity handshake.
The current published client's authentication flow remains unchanged.

## Game server hostname

Each native launcher Play attempt resolves `valzargaming.com`, excludes
`192.64.119.81`, and requires the remaining answer to be the operator-approved
`72.218.249.221`. It displays and passes only that freshly verified DNS address to
the installed client's `Connect.ps1 -ServerAddress`, preventing a second lookup
from selecting the excluded address. A changed/unverified endpoint blocks Play
until its configuration is reviewed; the launcher never falls back to a stale IP.
Nomads and TDM retain that script's existing ports (18452 and 18453 in the current
published package) and protocol/authentication behavior. Lookup failure, timeout,
or an unverified address keeps the menu open for retry without starting a game.
DNS resolution does not authenticate a server. Windows script policies remain in
effect. Older direct Play CMD files retain their packaged connection defaults.
