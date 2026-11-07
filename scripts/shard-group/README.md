# Region groups (sharded servers)

`shard_group.py` runs several Civ13 worlds on one host as one region group.
Each region is its own git worktree of the repository with its own selected
map, build (`region.dmb`), `config/` and `map_saves/`, so regions never share a
save, a lock or a lifecycle token. Nothing here touches the live server: port
1714 is refused, and the source checkout's own files are never changed.

```
python scripts/shard-group/shard_group.py --config group.json setup
python scripts/shard-group/shard_group.py --config group.json update
python scripts/shard-group/shard_group.py --config group.json start [--region ID]
python scripts/shard-group/shard_group.py --config group.json status
python scripts/shard-group/shard_group.py --config group.json stop|restart [--region ID]
```

- `setup` creates `<root>/<id>` as a detached worktree for every region and
  writes `config/shard_region.json` (the whole group, which region this is,
  and the local doorman's address: regions ask the doorman which peers sleep,
  because any connection to a frozen world wakes it, and a trail asks it to
  wake its destination before sending a traveller), `config/lifecycle-token.txt` and the region's host config. It refuses
  while any region is listening.
- `update` checks every region out at the group's `revision`, writes
  `region.dme` (civ13.dme with only the region's map selected) and compiles it.
  A map path inside the repository is used as is; an absolute path is copied to
  `maps/regions/<id>.dmm` in that region's worktree.
- `start` and `restart` fetch the group's remote first and run the region's
  `update` unless its last build (`data/shard-host/build.json`) is already of
  the group revision, so a region never runs a stale build. A region that was
  set up but never built is built by its first `start`.
- `start`, `stop` and `restart` reuse the host logic of
  [gaia-host](../gaia-host/README.md): one detached worker per action, progress
  in `data/shard-host/operation.json`, save-and-stop through the lifecycle
  topic and a verified backup of every save. Like Gaia, `stop` only saves a
  world that is playing and idle; a world still in the lobby is refused.
- `stage` builds the group revision beside each running region; see
  [staged builds](#staged-builds).
- `status` reports each region's host state, and for a listening region what
  it answers to the `shard_region` topic, including how it sees its peers
  (`UP`, `DOWN`, `MISMATCH`, `UNKNOWN`).

See [group.example.json](group.example.json). Required keys: `group`,
`repository`, `root` (outside the repository), `compiler`, `daemon`, `git`,
`public_host` (the address players use to join) and 1 to 16 `regions`, each
with a unique `id`, `name`, `kind` (`SURFACE`, `OCEANIC`, `UNDERGROUND`, `RAILYARD`, `RAID`
or `OTHER`; a `RAID` region cannot be the mainland), `port` and `map`. Optional: `revision` (default `HEAD`), `public`
(default false, so the worlds are not listed on the hub),
`save_timeout_seconds`, `start_timeout_seconds` and `backups_kept`.

In game, every region polls its peers once a minute and players see the group
with the OOC verb **Regions**, with join links for regions that are up.

With travel on, each player belongs to one region at a time (the home world
ledger in [tools/transfer_storage](../../tools/transfer_storage/README.md#home-worlds-one-land-per-player)).
New players, and players whose character died without an assigned bed in the
land they died in, start in the `mainland` region
(optional key, default the first region) and reach the others only by
travelling. Joining any other region shows where the character lives instead
of starting a new one.

## The live group (Gaia)

Gaia itself can be a region: set `"live": true` on its group, which allows
port 1714, and give that region `"public": true` so only it is listed on the
hub (a region's `public` overrides the group's). Optional keys for it:

- `overlay` (group or region, an absolute folder): copied over the region's
  worktree after every checkout, region last. It holds what git does not, such
  as `config/host.txt`, native DLLs and the host's own config settings. It must
  not contain `map_saves`, `data` or the files `setup` writes into `config/`.
  A file that already matches is not rewritten, so a DLL a running world loaded
  is left alone.

### Host config settings

The repository's `config/config.txt` is the default (and what a Linux host
deployed from master runs). A host keeps only its own lines in
`config/config.local.txt` inside an overlay, and every update merges them over
the checked-out `config.txt`, so new settings and changed defaults on master
still arrive:

```
# comments and blank lines are ignored
WEBHOOK_CAN_FIRE
WEBHOOK_KEY <key>
#SKIP_PERSISTENCE_SAVING
```

`KEY value` (or a bare `KEY`) replaces that setting's active line, else
uncomments its `#KEY` line, else is added at the end; `#KEY` turns the setting
off. The group overlay's file is merged first, then the region's, so put shared
settings in the group overlay and the webhook in Gaia's. The persistent-round
lines (`ALLOWED_GAMEMODES PERSISTENCE`, saving on) are still applied last.

- `config-apply [--region ID]` writes the overlays and the merged config into
  set-up regions without a checkout or compile (running regions too). A world
  reads `config.txt` when it starts, so a change takes effect at its next
  restart; `host.txt` is read at each login.
- `config-migrate` turns each overlay's whole `config/config.txt` (the old way)
  into a `config.local.txt` with only its differences from the repository's
  `config.txt` at the group revision, checks that the merge reproduces every
  setting, and keeps the old file as `config.txt.migrated`.
- `fetch` (a remote name such as `origin`): `setup`, `update` and
  `check-update` run `git fetch` there once first, so `revision` can be
  `origin/master`.

`adopt --region gaia --from D:/GitHub/Civ13` moves a stopped standalone server
into a region that has no save yet: it copies `map_saves` (checking each
file's SHA-256) and the runtime state outside it (`SQL/`, player notes, memos,
faction symbols, reputation and extraction data). The source is not changed.
`check-update [--region ID]` prints one JSON line for the launcher's update
panel (`component`, `current`, `available`, `behind`, `can_update`, `reason`,
plus `regions`); it fetches but never merges or touches a world. The Windows
walkthrough is in [scripts/windows/host](../windows/host/README.md).

## Sleeping regions

Regions sleep like Gaia: run the host service
`gaia_host.py --group group.json serve` (see
[gaia-host](../gaia-host/README.md#one-host-service-for-gaia-and-region-groups)).
It freezes an empty region once it has saved, wakes it on a connection or a
launcher request, cold-starts it from its save after a power-down, and keeps
the transfer agents and coordinator running. `status` shows each region's
`state` (`awake`, `asleep`, `cold` or `stopped`); `freeze` and `thaw` do it
by hand. Sleep settings such as `freeze_idle_minutes` can be set once in the
group config.

Regions ask the doorman which peers sleep, and ask it to wake one, over HTTP
(`GET /?host_status=1`) through rust_g. `world.Export("byond://...")` cannot
reach the doorman: it opens a BYOND world handshake that only DreamDaemon
answers.

## Two public ports (routing relay)

Set `relay_port` (0 = off) to put every region behind two public ports: the
gate region's own port (`gate`, the mainland by default) and the relay port.
Forward only those two on the router; the other region ports and every agent
port stay closed. `relay_control_port` (default `relay_port + 1`) is loopback
only; `relay_bind` (`0.0.0.0`) and `relay_capture` (false) are optional. Setup
writes `relay`, `relay_control` and `gate` into each region's
`shard_region.json` and the group token into `config/relay-token.txt`; the host
service starts `relay.py` with the other helpers.

- A player joins the gate directly, so it sees their real address. If the
  coordinator says their character lives elsewhere, the gate wakes that region,
  writes a route for the player's address on the relay and links them to the
  relay port. Admins stay at the gate with a Go there link.
- A trail, a raid reset, the Regions panel and the home notice route the player
  the same way from whichever region they are in.
- A region reached through the relay sees no client address; it asks the relay
  for the address it routed for that key, and bans, login logs and the alt
  check use it (`client.public_address()`). Local-only admin verbs use
  `client.local_connection()`, which is false for a relayed player.
- A player behind the same address as someone heading elsewhere at the same
  moment can land in the wrong region (routes are per address, last write
  wins); the region's Join check then offers the way to their home.

Not yet measured on a real host: whether Dream Seeker reconnects through the
relay after `link()` and a world reboot, and what its first packet looks like
(`relay_capture` logs it). A routed player who connects with DreamDaemon instead
of Dream Seeker reaches a region as a loopback Topic caller; token-checked
Topics (agent control, lifecycle) stay closed, but the Topic rate limit does
not apply to them.

## Travel between regions

Travel is off unless every region has a `transfer_port` (a free loopback
port, unique in the group, never 1714). Then:

- `setup` writes each region's `config/transfer-token.txt` and
  `config/transfer_agent.json`, with every other region as a peer.
- `start` launches the region's transfer agent
  ([tools/transfer_storage](../../tools/transfer_storage/README.md)) before
  DreamDaemon, enrolled both ways with every peer, and starts one
  coordinator for the group (`<root>/coordinator.pid`).
- `status` shows each region's `transfer_agent` and the group's
  `coordinator`.

The same agents and coordinator carry cross-region radio once players build
and key long-range radio relays on both sides; see
[docs/cross-shard-radio.md](../../docs/cross-shard-radio.md). No extra
service is needed.

A character trip completes in seconds: each region's agent journals the
departure and the arrival as soon as it records them. A region that reloads a
save made before a trip replays that trip from its journal, so a crash can
neither bring the traveller back nor lose them. A world save that lists a trip
clears it from the journal, so the group still keeps saves regular:

- `save_minutes` (default 15, 1 to 1440) is the longest gap between autosaves.
- `travel_save_seconds` (default 60) is how soon a region saves after
  someone leaves through a gate.
- `persistent` (default true) makes `update` set `ALLOWED_GAMEMODES
  PERSISTENCE` and comment out `SKIP_PERSISTENCE_SAVING` in each region's
  `config/config.txt`. Without saves the journal only grows, and goods sent
  through trade posts (which still wait for saves) never arrive.
- A save of a 155x225 map takes over a minute, so keep `save_minutes` at 5 or
  more. Gates refuse travel while their region is saving.
- A `RAID` region may set `reset_minutes` (0 = never, or 30 to 1440). It
  never saves (`SKIP_PERSISTENCE_SAVING` stays on, `save_minutes` 0). Each
  boot loads a fresh map and adopts the agent's ledger. Before each reset
  the world confirms the cycle's trips and removes everyone still inside,
  whose home goes back to the land they came from. See
  `docs/persistence-raids.md`.

Other optional keys:

- `python` is the interpreter for the agents and the coordinator (default:
  the one running the script).
- `rust_g` is a rust_g library copied into each region on `update` (needed on
  Linux).
- `systemd_scope` (Linux, `""` by default) set to `"user"` or `"system"` starts
  each region's DreamDaemon through `systemd-run --scope` as unit
  `civ13-<group>-<region>`, so every world has its own cgroup: `systemctl
  status` and memory accounting per world, and a world can be stopped alone.
  Use `"user"` when the host service runs as a user unit, `"system"` when it
  runs as a system unit with the right to create scopes.

Players travel through an admin-placed `/obj/structure/region_gate`, with its
`destination` set to a peer's region id; see
[region_travel.dm](../../code/modules/persistence/region_travel.dm). The
character arrives at a gate in the destination, or at a late-join point when
the destination has no gate. Its owner gets it back on joining that server.

Tests: `python3 -m unittest tests/gaia_host/test_shard_group.py` (fake
machine, no BYOND). A Linux smoke run with the pinned compiler on two test
maps (setup, update, start, status with both peers `UP`) passed on 2026-11-05.
A two-region travel run passed on 2026-11-05 on two generated playable maps
(before trips were journaled).
A Nomad left through a gate and arrived in the other region about 2.5 minutes
later, with name, owner, clothes and coins. The transfer settled on both agents
after the destination saved, and there were no runtime errors.

## Staged builds

`stage [--region ID]` builds the next update while the regions keep running, so
players are not kicked for a compile. For each region it fetches, resolves the
group `revision` and, unless the region already runs that build, checks it out
in a second worktree, `<root>/.staging/<id>`, with the same overlays, config
and `region.dme` as `update`, and compiles it at below-normal priority. Regions
take turns (`<root>/.staging/compile.lock`), so a deploy never compiles every
region at once. Progress is in `data/shard-host/stage.json` (`phase` is
`ready`, `current` or `failed` with `error`) and `status` shows it under
`stage`, with `pending` true while a ready build is newer than the running one.

The host service (`gaia_host.py serve`) installs a ready build by itself:

- an awake region that is empty and has saved since its last player (the moment
  it would otherwise go to sleep) is restarted, and its `update` copies
  `region.dmb` and `region.rsc` from the staging worktree instead of compiling;
- an asleep region is stopped (it saved before it froze) and a cold one is
  updated the same way, so its next wake starts on the new build.

A staged build is never installed over a newer build, and an `update` of any
other revision compiles as before. `auto_stage_minutes` (group key, 0 = off)
runs `stage` on that interval; with `revision: origin/master` and `fetch:
origin`, merged changes then reach each region the next time it is empty.

## Player help ("Ask for help")

With a `player_help` key, the host service (`gaia_host.py serve`) also keeps
one Player Help bridge per region running, so help starts with the host:

```json
"player_help": {"config": "D:/GitHub/Civ13/data/player-help-config.json", "regions": ["gaia", "railyard"]}
```

`regions` defaults to every region. Each bridge is the region's own
`scripts/player_help_bridge.py --game-root <region> --config <config>`, run with
the group `python` and `--stop-file <root>/player-help/stopped`, logging to
`<root>/player-help/<id>.log`. Every half minute a region without a live bridge
(its `SQL/player-help/worker.lock` names a dead pid, or there is none) gets one,
after a lock left by a dead bridge is removed. One region that cannot start its
bridge does not keep the others down.

- `help-status` prints each region's `running`, `pid`, `enabled`, `log` and
  `heartbeat_age_seconds` (how old its `health.json` is), and whether help is
  `stopped` on request.
- `help-stop` writes the stop file, waits up to 60 seconds for the bridges to
  finish their answers and exit, then ends any still running (a bridge started
  without the stop file never sees it). The host service leaves them stopped.
- `help-start` removes the stop file and starts the missing bridges at once.

The launcher's **Player help** tab shows this status and has Start and Stop.
Run only one supervisor per region: a bridge started some other way still holds
the region's lock, so the host service leaves it alone, but it is not restarted
when it exits and ignores the stop file until it is ended.
