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
Joining another region starts a new character there; moving a character and
their belongings between regions is not implemented yet.

Tests: `python3 -m unittest tests/gaia_host/test_shard_group.py` (fake
machine, no BYOND). A Linux smoke run with the pinned compiler on two test
maps (setup, update, start, status with both peers `UP`) passed on 2026-11-05.
