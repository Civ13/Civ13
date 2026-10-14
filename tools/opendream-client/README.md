# OpenDream continuous movement patch

The portable Civ13 client uses OpenDream revision
`b1a452e7fefa36f8919bff38067c602d0bb4e1a5`.
The original glide handler jumps to the previous tile destination whenever a
new step arrives before its animation finishes. It also assumes 20 ticks per
second and assigns a fixed speed to automatic gliding.

`movement.patch` applies to that exact engine revision. It preserves the current
rendered position when updating the destination. While movement updates overlap,
automatic glide speed covers the remaining distance in the observed update
interval, bounded below by one server tick. Explicit positive glide sizes retain
their configured pixels-per-tick rate, using the actual server tick rate.
Moves exceeding two tiles from the previous authoritative destination remain
immediate teleports. The camera follows the eye transform, so the same continuous
movement reaches the camera. No game movement delays or server gameplay change.

Apply the patch in an isolated engine checkout. Preserve the portable client's
separate RobustToolbox authentication-order patch. Build OpenDreamClient with the
matching .NET 10 SDK and RobustToolbox revision. Replace only the OpenDream client
and shared assemblies/PDBs in a candidate `Content.Client.zip`, retaining the
existing resources and manifest. Rebuild the portable distribution and installer
checksums after visual acceptance; do not overwrite an existing release asset.

Run the bounded regression with a verified full Python interpreter path:

```text
verify-movement.py --engine <OpenDream-checkout> --dotnet <full-dotnet-path>
```

It compiles the production glide handler and timing helper with isolated transport
adapters in temporary storage. It checks 50 held-key steps at 10/20/30/60 ticks per
second, continuity, catch-up, turns, teleport cancellation and explicit gliding.
The historical source control must reject snapping; the fixed-speed control must
reject failing to catch up. Neither launches a game or contacts a server.

Local evidence: 211 assertions and both behavior controls passed. The full client
build completed with zero errors and 172 existing/dependency warnings. This does
not establish graphical acceptance. Before publishing, hold a movement key across
several tiles at walking/running speeds, turn, stop, and verify both character and
camera remain continuous using a genuine client capture. The installed client and
connected server remain unchanged until the candidate handoff is accepted.

The patch contains MIT-licensed OpenDream-derived code; see
`OPENDREAM-LICENSE.txt`. No upstream pull request or production deployment is implied.

## Simplified launcher and update channel

For the single-file native Windows launcher, build and distribute `Civ13.exe`
from [native/README.md](native/README.md). Its separate executable update channel
remains inactive until release deployment builds and verifies an immutable binary
and its downloaded checksum. The script package below remains available for existing users.

Distribute `Civ13-Launcher-Windows.zip` containing Civ13.cmd, Launcher.ps1,
Install-Client.ps1, channel.json and LAUNCHER-README.txt. Testers extract it and
run Civ13.cmd. It downloads the complete client and offers sign-in and game
choices. Updates use master/tools/opendream-client/channel.json, restricted to
HTTPS release assets in Civ13/Civ13 with a mandatory SHA256 checksum. The bundled
manifest provides the original published client before the channel is available.
A successful installation caches the manifest for offline use; no running version
or authentication storage is replaced. A file lock serializes updates. Disk-full,
interruption or failed validation leaves the previous version usable. Failed
staging folders and old versions are retained for recovery and manual cleanup.

Publish a new immutable release asset only after acceptance. Verify its downloaded
SHA256, then change channel.json version/url/sha256 in a reviewed repository
commit. Never point the channel at an unaccepted candidate. The small launcher
scripts themselves are fixed in this download; changes to updater behavior require
a new launcher package. Run Test-Launcher.ps1 for isolated native PowerShell
installation and rejection tests, with no network calls, credentials or game start.
