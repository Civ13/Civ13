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
| `freeze` | Only with no clients online and the world ready and not busy: suspends the dd.exe that listens on the port (and trims its memory to the pagefile). The same process keeps every object exactly as it was. Answers at once. |
| `thaw` | Resumes the frozen process. `stop`, `restart` and `update` thaw first on their own. |
| `watch` | Runs until killed: freezes the server after `freeze_idle_minutes` with no clients and thaws it within about a second when a connection from an address outside `wake_ignore` reaches the port. Prints one JSON line per freeze or thaw. |

Every action except `status` prints `{"ok": true, "accepted": true, ...}` within
seconds and continues in a detached worker. Its progress (`phase`, `error`,
`generation`, `backup`) is in `<state_dir>/operation.json`; `status` shows it.
One action runs at a time. A refused action prints `{"ok": false, "refused": ...}`,
exits 1 and changes nothing.

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
- Optional config keys: `freeze_idle_minutes` (15), `freeze_trim_memory`
  (true), `wake_ignore` (`["127.0.0.1", "::1"]`).

