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
