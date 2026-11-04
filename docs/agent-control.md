# Agent control

Agent control lets LLMs, scripts and other agents observe and run a Civ13
server over world/Topic: read status and players, read and edit variables, call
procs and admin verbs, message players, and play characters. It is off unless
the host creates `config/agent-control.txt`.

Code: `code/modules/agent_control/`. Client, MCP server and Ollama autopilot:
`tools/agent-control/`. Tests: `tests/agent_control/`.

## Security model

- **Off by default.** Without `config/agent-control.txt` (git-ignored) or with
  no `agent` line, every request gets `{"ok": false, "error": "disabled"}`.
  See `config/agent-control.example.txt`. The file is re-read when it changes,
  so adding or removing an agent needs no restart.
- **Authentication.** Each request names an agent and carries its token
  (32-128 URL-safe characters). Tokens are compared without early exit and never
  logged. The request is routed in `/world/Topic` before the generic Topic log,
  so its query string is not written to the diary either.
- **Network.** Only `127.0.0.1` is accepted unless the file adds
  `allow_address` lines. Topic traffic is plain text, so use an SSH tunnel
  rather than exposing the port. Five failed authentications from an address
  lock it out for ten minutes. Each agent is limited to 30 requests a second.
- **Scopes.** An agent gets only the scopes listed on its line:

  | Scope | Actions |
  | --- | --- |
  | `observe` | `discover`, `status`, `players`, `inspect`, `look`, `find`, `logs`, `job` |
  | `vars_read` | `get_vars` |
  | `vars_write` | `set_var` |
  | `call_proc` | `call_proc` |
  | `admin_verbs` | `list_verbs`, `call_verb` (further limited by the agent's rights) |
  | `message` | `announce`, `admin_pm`, `narrate`, `asay` |
  | `moderation` | `kick` |
  | `server` | `start_round`, `restart` |
  | `spawn` | `spawn_atom`, `delete_atom` |
  | `characters` | `character_spawn`, `character_list`, `character_observe`, `character_act`, `character_queue`, `character_release` |
  | `*` | everything |

- **Audit.** Every mutating action is written to the admin log as
  `AGENT <name>: ...` (with old and new values for `set_var`, and arguments for
  procs and verbs) and shown to online admins, except announcements and
  individual character steps. Reads and character movement go to the game
  log. Agents can read the admin log back with `logs`.
- **Protected state.** Agent control's own objects (the controller, agent
  identities, proxies and their admin holders, jobs) cannot be read, edited or
  have procs called on them, and `get_vars`/`set_var` never touch the globals
  `agent_control` and `agent_characters` or any `token`, `address`,
  `computer_id` or `lastKnownIP` variable, whatever scopes an agent holds.
- **Guards kept.** `set_var` refuses `VVlocked` variables plus `type`,
  `parent_type`, `vars`, `ckey`, `key`, `computer_id` and `lastKnownIP`.
  `kick` refuses admins. `delete_atom` refuses mobs with a connected player.
  `restart` needs `confirm: true` and is refused during saves and recovery;
  `world.Reboot` keeps its own persistence guards.

`call_proc`, `call_verb` and `set_var` are as powerful as the matching admin
tools (Advanced ProcCall and View Variables). Grant them only to agents you
would trust with host rights.

## Protocol

Send a Topic request to the world port:

```text
?agent_control=1&agent=<name>&token=<token>&action=<action>&args=<url-encoded JSON object>&request_id=<optional, up to 64 chars>
```

The reply is JSON: `{"ok": true, "action": ..., "result": ...}` or
`{"ok": false, "error": "<code>", "detail": "..."}`. Error codes include
`disabled`, `address_not_allowed`, `locked_out`, `unauthorized`,
`rate_limited`, `unknown_action`, `forbidden`, `invalid_args`, `bad_target`,
`not_found`, `locked_var`, `cooldown`, `runtime_error` and
`response_too_large` (replies are capped at 60 000 bytes; narrow the request).

### Targets and values

A `target` is `world`, `global`, `global:<var>` (for example `global:ticker`
or `global:map`), a ref such as `[0x2000017]`, `ckey:<ckey>` (that player's
mob), `client:<ckey>` or `turf:x,y,z`.

Values sent as arguments or new variable values are JSON scalars or one of
`{"ref": "[0x...]"}`, `{"type": "/obj/item"}`, `{"ckey": "name"}`,
`{"turf": [x, y, z]}`, `{"text": "..."}` and `{"list": [...]}`. Returned objects
look like `{"ref", "type", "name", "x", "y", "z"}`; lists report `list_len`
and at most 64 entries, two levels deep.

### Procs and admin verbs

`call_proc` and `call_verb` run with `usr` set to a hidden proxy mob for the
agent. `check_rights` grants that mob exactly the rights on the agent's line,
so verbs behave as they would for an admin with those rights. A call that
finishes at once returns its result; one that sleeps returns `{"job": id,
"done": false}`, and `job` fetches the result later. Text a verb sends to
`usr` comes back in `output`.

Verbs that ask questions with `input()` or `alert()` get no answer and usually
stop; pass arguments where the verb declares them, or use `set_var` and
`call_proc`. Verbs that read `usr.client` fail with a `runtime_error` naming the
file and line. `list_verbs` lists what the agent's rights allow.

## Characters

Agents can play characters through ordinary mob actions, so normal range,
cooldown, combat and crafting rules apply.

- **Host characters without a ckey.** `character_spawn` creates a mob (default
  `/mob/living/human`) owned by that agent, up to `max_characters` (default 4).
  Humans still get their usual map identity; a `name` is applied after it.
- **Player handover.** With `allow_handover` in the config, players get a
  **Toggle AI Control** verb (OOC). After they confirm, any agent with the
  `characters` scope can drive that character until the player uses the verb
  again or an agent releases it. The player's own input keeps working.

`character_observe` returns the character's state (health, hands, intent,
nutrition, water, worn items), the four neighbouring turfs, up to 64 visible
objects with `dx`/`dy` offsets and refs, and the messages the character saw or
heard (after normal language scrambling) since the `since` id.
`character_act` takes `do`: `move` and `face` (`dir`), `say` and `emote`
(`text`), `click` (`target` ref the character can see, optional `modifier`),
`use` (the held item), `drop`, `swap_hand`, `intent` (`help`, `disarm`, `grab`,
`harm`) and `resist`. Actions run with `usr` set to the character.
A direct `character_act` that is still cooling down fails with `cooldown` and
the ticks to wait. Cooldowns are the character's movement delay, the mob's own
click cooldowns (`next_move`, `next_click`) and one second between `say` or
`emote`.

`character_queue` takes a plan of up to 32 `actions` (64 pending per
character), each shaped like `character_act` arguments, plus
`{"do": "wait", "ticks": 1-600}`. Every step is validated before any is queued.
The server runs them in order, waiting out each cooldown, at most one step per
tick, so one request replaces many polled ones and the request rate limit is
not spent on retries. A failed step skips the rest unless `stop_on_failure` is
false. `clear: true` cancels pending steps. `character_observe` reports the
queue as `pending`, `running` and `results` with ids above `queue_since`.
Queued steps are logged like direct ones; releasing a character, or removing
its agent from the config, stops its queue. Movement waits for the mob's
movement delay and is logged to the game log; other character actions reach
the admin log.
Controlled characters are not treated as SSD.

## Tools

Credentials come from the environment, never from arguments:
`CIV13_AGENT_NAME`, `CIV13_AGENT_TOKEN` (or `CIV13_AGENT_TOKEN_FILE`),
`CIV13_HOST` (default `127.0.0.1`) and `CIV13_PORT` (default `1714`).

```text
python tools/agent-control/civ13_agent.py call status
python tools/agent-control/civ13_agent.py call get_vars '{"target": "global", "names": ["season"]}'
python tools/agent-control/civ13_agent.py mcp
```

`mcp` is a stdio MCP server exposing one `civ13_<action>` tool per action with
a JSON schema (from `tools/agent-control/catalog.py`). An MCP client entry:

```json
{"mcpServers": {"civ13": {"command": "python", "args": ["tools/agent-control/civ13_agent.py", "mcp"],
  "env": {"CIV13_AGENT_NAME": "gamemaster", "CIV13_AGENT_TOKEN_FILE": "/path/to/token"}}}}
```

`autopilot.py` lets an Ollama model play one character. It reuses the Player
Help bridge config (`--player-help-config`, else `data/player-help-config.json`,
else `config/player-help.json`): `ollama_url` (origin, `/v1` or `/api/chat`),
`model`, `auth_token_env`, `num_ctx` and `think` (off unless `true`). Using the
same `num_ctx` keeps Ollama from reloading a model shared with Player Help:

```text
python tools/agent-control/autopilot.py --spawn turf:483,43,2 --name Ada --goal "Gather food and greet people" --steps 30 --release
python tools/agent-control/autopilot.py --character "[0x3000090]" --goal "Help my tribe build a hut"
```

The model answers with a plan of up to five steps, which the autopilot sends
through `character_queue` and reports back after the queue drains. It shows the
model only names and offsets (refs stay local), marks game text as untrusted,
and validates every reply before acting.

## Tests

```text
python -B -m unittest discover -s tests/agent_control -v
```

The offline suite covers the Topic packet format, client, MCP handshake and
tool calls, catalog sync with the DM action table, autopilot parsing, and the
security contracts above.
