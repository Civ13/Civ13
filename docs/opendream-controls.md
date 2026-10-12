# Local OpenDream server controls

Native BYOND launchers remain unchanged. OpenDream has no DM `shell()` support,
so opt in using a trusted local profile and the Python supervisor instead of
calling the legacy DreamDaemon Python helpers.

Copy `scripts/opendream/profile.example.json` into ignored local configuration.
Use absolute trusted executable paths and a separate profile per server. The
OpenDream JSON directory is the DM file root: set `runtime_dir` to that directory,
not a sibling working directory. `SQL/`, `serverdata.txt` and durable game files
live there. Configure loopback bindings in the referenced server TOML. Game and
Topic ports must differ; `opendream.topic_port` must match the profile.

Run with a verified Python 3.10+ interpreter:

```
<python> scripts/opendream/control.py --profile <absolute-profile.json> start
<python> scripts/opendream/control.py --profile <absolute-profile.json> status
<python> scripts/opendream/control.py --profile <absolute-profile.json> topic-status
<python> scripts/opendream/control.py --profile <absolute-profile.json> restart
<python> scripts/opendream/control.py --profile <absolute-profile.json> mapswap NOMADS
<python> scripts/opendream/control.py --profile <absolute-profile.json> stop
```

Each CLI call prints one JSON response and exits nonzero on rejection. Status
reports `running`, `server_pid`, `game_port`, `topic_port`, and `runtime_dir`.
`topic-status` performs a bounded read-only standard BYOND TCP status request on
loopback using the separate Topic port. It requires a complete Civ13 JSON reply.
Process existence is not gameplay readiness. Check the status HTTP endpoint and
the DM Topic response separately before admitting clients. The supervisor owns
its child process only and does not discover or kill other servers. It does not
pull Git, activate Discord, or restart any official server.

Map IDs must be explicitly listed in the profile. A staged DME is compiled before
stopping the old server; compilation failure preserves the running world and
current DME/JSON. Switching maps and restarting do not implicitly save the world.
Complete the game's authorized save workflow first when preservation is needed.

OpenDream map votes and `world.Reboot()` submit fixed requests through
`SQL/opendream-control/game-request.json`. Results, including rejected map IDs,
are recorded in `game-result.json`; supervisor/server and compiler logs are in the
same directory. Unsupported script actions fail closed. Native DM shell controls
retain their existing behavior.

For CivilizationBot, use its explicit OpenDream adapter with the fixed argv above;
do not reuse legacy Host/Kill/Restart/MapSwap. Topic uses `topic_port`, game clients
use `game_port`, and file messaging uses `runtime_dir/SQL`. Profiles and spool
directories are trusted administrator configuration, not remotely writable input.
Discord commands must retain their existing authorization and local-only gates.

Requests are serialized and bounded. A timeout leaves the request in place: inspect
its matching receipt before any retry. An abandoned `supervisor.lock` prevents
restarting by guessed PID. After a supervisor crash, verify its server is stopped
manually before removing stale lock/request files. There is no automatic crash
recovery or game save guarantee. Controller shutdown is process termination,
matching the old launcher behavior rather than a graceful persistence transaction.

Offline control tests: `python -m unittest discover -s tests -p test_opendream_control.py -v`.
These launch only temporary dummy processes, never a game or external service.
