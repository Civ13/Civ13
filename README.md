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
   The Dream Maker IDE re-sorts `civ13.dme` alphabetically when it saves (for
   example after you tick or untick a file). The game still compiles that way,
   but some procs are extended across files in the listed order, so restore it
   with `git checkout civ13.dme` before you commit, and add new `#include`
   lines by hand. Put a define that other files use in `code/__defines/`;
   `tests/dme_order` checks this for both orders.
3. Run the focused tests for the area you changed (under `tests/`, each with its
   own README or runner).
4. Before pushing, run `python3 scripts/agent_preflight.py all --write`. It finds
   tests pinned to the files you touched, regenerates the crafting atlas and
   recipe audit index, runs the lint ratchets and every offline CI suite.

CI selection and the offline baseline are described in
[docs/ci-selection.md](docs/ci-selection.md). Lint uses SpacemanDMM `dreamchecker`
(`SpacemanDMM.toml`). Contributor and agent rules live in
[AGENTS.md](AGENTS.md) and [CODEX.md](CODEX.md).

## Coding pitfalls

Most persistent-world bugs come from a few habits that look harmless in code
review. Each rule below names the check that guards it; run those checks with
`python3 scripts/agent_preflight.py all --write` before pushing.

### Persistence: what the saver really saves

- **`var/tmp` does not keep a field out of a save.** The saver walks every
  changed var on mobs, items and structures, tmp vars included. Exclude
  process-local state in `persistence_runtime_var()` (see
  `code/modules/persistence/functions.dm`), or, for a `world.time` stamp, in
  `code/modules/persistence/world_time_stamps.dm`.
  Guard: `tests/persistence_pointers/test_world_time_stamps.py`.
- **Never save a `world.time` stamp.** `world.time` starts at zero after every
  reboot, so a restored cooldown sits hours in the future: a door stayed shut,
  an animal could not bite, a ship stayed "at sea" with no timer to bring her
  in. Register the stamp in `world_time_stamps.dm`, or store `world.realtime`.
  Same guard as above.
- **Do not keep references to things on another z-level, or to throwaway
  objects, in a saved field.** Each level saves on its own, so a cross-level
  reference fails the whole save closed (one stale `lastattacker` once blocked
  every save). AI targets, grabs, HUD actions, attack logs and client links are
  runtime state: exclude them. Only fields declared with
  `persistence_level_link_var()` may cross levels. Never clear a live pointer
  just to make a save pass. Guard: the save itself, plus
  `tests/persistence_pointers` and [the pointer audit](docs/persistence-pointer-audit.md).
- **Do not store `\ref[]`/`REF()` strings, timer ids or client/ckey-bound
  objects as durable data.** Refs are recycled after a reboot and timers are
  not saved (`active_timers` is excluded), so a timer-driven loop stops after a
  load. Restart it in `after_load()`.
- **Keep first-spawn work out of `New()`.** A load builds each saved atom with
  `new type(loc)` before its fields arrive, and the saver omits fields still
  at their default. Random looks, starting inventory, serial numbers and
  random stats go in `on_runtime_spawn()`; anything derived from a saved field
  is rebuilt in `after_load()`, never by a timer. A constructor that throws
  aborts the whole import. See `code/modules/persistence/restore_contract.dm`.
  Guard: `tests/load_construction/run.py` (native; CI runs it on every game change).
- **Do not save icons, images or sounds you can rebuild.** A savefile embeds a
  full copy of every resource held in a field, per entry; derived art once made
  up about 80% of a Gaia level file. Rebuild them from type defaults
  (`code/modules/persistence/derived_assets.dm`).

### Memory: stale references and leaks

- **Delete with `qdel()`, never `del()`.** `del()` scans every reference in the
  world: 18 ms per datum and 67 ms per mob on Gaia. `del()` stays only for
  savefiles, clients, the world and the collector itself.
  Guard: `hard_del` in `scripts/check_forbidden_patterns.py`.
- **Whatever adds `src` to a list takes it out in `Destroy()`.** A global or
  owner list that still holds a deleted object keeps it alive: `qdel` cannot
  collect it, the collector falls back to a slow forced delete 30 seconds later
  and the list grows forever. Humans used to stay in `faction_hud_users` this
  way. Guard: `unpruned_global_list` in `scripts/check_forbidden_patterns.py`
  fails on a global list that gains `src` and is never removed from.
- **`Destroy()` must call `..()` and should null out the references it owns.**
  The base proc cancels the datum's timers and drops its weak reference;
  `SHOULD_CALL_PARENT` makes dreamchecker flag a missing call.
- **Hold another object you do not own through a weak reference.** Use
  `WEAKREF(thing)` and `resolve()` it when needed, or clear the field when the
  target is destroyed. Check `QDELETED(thing)` before using a reference that may
  have outlived its target, especially after any `sleep`, `spawn`, `do_after` or
  timer. Guard: `tests/weakref_ownership` (native).
- **Prefer `addtimer(CALLBACK(...))` or a `/process` to `spawn()`, and typed
  global lists to `in world` loops.** A sleeping `spawn()` cannot be cancelled
  and keeps its frame (and every reference in it) alive; `in world` walks every
  atom. Guard: `spawn` and `in_world` in `scripts/check_forbidden_patterns.py`
  (existing uses are capped per file; preflight fails on a new one and CI
  flags it).
- **Yield in long loops.** A loop over a whole map needs `TICK_CHECK` (or
  `PROCESS_TICK_CHECK` in a process) on every path, `continue` paths included,
  or the server stalls. Never walk a large savefile directory with `for(x in
  S.dir)`: it is quadratic.

Deeper notes live in the scoped guides:
[persistence](docs/agent-guides/persistence/README.md),
[runtime and memory](docs/agent-guides/runtime-memory/README.md) and
[GC triage](docs/gc-triage.md).

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
