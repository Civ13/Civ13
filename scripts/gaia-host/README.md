# Gaia host control

`gaia_host.py` starts, saves and stops, restarts and updates a Civ13 server
that runs from a Windows scheduled task, the way live Gaia is hosted. The
Discord bot and the launcher both call it, so there is one control path.

```powershell
py -3 scripts/gaia-host/gaia_host.py --config D:/private/gaia-host.json status
py -3 scripts/gaia-host/gaia_host.py --config D:/private/gaia-host.json start
```

| Action | What it does |
| --- | --- |
| `status` | Prints the port state, the last action's progress and, when the world answers, ready/busy/players/map/save. Changes nothing. |
| `start` | Checks `map_saves` (empty for a fresh world, or a complete save whose marker, `round.json`, `map.txt` and level files agree; a restart intent must belong to that save), writes `config/lifecycle-revision.txt` from git HEAD and runs the scheduled task. |
| `stop` | Asks the running world to save and shut down through its authenticated lifecycle topic, waits for the port to close, then copies `map_saves` to `<state_dir>/backups/<operation>` and checks every file's SHA-256. The newest `backups_kept` copies are kept. |
| `restart` | `stop`, then `start`. |
| `update` | Only while stopped: `git fetch` and a fast-forward merge of the branch, then `dm.exe civ13.dme`, which must report 0 errors. |
| `freeze` | Only with no clients online and the world ready and not busy: suspends the dd.exe that listens on the port (optionally trimming its memory to the pagefile). The same process keeps every object exactly as it was. Answers at once. |
| `thaw` | Resumes the frozen process. `stop`, `restart` and `update` thaw first on their own. |
| `watch` | Runs until killed: freezes the server after `freeze_idle_minutes` with no clients and thaws it within a fraction of a second when a connection from an address outside `wake_ignore` reaches the port. Prints one JSON line per freeze or thaw. |
| `check-update` | Fetches `origin/<branch>` and prints `current`, `available`, `behind`, `can_update` and `reason` for the launcher's update panel. Never merges or touches the world; `can_update` is false while the server runs. |
| `serve` | Runs until killed: does `watch` for every config given (`--config a.json --config b.json`, one per game port) and for every region of each `--group group.json`, and runs the doorman on `doorman_port`. Use it instead of `watch`. |

Every action except `status` prints `{"ok": true, "accepted": true, ...}` within
seconds and continues in a detached worker. Its progress (`phase`, `error`,
`generation`, `backup`) is in `<state_dir>/operation.json`; `status` shows it.
One action runs at a time. A refused action prints `{"ok": false, "refused": ...}`,
exits 1 and changes nothing.

`status` reports a `state`: `awake` (running), `asleep` (frozen in memory),
`cold` (down after a power-down, starts from its save when woken) or `stopped`
(down on purpose; wakes are refused).

## Setup

1. Copy `gaia-host.example.json` outside the repository and set its paths.
2. Create `config/lifecycle-token.txt` in the game folder with 32 random
   lowercase hex characters (it is git-ignored), for example
   `py -3 -c "import secrets; print(secrets.token_hex(16))" > config/lifecycle-token.txt`.
   The world reads it at each lifecycle request; only `127.0.0.1` peers are accepted.
3. Keep the scheduled task's action as today:
   `dd.exe civ13.dmb 1714 -trusted -public -close -ip 0.0.0.0 -log logs/world.log`.
   `-close` makes DreamDaemon exit when the world shuts down after saving.

Callers pass only the action name. Paths, commands and the task come from the
config file. Tests: `python3 -I -B -m unittest discover -s tests/gaia_host -p 'test_*.py'`.

## Freezing while nobody plays

While frozen, BYOND's world.time stops, so the world does not age: crops,
seasons and animals pause until someone connects. The wall clock keeps
running, and the world shifts its own wall-clock schedules when it wakes
(`code/_helpers/wall_clock.dm`): the periodic save moves forward by the frozen
time, so the first player does not land in a save, and the timer subsystem's
midnight count stays right after a freeze of any length. Real-world cooldowns
such as bans, respawn and faction timers keep counting.

A player who connects to a frozen server waits in the TCP backlog until the
watcher thaws it, then logs in normally. Things to know before running `watch`:

- The BYOND hub drops the server from its list while it is frozen, so players
  who browse the hub will not see it. Direct `byond://` links, the launcher's
  saved server and Discord links still work and wake it.
- Status pollers on this machine (the Discord bot) connect from 127.0.0.1 and
  are in `wake_ignore`, so they do not keep the server awake. Their status
  topics wait or time out while it is frozen; `status` here reports `frozen`.
- Run `watch` as the same Windows user as dd.exe, without less privilege than
  it (a non-elevated watcher cannot suspend an elevated dd.exe).
- While frozen, `watch` reads the TCP table (GetExtendedTcpTable, with
  `netstat` as a fallback) every `wake_poll_seconds`. The launcher waits up to
  12 seconds for a status reply once connected, so a wake must finish within
  that. `freeze_trim_memory` hands the frozen process's memory to the pagefile;
  it stays off by default because paging Gaia back in can outlast that wait.
- Optional config keys: `freeze_idle_minutes` (15), `freeze_trim_memory`
  (false), `wake_ignore` (`["127.0.0.1", "::1"]`), `wake_poll_seconds` (0.2).

## The doorman (`serve`)

`serve` adds a small always-on status service so the Civ13 launcher can list a
frozen server without waking it. It listens on TCP `doorman_port` (1713) on
`doorman_bind` (`0.0.0.0`); forward that port on the router like the game
ports. It speaks BYOND Topic framing and answers only:

- `?host_status=1`: every instance's port, state (`awake`, `asleep`, `waking`,
  `stopped`), `wake_estimate_seconds`, and the players, map and mode the world
  last reported with their age. Awake worlds are asked for `status` from
  127.0.0.1 every 30 seconds, which does not keep them awake.
- `?wake=1&port=1714`: thaws that instance, unless the machine has less than
  `wake_min_free_mb` (1024) of physical memory free, after first stopping the
  longest-asleep other world to make room (see below); then it stays asleep and
  the launcher tells the player the host is low on memory (0 turns the check
  off; a direct connection to the game port still thaws it). One wake per
  address every 30 seconds; all requests are limited to 40 per address per minute and 16 open
  connections.

### Low-memory eviction

While less than `evict_below_free_mb` (1024; 0 turns it off) of physical memory
is free, `serve` stops the longest-frozen world, at most one a minute. A wake
that is short of memory does the same for the other worlds first. Only a world
that saved before it froze (`freeze_requires_save`) is stopped; it becomes cold
(below) and starts from that save on its next wake.

### Surviving a power-down

A frozen process does not survive the machine shutting down, so `serve` and
`watch` only freeze a server once `map_saves/save_complete.txt` is newer than
the last time a client was seen (`freeze_requires_save`, on by default). The
world saves itself when it empties; until that save completes the server stays
awake, and a refused or failed save just keeps it awake until a later save
lands. The time of the last client is kept in `<state_dir>/activity.json`.

If the frozen process is gone when `serve` next looks (the machine rebooted or
dd.exe was killed) and nothing listens on the port, the instance becomes cold
(`<state_dir>/cold.json`). It still shows as asleep in the launcher, with
`cold_start_estimate_seconds` (300) as its wait, and the next wake request runs
the ordinary `start` action, which loads that save. A cold start needs
`cold_start_min_free_mb` (2560) of free memory, since loading peaks far above a
thaw, and an action lock left by the power-down is cleared first. A save that
fails `start`'s checks keeps the server down. On Windows, `start` (and so a
cold start) also refuses while the BYOND pager (byond.exe) is not running in the
same logon session, since `-public` needs the host's BYOND account signed in
(`start_requires_byond_pager`, on by default); the launcher tells the player the
host is not signed in. Put the BYOND pager in the Startup folder with "remember
me" so it signs in at logon. Run `serve` from a scheduled task
that starts at boot so the launcher can see and wake the instance.

The launcher lists asleep servers from this cache and offers "Wake and join":
it wakes the server, waits until the doorman reports it awake, then checks the
game port directly and joins. The doorman never forwards game traffic, so bans
and logs still see each player's own address. Without the doorman (plain
`watch`), the launcher still works: its direct status check wakes the server.

## One host service for Gaia and region groups

`serve` is the host service: run one per machine, and give it every world on
that machine. `--group` takes a [region group](../shard-group/README.md) config
and serves each of its regions like Gaia: freeze after idle and a save, thaw on
a connection or a launcher wake, and a cold start from the save after a
power-down. A region starts DreamDaemon directly (agent first), so it needs no
scheduled task; only a hub-listed (`public`) group needs the BYOND pager. Sleep
settings set in the group config (`freeze_idle_minutes`, `wake_min_free_mb`,
`cold_start_estimate_seconds` and the other keys above) apply to all its
regions; with only `--group` and no `--config`, the doorman port and bind come
from the first group.

Every 30 seconds the service also starts any of the group's transfer agents or
its coordinator that is not running. They stay up while their region sleeps or
is cold, so travellers to it are journaled and handed over when it wakes.

```powershell
py -3 scripts/gaia-host/gaia_host.py --config D:/Civ13-host/gaia-host.json --group D:/Civ13Regions/europe.json serve
```

On Windows, add `--group ...` to the existing `Civ13 Gaia Doorman` scheduled
task's arguments. On Linux, see [civ13-host.service.example](civ13-host.service.example).
`shard_group.py status` shows each region's `state` and never asks a frozen
region for its view, and `shard_group.py freeze|thaw [--region ID]` does a
one-off freeze or thaw.

A region's own `data/shard-host/host.json` (written by `shard_group.py setup`)
can be passed as `--config`: it is driven as that region (DreamDaemon started
directly, its agent first). Point the bot's `gaia_host` option and the
launcher's `control.config` at it once Gaia runs as a region.

