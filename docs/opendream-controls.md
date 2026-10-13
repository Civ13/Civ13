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

The optional actual-engine check uses production request/reboot/whitelist bodies:

```
<python> scripts/opendream/verify-dm-controls.py --compiler <absolute-DMCompiler> --server <absolute-Robust.Server> --output <temporary-result.json>
```

It launches a disposable one-tile OpenDream world on loopback, then closes its
owned process. The ready marker gates direct request-file writes. Reusing a
copied temporary OpenDream file resource can retain old bytes, so requests must
not use `fcopy` from a reused temporary resource. The verifier reads the reboot
request from disk independently of DM's resource cache.

Local acceptance covered Nomads and Little Creek TDM readiness, repeated Topic
queries, owned-process restart, compiled map transitions, and two distinct OOC
file messages consumed by the game. Desert compilation succeeded but startup did
not reach readiness within the test window; that map is excluded from the local
allowlist. These checks do not establish all admin commands, graphical gameplay,
graceful persistence shutdown, or production parity. OpenDream builds retain
103 compatibility warnings; the native BYOND build has zero errors or warnings.

Game-originated map votes compile a pending map without stopping the current
world. The game's subsequent reboot hook commits it, preserving the round-end
countdown and save hooks. Explicit console `mapswap` switches immediately.
A second map change is rejected while a game map is pending. After a supervisor
crash, pending staged files require manual inspection along with its stale lock;
they are never automatically replayed by a new supervisor.

## Lifecycle operation receipts (review-stage)

Mutating CLI requests accept `--operation-id` (ASCII letters, digits, underscore,
hyphen; 1-80 characters). Reusing an ID with the same action, map, origin and
SHA256 of exact trusted profile bytes returns its original receipt. Changed
bindings reject. The digest is identity, not authentication; filesystem access
and the trusted profile remain the control boundary.

`operation-status --operation-id ID` is read-only and returns
`{ok:true,schema:"civ13.lifecycle.v1",operation_status:"pending"|"committed"|"not_found",receipt}`.
A committed receipt proves only completion of the owned process action. It does
not prove game initialization, Topic readiness, requested build or active map.
The separate `civ13.launch.v1` projection carries instance/profile/build/map/PID
and currently always declares `ready:false`. No game readiness integration is
claimed.

Each operation is published pending before effects, then committed before the
transport request is removed. A crash or unsuccessful effect leaves pending;
retry does not repeat it. An actual process crash can retain exclusive lock
files: operator recovery is required, never automatic PID discovery or replay.
There is a hard 256-receipt allocation limit. Nothing is automatically pruned,
including unresolved operations; full storage fails closed. File publication
flushes/fsyncs the temporary file and replaces it, but does not establish parent
directory power-loss ordering or a multi-file transaction.

Current acceptance is review-stage: injected crash/replay/history tests and owned
dummy-child tests run without any game. Deferred map stages are persisted with profile and content hashes. Fresh
controllers restore a validated staged map. An applying marker surviving interrupted
multi-file replacement quarantines controls for operator recovery. Active map
identity also binds the installed DME/JSON hashes and survives controller restart. No service activation
or new readiness endpoint is authorized by this change.

Run both focused suites with a verified Python interpreter:
`-m unittest discover -s tests -p 'test_opendream*.py' -v`.

Receipt inspection remains available when an interrupted map replacement
quarantines controls. This constructor mode skips map recovery only for the
read-only receipt query and rejects every process effect before writing another
pending operation. It never repairs or clears the interrupted map marker.

CivilizationBot opts into this protocol with `controls.lifecycle_schema` set to
`civ13.lifecycle.v1`; null preserves its original controller DTO. Its versioned
HTTP mutations require caller operation IDs and its recovery query never replays
an action. The versioned bot `tests/local/lifecycle-wire.py` imports this actual
OperationStore and verifies Python-produced receipts with the PHP adapter using
synthetic effects and temporary storage. No runtime activation is implied.

## Native identity launcher candidate

The local launcher no longer supplies `OpenDreamTester` or any other username.
It opens the client menu with the selected server address. The native-aware client
must read the logged-in BYOND account and native CID before connecting. Its account
display is read-only, and reconnecting must obtain a fresh native observation.

This source change depends on the native identity client/bridge candidate in
OpenDream PR #18. That candidate currently fails closed while the real observer,
channel handoff and server gate are incomplete. It is not an installed or playable
launcher update. Do not tell players to switch yet or change the published client
channel based on this launcher patch alone.

After the complete candidate has passed native login/CID parity and connection
acceptance and is published, players will need to install the supported BYOND
client, sign into their BYOND account there, update the Civ13 launcher, select a
server, and connect using the displayed BYOND account. They will not type a
username or give the Civ13 launcher their BYOND password. The native observer
can disconnect an existing native BYOND world; the completed launcher must tell
players before running that step. Final player instructions must match the
verified shipped flow.
