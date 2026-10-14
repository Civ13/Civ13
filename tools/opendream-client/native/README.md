# Single-file Windows launcher

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

Executable updates use a separate `native-launcher-channel.json` at the same
repository channel location. Its schema is `{ "schema": 1, "version": "1.0.1",
"url": "https://github.com/Civ13/Civ13/releases/download/<immutable-tag>/Civ13.exe",
"sha256": "<64 hexadecimal characters>" }`. Publish an accepted immutable EXE,
verify its downloaded hash, then commit this manifest through review. No native
channel is activated by this PR. A missing/offline channel continues the current
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
