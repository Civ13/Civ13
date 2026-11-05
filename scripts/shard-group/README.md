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
  writes `config/shard_region.json` (the whole group plus which region this
  is), `config/lifecycle-token.txt` and the region's host config. It refuses
  while any region is listening.
- `update` checks every region out at the group's `revision`, writes
  `region.dme` (civ13.dme with only the region's map selected) and compiles it.
  A map path inside the repository is used as is; an absolute path is copied to
  `maps/regions/<id>.dmm` in that region's worktree.
- `start`, `stop` and `restart` reuse the host logic of
  [gaia-host](../gaia-host/README.md): one detached worker per action, progress
  in `data/shard-host/operation.json`, save-and-stop through the lifecycle
  topic and a verified backup of every save. Like Gaia, `stop` only saves a
  world that is playing and idle; a world still in the lobby is refused.
- `status` reports each region's host state, and for a listening region what
  it answers to the `shard_region` topic, including how it sees its peers
  (`UP`, `DOWN`, `MISMATCH`, `UNKNOWN`).

See [group.example.json](group.example.json). Required keys: `group`,
`repository`, `root` (outside the repository), `compiler`, `daemon`, `git`,
`public_host` (the address players use to join) and 1 to 16 `regions`, each
with a unique `id`, `name`, `kind` (`SURFACE`, `OCEANIC`, `UNDERGROUND` or
`OTHER`), `port` and `map`. Optional: `revision` (default `HEAD`), `public`
(default false, so the worlds are not listed on the hub),
`save_timeout_seconds`, `start_timeout_seconds` and `backups_kept`.

In game, every region polls its peers once a minute and players see the group
with the OOC verb **Regions**, with join links for regions that are up.
Joining another region this way starts a new character there.

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

A trip is only final once both regions have saved, so the group keeps saves
frequent:

- `save_minutes` (default 15, 1 to 1440) is the longest gap between autosaves.
- `travel_save_seconds` (default 60) is how soon a region saves after
  someone leaves through a gate.
- `persistent` (default true) makes `update` set `ALLOWED_GAMEMODES
  PERSISTENCE` and comment out `SKIP_PERSISTENCE_SAVING` in each region's
  `config/config.txt`. Without saves, no trip ever completes.
- A save of a 155x225 map takes over a minute, so keep `save_minutes` at 5 or
  more. Gates refuse travel while their region is saving.

Other optional keys:

- `python` is the interpreter for the agents and the coordinator (default:
  the one running the script).
- `rust_g` is a rust_g library copied into each region on `update` (needed on
  Linux).

Players travel through an admin-placed `/obj/structure/region_gate`, with its
`destination` set to a peer's region id; see
[region_travel.dm](../../code/modules/persistence/region_travel.dm). The
character arrives at a gate in the destination, or at a late-join point when
the destination has no gate. Its owner gets it back on joining that server.

Tests: `python3 -m unittest tests/gaia_host/test_shard_group.py` (fake
machine, no BYOND). A Linux smoke run with the pinned compiler on two test
maps (setup, update, start, status with both peers `UP`) passed on 2026-11-05.
A two-region travel run passed on 2026-11-05 on two generated playable maps.
A Nomad left through a gate and arrived in the other region about 2.5 minutes
later, with name, owner, clothes and coins. The transfer settled on both agents
after the destination saved, and there were no runtime errors.
