# Optional Ollama gameplay help

Players use **Help! > Ask for help**. It opens a question dialog, then a private
answer window. The prompt warns that the question goes to the server owner's AI
service and should not contain personal information. Answers can be wrong. The
Crafting Atlas and player wiki remain available without an AI service.

Without configuration, a running bridge, or a fresh heartbeat, players see an
unavailable/configuration notice. An unanswered request times out after 60
running-server seconds and releases its slot. Failed or empty model answers
show an explicit notice rather than a blank window. Wait until the bridge has
published two heartbeats (normally a few seconds) before trying the first question.

## Owner setup

The game never performs model HTTP calls. A separately supervised Python 3.10+
worker exchanges small local files under `SQL/player-help`. This supports native
BYOND 516.1681 and OpenDream without rust-g or shell execution in the game.
Run one worker per game directory, with the same OS user as the game or suitable
private directory permissions. Do not share a spool across Nomads and TDM.

1. Install an Ollama model on your own Ollama host. This integration does not
   download a model, expose the host, or change its network configuration.
2. Copy `config/player-help.example.json` to an **untracked private file**, for
   example `data/player-help-config.json`. Set `enabled` to `true`, your remote
   `ollama_url`, and the installed `model`. Use either an origin such as
   `https://ollama.example.net` or its `/api/chat` URL. The service follows the
   [Ollama chat API](https://docs.ollama.com/api/chat), with streaming disabled.
3. Set `timeout_seconds` to 1..45 and `workers` to 1..2. The game permits eight
   outstanding questions, one per client, and a 30-second per-client cooldown.
   Questions are limited to 500 characters; answers to 4,000. Slow remote
   inference can fill these slots, in which case players receive a busy notice.
4. For a protected HTTPS proxy, put its bearer token in the worker's private
   `CIV13_OLLAMA_TOKEN` environment variable (or change `auth_token_env`). Never
   put credentials in a URL, tracked config, player text, or public service logs.
   HTTP is appropriate only across a trusted private connection; HTTPS protects
   questions and tokens over other networks. The worker disables redirects and
   ambient HTTP proxy settings so requests go only to the configured endpoint.
5. Launch the worker below and keep it supervised. Configuration is read at
   launch; restart the worker after changing it. Shutdown marks help unavailable.
   Restart clears old spool questions rather than re-sending them. Do not run
   multiple workers against the same spool.

The worker atomically claims `SQL/player-help/worker.lock`; a second instance
refuses to start. After an abrupt crash, confirm that the PID in `worker.lock/pid`
is no longer the bridge process before removing that exact stale lock directory.
Never remove an active worker's lock to start a competing instance.

Windows PowerShell (replace the interpreter and game paths with yours):

```powershell
& 'C:\Python312\python.exe' 'D:\Civ13\scripts\player_help_bridge.py' --game-root 'D:\Civ13' --config 'D:\Civ13\data\player-help-config.json'
```

For unattended Windows hosting, use Task Scheduler with the same executable and
arguments, the game directory as **Start in**, restart on failure, and a private
service account environment. The script does not need Administrator privileges.

Example Linux systemd unit `/etc/systemd/system/civ13-player-help.service`:

```ini
[Unit]
Description=Civ13 optional gameplay help
After=network-online.target
[Service]
User=civ13
WorkingDirectory=/srv/civ13
ExecStart=/usr/bin/python3 /srv/civ13/scripts/player_help_bridge.py --game-root /srv/civ13 --config /srv/civ13/data/player-help-config.json
EnvironmentFile=-/etc/civ13-player-help.env
Restart=on-failure
RestartSec=5
TimeoutStopSec=50
UMask=0077
[Install]
WantedBy=multi-user.target
```

Use `systemctl daemon-reload` and `systemctl enable --now civ13-player-help` after
adjusting paths/user. If used, protect `/etc/civ13-player-help.env` with mode 600.
Stop/disable the unit or set `enabled: false` and restart it to disable AI help.
The bridge does not start, stop, or restart game servers.

## Knowledge and privacy

`UI/player-help.json` is a small, explicitly reviewed **player-safe** guide.
It covers atlas use, winter/wetness and external bandaging. Expand it with
documented player mechanics as needed, keeping secrets, admin tools, hidden
loot tables and implementation notes out. Do not point it at arbitrary source
trees or internal documentation. Unknown questions should be referred to the
wiki/atlas; the worker does not assume exact unlocks for the current map.
The worker also loads a bounded projection of the existing player-facing
`UI/crafting-atlas.json` once at launch. Only recipe names, system, quantities,
inputs, outputs and conditions are retained; source locations and sprite metadata
are omitted. At most six matching guide/recipe entries and 8,000 context characters
are sent per question. Unmatched or truncated recipe details must be checked in
the atlas, including current map and research availability.

Only question text and the approved guide are sent. No account name, inventory,
chat history, filesystem, developer MCP tools or administration API is exposed.
There is no conversational memory, command execution or tool calling. Questions
are temporary spool files, removed when completed, disconnected or timed out;
the remote service may keep its own logs, so owners should disclose its policy.
Model text is rendered as escaped text, never executable HTML or links.

The worker is separate from the developer MCP server: player requests do not
receive developer tools. Do not expose MCP credentials to the worker.

## Verification

```sh
python3 -m unittest discover -s tests/player_help -v
python3 tests/player_help/run.py --byond-bin /path/to/byond/bin
```

These use temporary storage and an injected fake network transport. They verify
disabled/failure paths, stale request identity, output bounds, escaped rendering,
heartbeat expiry and cleanup. They do not contact your remote Ollama host or
prove its model is installed, reachable or knowledgeable. After configuring,
ask a harmless known question in-game; confirm an answer and then stop the worker
to confirm the unavailable notice. This live smoke check is owner-controlled.
