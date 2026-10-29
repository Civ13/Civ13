# Civilization 13

![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/civ13/civ13.svg?style=flat)
![GitHub repo size](https://img.shields.io/github/repo-size/civ13/civ13.svg?style=flat)

## WHAT IS THIS?

Civ13 (formerly 1713) is a game based on Space Station 13 code, which features several epochs of human history. It features both RP and Combat maps and gamemodes.

<kbd>
 <img src="https://i.imgur.com/napac0L.png">
</kbd>


## Civ13 Discord
[![discord](https://discordapp.com/api/guilds/468979034571931648/widget.png)](https://civ13.com/discord)


## Official Website
https://civ13.com/


## Playing the game

### OpenDream client for Windows

The portable OpenDream client is experimental. Download the
[current Windows launcher package](https://github.com/Civ13/Civ13/releases/download/opendream-client-2026-10-12-movement/Civ13-Launcher-Windows-v2.zip),
extract it, and double-click **Civ13.cmd**. Its first run downloads the full client,
so allow time for the download. Choose **Sign in** and use your own account, then
choose **Play Nomads** or **Play TDM**. This is the currently published client's
sign-in flow; the new BYOND identity integration is still under verification.

Windows x64 is required. You do not need to install .NET separately or run the
launcher as administrator. Clients are kept under `%LOCALAPPDATA%\Civ13`; updates
keep older client versions and your account settings. The launcher checks verified
updates at startup and can use an already installed client when offline.

The stable native launcher feed references **1.0.7**, whose embedded BYOND
requirement is **516.1681**. This source prepares **1.0.8** with an exact **516.1688**
client requirement, aligned with the default compiler/server target in
`tools/byond/version.json`. Source merge does not update an installed launcher or
advance the stable feed. The new executable needs separate build, compatibility
review and release approval; see [the acceptance matrix](docs/byond-5161688.md).

The native launcher verifies both BYOND and DreamSeeker file versions and offers
the pinned official installer if missing. Review its license and Windows prompts;
a separate versioned folder preserves older installations. Installing BYOND does
not log you into an account. The client requires Windows 10/11, 32-bit WebView2 and
the Visual C++ runtimes listed on the official download page.

### BYOND client

You will need a windows machine or a virtual machine running it from another OS.

1. Download the intended BYOND **516.1688** distribution from https://www.byond.com/download/
   Compatibility acceptance is pending; do not replace an existing playtest installation without owner approval.

2. Register a BYOND account at https://secure.byond.com/Join

3. Launch BYOND from **BYOND/bin/Byond.exe** and login.

4. Navigate to **Space Station 13** and search for the **Civilization 13** server.

5. You will start playing in seconds!


## Setting up a Server

The legacy `INSTALL` and `INSTALL.py` provisioners are retired. They exit with
status 2 without installing or changing anything. Do not use the old
`sudo bash INSTALL` instructions.

### Windows/WSL

See [the local Windows/WSL setup instructions](docs/local-wsl.md#windowswsl)
for the existing Prepare, Build, Start, Stop and Status flow.

### Linux

See [the direct Linux local-test instructions](docs/local-wsl.md#direct-linux-local-test-runtime)
for the existing Debian-compatible setup and controller.

These paths prepare separate local test servers using the BYOND target in
`tools/byond/version.json`; they are not a production migration procedure or an
integrated cross-platform launcher installer. Setup/build and server startup
are separate actions. Review the [compatibility acceptance matrix](docs/byond-5161688.md)
before replacing an existing runtime.

Legacy `scripts/launch.py` and `scripts/updateserver.py` are not upgraded.
Preserve existing saves, configuration and binaries, and coordinate shutdown
with the server owner before any migration. These tools do not configure
firewall rules, router forwarding or DNS.

## Contributor API reference
See [source documentation generation and comment conventions](docs/api/README.md).

## Designing maps

See the [Civ13 mapping checklist](docs/mapping.md) for map registration, areas,
travel, spawns, resource readiness and saved-world compatibility.

For experimental Python generation, see the [offline procedural map guide](docs/procedural-maps.md).
It produces new typed IR, a static DMM and a required sidecar without launching
the game or replacing installed maps. Native playability and a reference-matching
seed remain unverified.

The [liminal authored-room tool](tools/liminal_maps/README.md) prepares finite
indoor topology and separate scenario/template manifests. Its
[mode design](docs/liminal/README.md) records the native DMM/gameplay work still
required; the tool does not register or activate a game mode.

## Cloud-rendered scene capture

See [reproducing native cloud-rendered stills](docs/cloud-rendering.md) for the
isolated Windows bakery capture, source pins, bounded workflow and evidence limits.
