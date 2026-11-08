# Civilization 13

![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/civ13/civ13.svg?style=flat)
![GitHub repo size](https://img.shields.io/github/repo-size/civ13/civ13.svg?style=flat)

Civ13 (formerly 1713) is a BYOND game built on Space Station 13 code. It covers
human history from the stone age to the space age, with persistent Nomads
survival worlds as well as round-based combat (TDM) maps and game modes.

<kbd>
 <img src="https://i.imgur.com/napac0L.png">
</kbd>

- **Discord:** [![discord](https://discordapp.com/api/guilds/468979034571931648/widget.png)](https://civ13.com/discord)
- **Website:** https://civ13.com/
- **Player wiki:** https://civ13.github.io/civ13-wiki ([source](https://github.com/Civ13/civ13-wiki))

## Playing

You need Windows (or a Windows VM) and BYOND **516.1688**, the version pinned in
[`tools/byond/version.json`](tools/byond/version.json).

### With the Civ13 launcher (recommended)

1. Download `Civ13.exe` from the newest `launcher-v*` release on the
   [releases page](https://github.com/Civ13/Civ13/releases?q=launcher). It
   updates itself from then on.
2. Open it. If BYOND is missing or the wrong version, **Set up BYOND** offers the
   official installer. Then **BYOND sign in** with your own BYOND account.
3. Optionally sign in with Discord, which ties your connection to your Discord
   account (see [Discord accounts](docs/accounts/discord-accounts.md)).
   BYOND-only play works as before.
4. On the **Play** tab, pick a server and press **Join**.

Launcher details: [tools/opendream-client/native/README.md](tools/opendream-client/native/README.md).

### With plain BYOND

1. Install BYOND 516.1688 from https://www.byond.com/download/ and register at
   https://secure.byond.com/Join.
2. Open BYOND, log in and search the hub for **Civilization 13**, or connect
   directly to `byond://play.valzargaming.com:1714` (Gaia, the Nomads mainland).

New players should start with the wiki's
[New Player Guide](https://civ13.github.io/civ13-wiki/New_Player_Guide.html).

## The persistent world: regions

The Nomads server is a **region group**: several worlds that run side by side on
one host and share one epoch and OOC chat. Each account has one home world;
new characters start on Gaia and travel between regions by trail, train or rocket.

| Region | What it is |
| --- | --- |
| Gaia | The mainland Nomads world (port 1714). New characters start here. |
| Rail Yard | The shared rail yard world that [party trains](docs/party-train.md) run to. |
| Mars (Barren) | A dry settlement world, open from the 2026 epoch. |
| Moon | A lunar settlement world, open from the 1969 epoch. |
| Orbit | Orbital stations reached only by rocket; being built ([plan](docs/orbital-stations-plan.md)). |

How it fits together:

- [`scripts/shard-group/shard_group.py`](scripts/shard-group/README.md) gives each
  region its own git worktree, build, config and saves, and handles setup,
  update, start/stop, epochs, travel and **staged builds**.
- **Staged handover:** an update is built beside a running region; the old world
  saves (holding only the level being saved), the new build loads that save and
  players reconnect to it, so deploys do not take the world down.
- [`scripts/gaia-host/`](scripts/gaia-host/README.md) is the host service: the
  **doorman** (wakes sleeping regions, watchdog, low-memory eviction), freezing
  empty regions, and the **routing relay** (`relay.py`) that puts every region
  behind two public ports.
- [`scripts/windows/host/`](scripts/windows/host/README.md) has the Windows
  wrappers: `status`, `start`, `stop`, `restart`, `deploy`, `stage`, `setup`,
  `epoch`, `freeze`/`thaw`, `unlock` and more. Linux hosts call the Python scripts
  directly (`scripts/gaia-host/civ13-host.service.example`).

Design notes: [connected regions](docs/connected-regions-plan.md) and
[cross-shard radio](docs/cross-shard-radio.md).

## Hosting a server

- **Windows host (recommended):** set up a region group with
  [`scripts/windows/host`](scripts/windows/host/README.md) (copy
  `settings.example.bat` and `group.example.json`, run `setup.bat`, then
  `install-host-task.bat`). The launcher's **Host server** tab (shown when
  `host.json` enables local hosting) drives the same actions: status, start/stop,
  **Save, update and restart** (staged handover), build update, sleep/wake, epoch,
  lock-file cleanup and host config overlays (`config.local.txt`).
- **Linux:** run `shard_group.py` and `gaia_host.py serve` as a systemd service, or
  a single world with DreamDaemon. See the
  [direct Linux local-test instructions](docs/local-wsl.md#direct-linux-local-test-runtime).
- **Local test server on Windows/WSL:** [docs/local-wsl.md](docs/local-wsl.md#windowswsl).

The old `INSTALL`, `INSTALL.py`, `scripts/launch.py` and `scripts/updateserver.py`
are retired; do not use them.

## Building and testing

1. Install the pinned compiler. On Windows install BYOND 516.1688; on Linux or a
   cloud session run `bash scripts/cloud_byond_setup.sh`.
2. Compile: `compile.bat` or `dm.exe civ13.dme` on Windows,
   `DreamMaker -max_errors 0 civ13.dme` on Linux.
3. Run the focused tests for the area you changed (under `tests/`, each with its
   own README or runner).
4. Before pushing, run `python3 scripts/agent_preflight.py all --write`. It finds
   tests pinned to the files you touched, regenerates the crafting atlas and
   recipe audit index, runs the lint ratchets and every offline CI suite.

CI selection and the offline baseline are described in
[docs/ci-selection.md](docs/ci-selection.md). Lint uses SpacemanDMM `dreamchecker`
(`SpacemanDMM.toml`). Contributor and agent rules live in
[AGENTS.md](AGENTS.md) and [CODEX.md](CODEX.md).

## Agent control and MCP

- [Agent control](docs/agent-control.md) lets scripts and LLM agents observe and
  run a server over world/Topic: status, players, variables, admin verbs, messages
  and playable characters. It is off unless the host creates
  `config/agent-control.txt`, and each agent gets only the scopes listed for it.
  `python tools/agent-control/civ13_agent.py mcp` exposes it as an MCP server.
- [`tools/mcp`](tools/mcp/README.md) is a local MCP server for source, compile and
  runtime tools, plus a read-only Atlas/docs reference server.
- [BYOND Devtools](https://github.com/Civ13/byond-devtools) is the companion
  toolkit for map work: inspection, static and in-game rendering, safe edits,
  diffs, prefabs, an MCP server and a VS Code map editor.

## Contributing content

- **Maps:** the [mapping checklist](docs/mapping.md) covers registration, areas,
  travel, spawns and save compatibility. Offline generators:
  [procedural maps](docs/procedural-maps.md) and the
  [liminal room tool](tools/liminal_maps/README.md).
- **Source API docs:** [docs/api/README.md](docs/api/README.md).
- **Player guides:** update the [wiki](https://github.com/Civ13/civ13-wiki) once
  a player-facing feature is merged and live.
- **Scene capture:** [cloud-rendered stills](docs/cloud-rendering.md).

## License

GNU Affero General Public License v3.0; see [LICENSE](LICENSE).
