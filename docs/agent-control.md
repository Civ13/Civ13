# Agent control

Agent control lets LLMs, scripts and other agents observe and run a Civ13
server over world/Topic: read status and players, read and edit variables, call
procs and admin verbs, message players, and play characters. It is off unless
the host creates `config/agent-control.txt`.

Code: `code/modules/agent_control/`. Client, MCP server and Ollama autopilot:
`tools/agent-control/`. Tests: `tests/agent_control/`.

Observation authority, stale visual memory, replay format and navigation limits:
[observation contract](agent-observation-contract.md). The autopilot's
[guarded action contract](agent-action-contract.md) covers correlation, completion,
cancellation and operator pause.

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
  | `visits` | `visit_status`, `visit_order`, `visit_start` |
  | `ooc` | the `ooc` character action (with `characters`) |
  | `bug_report` | the `bug_report` character action (with `characters`) |
  | `*` | everything |

- **Audit.** Every mutating action is written to the admin log as
  `AGENT <name>: ...` (with old and new values for `set_var`, and arguments for
  procs and verbs) and shown to online admins, except announcements and
  individual character steps. Reads and character movement go to the game
  log. Agents can read the admin log back with `logs`; `logs` with `kind` `food`
  returns recent food toxin swallows (source item, amounts and recorded cause),
  and `kind` `radio` returns the last lines relayed to and from other regions
  through long-range radio relays (speaker key, region and relay).
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

- **Verbs and throwing.** `verb` runs what a player reaches through the
  right-click menu, verb panels or command bar: `name` is a verb from the
  observation's `self.verbs` (the character's own, such as Rest, Sleep, Give or
  Point To; emotes are left out of the list but still work), `self.item_verbs`
  (held and worn items, listed and accepted as `item: verb`) or a nearby
  row's `verbs` (things on a tile next to the character, with `target`).
  `onto` is the verb's argument when it takes someone or something, and `text`
  when it takes words. Out-of-character, admin and preference verbs, and verbs
  that end the character (Succumb, Ghost), are never offered. `throw` throws the
  held item at `target`. Both run only from `character_queue`. Wound rows
  (`self.wounds` and nearby people's `wounds`) name the limb by its
  zone-selector name (`l_arm`), so `click` with that `zone` aims at it.

- **Host characters without a ckey.** `character_spawn` creates a mob (default
  `/mob/living/human`) owned by that agent, up to `max_characters` (default 4).
  Humans still get their usual map identity; a `name` is applied after it.
  With `job` (a late-join title on the current map, such as `Nomad`), the
  character joins like a late joiner instead: that job's clothes, kit, name
  and spawn point through the normal `EquipRank` path; `stay: true` keeps the
  kit but starts the character at `target`. An unknown job is
  refused with the list of open ones. Spawned characters get a mind (key
  `agent_<name>`, never active) so job notes have somewhere to go.
- **Player handover.** With `allow_handover` in the config, players get a
  **Toggle AI Control** verb (OOC). After they confirm, any agent with the
  `characters` scope can drive that character until the player uses the verb
  again or an agent releases it. The player's own input keeps working.

`character_observe` returns the character's state (health, hands, intent,
nutrition, water, worn and carried items, and `craftable` recipes when the
active hand holds a material stack), the nearest tile of each kind of terrain
(`terrain`, clickable as `turf:x,y,z`), the four neighbouring turfs, up to 64 visible
objects with `dx`/`dy` offsets and refs (trees and plants add `branches`, the
branches harm intent can break off now; fallen branches add `branch` as
`leafy` or `cleared`; loose items that can be picked up add `item`), and the messages the character saw or
heard (after normal language scrambling) since the `since` id.
`character_act` takes `do`: `move` and `face` (`dir`), `say` and `emote`
(`text`), `click` (`target` ref the character can see, optional `modifier`),
`use` (the held item), `craft` (`recipe` from the held stack, optional
`amount`), `equip` (the held item, as the quick-equip key does; `no_slot`
when nothing can take it), `take` (`item`: a stowed item's name, into the
empty active hand), `examine`
(`target`), `drop`, `swap_hand`, `intent` (`help`, `disarm`, `grab`, `harm`)
and `resist`. Crafting goes through the stack's own recipe handler, so costs,
tools and research gates apply. Click, use and craft can start timed work; a
direct call returns at once and the work continues in the game, while a queued
step waits for it. Actions run with `usr` set to the character.
`ooc` (`text`, needs the `ooc` scope too) says one line in OOC chat as
"<character name> (AI)": every player with OOC on sees it, it goes to Discord
like a player's line, and in a region group to the other regions. It fails with
`ooc_closed` while OOC is muted. The autopilot never uses it; send it by hand, for
example `python tools/agent-control/civ13_agent.py call character_act
'{"character": "<ref>", "do": "ooc", "text": "OOC test from Ada"}'`.
`bug_report` (`title` up to 80 characters and `what` up to 2000, both
required; `steps` and `expected` optional; needs the `bug_report` scope too)
files an in-game bug report as "<character name> (AI)", with the character's
round details and location, exactly like a player's Help > Report bug. It waits
in Admin > Bug Reports for an admin to approve or reject; nothing reaches GitHub
without that. The same limits apply (3 waiting per agent, 5 minutes apart, 50 in
all) and a refused report fails with `bug_report_refused` and the reason. The
autopilot never uses it; send it by hand, for example
`python tools/agent-control/civ13_agent.py call character_act '{"character":
"<ref>", "do": "bug_report", "title": "Test report from Ada", "what": "Testing
the bug report queue."}'`.

A direct `character_act` that is still cooling down fails with `cooldown` and
the ticks to wait. Cooldowns are the character's movement delay, the mob's own
click cooldowns (`next_move`, `next_click`) and one second between `say`,
`emote`, `ooc` or `bug_report`.

`character_queue` takes a plan of up to 32 `actions` (64 pending per
character), each shaped like `character_act` arguments, plus
`{"do": "wait", "ticks": 1-600}`. Every step is validated before any is queued.
The server runs them in order, waiting out each cooldown, at most one step per
tick, so one request replaces many polled ones and the request rate limit is
not spent on retries. A failed step skips the rest unless `stop_on_failure` is
false. `clear: true` cancels pending steps. `character_observe` reports the
queue as `pending`, `running` and `results` with ids above `queue_since`.
A step may take `repeat` (1-30): it runs that many times, each when its
cooldown allows, and is recorded once as `done xN`. `until` stops the repeats
early when a new message contains `message`, the active hand holds an item whose
name contains `holding`, or the held stack reaches `amount`. A blocked move or a
failure ends the repeats. Any step with a `target` may carry `expect_name`: the
step fails with `target_changed` when that ref now names something else.
Queued steps are logged like direct ones; releasing a character, or removing
its agent from the config, stops its queue. Movement waits for the mob's
movement delay and is logged to the game log; other character actions reach
the admin log.
Controlled characters are not treated as SSD.

### Change lists, prompts and sounds

Every `character_observe` returns a `rev`. Passing it back as `since_rev`
makes `nearby` list only the rows that appeared or changed since that observe
(a row's position is compared in map coordinates, so walking does not mark
everything changed), with `nearby_removed` refs and a `nearby_unchanged`
count. When the baseline is gone (another observe ran in between) the full
list comes back without `changes_since`.

<a id="prompts"></a>Game prompts reach agent characters through `WWinput` and through
`player_input`/`player_alert`, which gameplay code uses instead of raw `input()`
and `alert()` (amounts, names, text, colours and picks from a list). A player
sees the same prompt as before; an agent character answers it from its step's
`choose` (a number for amounts, the text itself, `#rrggbb` for colours, or the
option or button name, matched without case). A prompt the step did not
answer with `choose` is listed under `prompts` (after `prompt_since`, newest id
in `last_prompt`) with its text, the `choices` (or the input `kind`) and what
the character `took`, so the agent can repeat the step with `choose`.

<a id="sounds"></a>Sounds played within hearing range are listed under `sounds` (after
`sound_since`, newest id in `last_sound`) with the sound's name, `dx`/`dy` and
volume. Footsteps are left out unless `footsteps` is true. A deafened
character hears nothing.

<a id="movement"></a>`move` follows the rules a player's step follows in `/client/Move`
(`code/modules/agent_control/agent_movement.dm`): the grace-period wall, a level
being saved, nooses, crouching, being held while restrained, and being pinned
refuse it. While prone or lying the step is a crawl, which runs only from
`character_queue`. A wheelchair rolls. The step's cooldown is the movement mode's
delay (run, walk, sneak) plus ground (snow, mud, flood, the floor's own delay),
hills, drowsiness, a deployed sarissa, pulling and speed traits, and it costs
food, water, stamina and warmth the same way. A runner out of stamina drops to
walking. Riding a mount moves at the mount's pace.

<a id="stance"></a>`stance` sets what players change with HUD buttons: `move` (`run`, `walk`,
`sneak`, `crawl`), `defense` (`dodge`, `parry`), `tactic` (`charge`, `aim`,
`rush`, `defend`), `secondary` (the middle-click attack: `kick`, `jump`,
`bite`), `face_lock` and `aim` (gun aim mode), any of them in one step; the
character's `stance` reports them. `equip` takes an optional `slot` (`back`,
`belt`, `head`, `suit`, `uniform`, `shoes`, `gloves`, `mask`, `eyes`,
`shoulder`, `id`, `l_ear`, `r_ear`, `l_store`, `r_store`, `s_store`), as
dragging the item onto that inventory slot does. A storage container next to
the character lists its `contents` (refs and names, as opening it shows), and
`click` reaches an item inside a container that is next to the character or
carried by it. `here` reports the tile's terrain `height` and `light` (0-1).

<a id="windows"></a>Menu windows (research, trade posts, suppliers, faction and recruitment
desks, books and other HTML windows a player sees) are listed under `windows`
(shown or refreshed after `window_since`, newest id in `last_window`; the six
newest open windows are kept) with the window name, title, plain text and
numbered `links`. Game code opens them with `show_browse(target, html,
options)` instead of `target << browse(...)`, which keeps that copy for agent
characters. `topic` (`window` plus `link`, a number, or `label`; queue only)
presses one as the player's client would: the link's object gets its `Topic`
with the character as `usr`. Only links the character was shown can be
pressed, raw hrefs are never returned, and client, preference and admin routes
are refused with `unsupported`. `close_window` forgets a window.

The client takes `wait_s` (0-60) on `character_observe`: it polls twice a
second until there is a message after `since`, a queue result after
`queue_since`, a prompt after `prompt_since`, a sound after `sound_since` or a
nearby change after `since_rev`, and reports `waited_s`. The world never sleeps
inside a Topic reply.

### Seeing the view

`character_view` returns what a character sees within `radius` (1-7, default 7):
an appearance dump in the byond-devtools `ingame` format, with overlays,
underlays, colours, planes and the plane masters a player's HUD builds. Only
turfs in the character's view are listed, and things it cannot see are left
out. Icons from the source tree are named by path. Icons made at runtime (human
bodies, blended overlays) travel as base64 DMI bytes, up to 48 per view. A Topic
reply holds at most 64 KB, so the dump is built once and read in parts
(`view`, `part`, `parts`). The Python client and the MCP tool fetch every part.

With `BYOND_DEVTOOLS` set to a byond-devtools checkout (Node 22+), the
`civ13_character_view` MCP tool returns a PNG of the view next to a short
summary. `civ13_agent.py view <character> out.png [radius]` writes the PNG.
Without byond-devtools, the tool returns the dump, which byond-devtools'
`dump_render` MCP tool or `node src/cli.js ingame --root <Civ13> --dump view.json
--out view.png` can render. Filters, maptext and animation past the first frame
are not modelled.

- `frames` (2-8) and `interval_s` (0.2-10, default 1) take that many snapshots
  apart in time and return an animated PNG (the client waits between them; the
  world never sleeps in a reply). `civ13_agent.py view <character> out.png
  [radius] [frames] [interval_s]` does the same.
- When a player is in the body, the dump also carries the HUD: `client.screen`
  objects with their `screen_loc` and `client.view` (`hud` is 1). A body driven
  only through agent control has no client and so no HUD.
- The render report lists `undrawn`: things in view a player could click
  (`mouse_opacity` not 0) whose whole appearance put no pixel on the map. Each
  one breaks the rule that anything a player can interact with must be rendered,
  so treat it as a bug to look into.

### Boats

Characters use the same boats players do (`code/modules/agent_control/agent_boats.dm`):
a raft (10 wood logs, crafted where the character stands, research-gated like
any recipe), and outrigger, sail and motor boats.

- `board` (`target`: a raft or boat within one tile) climbs on, as dragging
  yourself onto it does. The first one aboard drives; a boat with a rudder
  needs a free hand for it.
- While driving, `move` steers one tile at the vehicle's own speed: rafts are
  paddled, sail boats sail, and motor boats need fuel and a running engine
  (`use` the rudder once to start it; a second `use` puts it in gear and it
  then moves by itself, with `move` only turning it). A boat stops at land.
  A stalled boat fails with `no_propulsion` and says why.
- `disembark` gets off onto the boat's tile; the next `move` steps ashore.
- `drag` (`target` dragged `onto` another thing, both next to the character)
  is the mouse drag: a crate onto a boat's deck, an engine onto a frame, or
  the character's own ref onto a boat.
- Refuelling is a `click` on the boat holding a container of its fuel.
- `board`, `disembark` and `drag` are timed, so they run only from
  `character_queue`; a direct `character_act` is refused with `use_queue`.

`character_state` adds `vehicle` (name, role, seats, cargo and cargo space,
fuel and accepted fuels, engine, sails, `stalled` reason) and `can_steer`;
nearby boats carry the same details, and `surroundings` marks `deep_water`,
which is `blocked` for a walker without a lifejacket and open for a driver.

`character_route` (`x`, `y` or `target` on the character's level, at most 150
tiles away, optional `reach`) plans a route over dry and shallow ground first.
When only deep water connects the two, it plans across it, with as few
crossings as it can, and returns `needs_boat`, `legs` (`walk` and `boat` legs
as strings of `n`/`s`/`e`/`w` moves), the `launch` tile (last dry tile), the
`landing` tile, up to five free `boats` near the launch with a `board_from`
tile each, and the raft recipe. A boat leg starts on the launch tile and
includes the shallows on either side, so a raft built there can take it.

### Cars, tanks, aircraft, turrets and drones

Modular vehicles are driven from a driver's seat
(`code/modules/agent_control/agent_vehicles.dm`). `drag` the character onto the
seat to sit in it; the steering wheel goes into the active hand.

- `drive` (`control`) presses a driver's seat HUD button: `gear_up` (starts the
  engine, then shifts up), `gear_down` (shifts down, stops, then turns the
  engine off), `forward`, `reverse`, `turn_left`, `turn_right`, and for
  aircraft `climb` and `descend`. A keyed vehicle needs its key carried.
  Climbing on the ground fails with the takeoff hint a player reads.
- `move` presses that arrow key, as `/client/verb/startmoving*` does: with the
  wheel in hand, east and west turn, and north and south pick forward or
  reverse while stopped. Held turret controls change range (north, south) or
  turn the turret (east, west) for `hold` deciseconds (default 5); the
  opposite key stops a turn. An active drone controller flies the drone. A
  seated character or one flying a drone does not walk.
- `use` with `alternate` presses the secondary-use key of the held item
  (gear down, the turret's weapon switch, a drone's special).

`character_state` adds `driving` (gear, gears, reverse, moving, heading,
engine, fuel, `key_ok`, and `flight`, `altitude` and `target_altitude` for
aircraft) and `remote_controls` for held turret and drone controls. Trains and
locomotives are clicked like any other machine.

<a id="screens"></a>

### Machine screens (NanoUI and tgui)

Research benches, chemical dispensers, vending machines, faction creation and
symbol desks, appearance changers and recruitment stations open a NanoUI or
tgui screen when clicked (`code/modules/agent_control/agent_screens.dm`). For an
agent character's body the screen stays open without a browser window, under
the same status rules as a player's: it closes when the character walks away.

- `character_observe` lists `screens`: number, title, template, `status`
  (`interactive`, `view_only`, `disabled`), the machine's `ref`, the `actions`
  the screen accepts and its `data` as JSON (cut at 4000 characters, with
  `data_truncated`).
- `screen` (`screen`: number or title, `act`: one of its actions, `value`:
  default 1) presses that button and reaches the machine's Topic after the
  same status and owner checks. Paint actions also take `x`, `y`, `cells` and
  `stroke_continue`. A press may prompt (answer with `choose`), so it runs only
  from `character_queue`. `close` (true) closes the screen directly.

Reader screens with their own topic states (books, notes, faction and religion
lists, photos, the crafting atlas, the paper editor) still need a connected
client.

## Nomad visits

The `visits` scope lets an agent coordinate a [nomad visit](nomad-raids.md):

- `visit_status` returns `{"active": false}` or the visit's kind, clan, state,
  party, nearby people (by ref, with their reputation and standing with the
  clans, and trade credit), tribute or goods, the
  orders allowed now, the cue the leader is about to say, and events since
  `since` (pass the last `last_event`). Reading it attaches the coordinator for
  10 seconds.
- `visit_order` sends one order (`say`, `retreat`, `assault`, `bargain`,
  `tactic`, `focus`, `loot` or `price`). The party controller checks it against
  the state and bounds and fails with `refused` and the reason otherwise.
- `visit_start` starts raiders or traders (`kind`) at the busiest settlement,
  or near `target`, with an optional `size` and `wants` (a kind of goods for
  traders: `medicine`, `seeds`, `food`, `metal`, `cloth` or `tools`).

Orders and starts go to the admin log. `visitor_voice.py` (see Tools) is a
ready-made coordinator.

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
a JSON schema (from `tools/agent-control/catalog.py`). Read-only tools carry
`readOnlyHint`; `set_var`, `call_proc`, `call_verb`, `kick`, `restart`,
`delete_atom` and `character_release` carry `destructiveHint`. It also serves
two resources, this guide (`civ13://docs/agent-control`) and the action catalog
(`civ13://actions`), and three prompts: `observe_and_act` (a character and a
goal), `view_character` and `server_check` (read-only). Set `BYOND_DEVTOOLS` to
a byond-devtools checkout for `civ13_character_view` pictures. An MCP client entry:

```json
{"mcpServers": {"civ13": {"command": "python", "args": ["tools/agent-control/civ13_agent.py", "mcp"],
  "env": {"CIV13_AGENT_NAME": "gamemaster", "CIV13_AGENT_TOKEN_FILE": "/path/to/token"}}}}
```

`autopilot.py` lets an Ollama model play one character. It reuses the Player
Help bridge config (`--player-help-config`, else `data/player-help-config.json`,
else `config/player-help.json`): `ollama_url` (origin, `/v1` or `/api/chat`),
`model`, `auth_token_env`, `num_ctx`, `think` (off unless `true`) and
`keep_alive` (default `30m`, see [Latency](#latency)). Using the same
`num_ctx` keeps Ollama from reloading a model shared with Player Help:

```text
python tools/agent-control/autopilot.py --spawn turf:483,43,2 --name Ada --goal "Gather food and greet people" --steps 30 --release
python tools/agent-control/autopilot.py --character "[0x3000090]" --goal "Help my tribe build a hut"
python tools/agent-control/autopilot.py --spawn turf:332,242,2 --stay --name Ada --goal "Help people in need"
```

**Spawn AI Character (admin verb, Fun).** An admin with `R_FUN` can put an AI
character such as Ada into play from in game. The verb asks for the agent (only
agents with the `characters` scope; skipped when there is one), a name (default
Ada), a goal, and whether to start at the admin's location or the job's spawn
point. It joins as Nomad when the map offers it, otherwise as a job the admin
picks. The character is spawned through the agent's own `character_spawn`
(same limits and audit line) and shows in `character_list` with `waiting: true`
and the `goal` until an autopilot first observes it. To play it, the host runs
one watcher per agent:

```text
python tools/agent-control/autopilot.py --watch
```

The watcher polls `character_list` every 10 seconds and starts one autopilot
run per waiting character with that goal, passing on its own model flags and
playing until the character dies (`--steps` overrides that). Each run logs to
`data/agent-control/<name>-<ref>.log` (`--log-dir` changes the folder). A run
that fails (the model or server stops it, a non-zero exit) is started again
with the same goal five minutes after it started, unless `--release` is set,
which the watcher passes on to each run. A run that ends on purpose (its
`--steps` or `--minutes` limit, or the character's death) is not retried. When no
watcher has listed that agent's characters in the last minute, the verb warns
the admin that the character will stand still until one starts.

A spawned character joins as `--job` (default `Nomad`). The model gets a short
survival primer (including the stone-age start: flint from rocks on grab
intent, sharpening, branches, sticks and leaves), matching lines from
`config/tips.txt`, and a rule not to take
from other players' camps. It answers with one to three steps and a note to
itself. Target indexes, travel coordinates/distances and wait ticks must be integers
(or decimal integer strings for older models); booleans, fractions and non-finite
numbers are rejected, not rounded into actions. Waits default to 10 ticks only
when omitted and valid integers are clamped to 1–50 ticks. A malformed step stops
the plan at its valid prefix; later steps do not run. This validation is not proof
that the game executed an action: queue results remain the execution evidence.
JSON is preferred. The legacy text fallback accepts forms such as
`find_flint on rock 5`, `explore north`, `wait 10` and `travel north 20`.
It requires complete integer tokens, which may carry list punctuation such as
`click [3]`, `chop tree (2)` or `find_flint on rock #3`; fractions, hexadecimal
notation, multiple target numbers and trailing numeric punctuation (such as
`click 1.`) are refused, and the feedback quotes the unreadable step.
Skills such as `find_flint`, `break_branch`, `drink` or `chop` name a
target; the autopilot walks next to the target (stepping around blocked
tiles), swaps to the right hand and intent before the click, stows (or drops) a
spare item rather than a tool when it needs a free hand, works a fallen
branch where it lies (leaves, then stick) instead of trying to pick it up, and refuses a skill whose
tool is not in either hand or a branch skill on a tree with no branches. The
model can also walk with `{"do": "go", "target": n}`, run from a target with
`flee`, or `explore` a few tiles in a direction; `attack` hits a target on harm
intent. A model `drop` of a gathered item tries to stow it first; a skill that needs a
free hand stows the spare item and stops (keeping it in hand) when `equip`
finds no free slot (`no_slot`). Each skill checks its target kind (a rock for flint, a tree for branches, a
fallen branch for leaves and sticks, fresh rather than salt water for
drinking), and loose leaves or grass are dropped rather than juggled when a
hand is needed. `sharpen_stick` only takes a stick, or with
target 0 the stick in the other hand. After `pick_leaves`, `make_stick` or
`cut_grass` the autopilot picks up what fell when a hand is free, and a
`NEEDS` line leads the observation when water or nutrition drops below 250;
below 200 water the autopilot replaces the plan with drinking at listed water,
or exploring for it. Body temperature below 290 K or above 316 K is a need too
and tops the goal ladder; below 270 K the autopilot replaces the plan with
putting on carried warm clothes, going to or lighting a listed fire, or
building a campfire from carried logs. Goals follow what she carries (with
twine or sinew, a sharpened stick and sharpened flint the axe goal is
`bind_axe` now). Leatherwork (`tools/agent-control/leatherwork.py`): after food
is secure the ladder asks for a leather belt satchel, then a leather backpack,
and `{"do": "leather_next", "make": "belt"|"backpack"}` runs one stage per turn
(scrape a raw hide, fill a wood mug, wash, dry on a tanning rack, cut logs for
bark, soak bark for tannin, tan, craft and equip). The observation's `items`
gives stack counts and open containers' liquids for what she holds and carries,
and a tanning rack row says what it `holds`. `take` (`item`: a carried or worn item's name) moves a
stowed item into the empty active hand, and skills take a stowed tool they need. A step the
autopilot cannot accept is explained to the model next turn (for example a skill
with no target listed: explore to find one). First aid for others: a hurt person in view is marked
`(hurt: unconscious, bleeding chest, broken left leg)` from what a player sees on them (the
observation row's `wounds`), and a `HELP` line names the one most in need and what to treat them
with. `{"skill": "treat", "target": n}` on a person walks over, takes a bandage (or a splint for a
break; herbs only work on whoever chews them) and clicks the wound's body part on help intent. A
bleeding person within 5 tiles is treated before the model's plan when she carries a bandage and is
not bleeding or under attack herself; she offers help first when they are awake. Whoever is
attacking her, and people her memory distrusts, are not helped. When something attacks the
character, a danger line leads the next prompt. The autopilot observes through
`senses.SensesClient`: each look sends `since_rev`, `prompt_since` and
`sound_since` and rebuilds the full nearby list from its cache. The prompt then
lists what came into or went out of view since the last turn, the sounds heard
(gunshots, explosions, animals, voices, with direction and distance; gunfire or
an explosion within 12 tiles is a warning line), and any game prompt a step could
not answer, with its options and how to repeat the step with `choose`. While the character is
unconscious the run waits for them to come round (checking every 10 seconds,
with no model calls), and it stops once the character is dead. A target the
character cannot walk to is hidden for a while instead of retried. Water marked
`(unclean)` (rivers, puddles, dirty wells) gives cholera, so `{"do": "boil_water"}`
crafts a wood mug, fills it, throws a stone onto a lit campfire, boils the mug with
the hot stone (mug in the active hand, a stick in the other) and drinks it; the
thirst override uses it unless the character is close to dying of thirst. A
serious illness (the `illness` field of `self`) comes before the plan: the
character chews a healing herb whenever the herb remedy runs low. The autopilot runs the
steps through `character_queue` and shows the next
turn what changed (position, hands, clothes, carried items, water, nutrition)
and warns when the same action keeps repeating. It waits while the character
is busy with timed work (`self.busy`), and leaves a target out of the lists
for a while after three clicks on it changed nothing and drew no message, or
after five turns on it within eight steps, and hides every target of a name
after four turns on it in a row without progress. Each turn's changes and messages are
printed to the run log. Only speech and lines about
the character reach the model, lines that keep recurring (heat, weather) are
muted after four turns, so other players' work messages do not crowd
the window. Travel (`tools/agent-control/boats.py`): `{"do": "travel", "x", "y"}`
(or `dir` and `tiles`, or `to` a remembered place such as `home` or `boat`)
follows `character_route`. On a boat leg it boards a free boat near the
launch, or crafts a raft there from 10 carried wood logs, refuels a motor
boat from a carried fuel container and starts its engine, paddles across,
disembarks and walks on. The boat it leaves moored is remembered as the
`boat` place, so the way back takes it again. A `BOAT` line in the prompt
says what boat she is on or sees and what it needs. `--minutes` caps the run time. It shows the
model only names and offsets (refs stay local), marks game text as untrusted,
and validates every reply before acting.

Recipe book (`techtree.py`): the autopilot plans crafting from the game's own
recipes rather than trial and error. On first use it builds
`data/agent-control/game-catalog.json` with
`scripts/build-crafting-atlas.py --catalog-only`, and rebuilds it when
`config/crafting/` changes. It reads the global material list (nomad maps), the
processing routes (smelting, tanning, rope making), a few hand-checked
blacksmithing routes and the stone-age chain that lives in DM procs rather than
recipe files (flint, sharpened flint, stick, sharpened stick, flint hatchet),
named with the autopilot's own skills. Every ladder goal from flint to metal
tools gets a `HOW` line with the cheapest route: basics are gathered, hand
tools (a sharp tool, a container) are only named, and parts already carried are
skipped. The route named like the query wins a tie (a stone pickaxe is made from
stone, not the sandstone "pickaxe" recipe for the same item), a way that needs
the thing being planned is not offered for it (stone for a stone pickaxe says to
make a bone pickaxe first instead of mining with a pickaxe), and stacks are
called what the character sees in hand (`wood logs`, not `wood`). The model can
ask `{"do": "recipe", "item": "..."}` at any time, which takes no game time.
`--catalog PATH` uses another catalog, and `--catalog none` turns the book off.
`python tools/agent-control/techtree.py "iron ingot"` prints a plan.

Memory (`memory.py`): each character keeps a small JSON file in
`data/agent-control/memory/`, named after the character. The file holds:

- home, set by the first campfire or bed the character makes;
- places worth finding again: clean and unclean water, ore, clay, rock and fires;
- the people it has met, with how often, their last few lines, its answers,
  and a trust level (talk raises it slowly, an attack drops it);
- facts the model asked to keep (`"remember"` in a reply, such as a promise);
- a short event log.

- a ledger of the structures it placed (walls, doors, roofs, supports, mine shafts and tunnels, furniture)
  and counts of what it has made or come by. Things skills make without a recipe (sticks, twine, a spear,
  an axe, logs) are noticed from the change in its hands and pockets between turns; the first of each kind
  is an event ("got my first flint hatchet at (x,y)").

Every prompt includes a `MEMORY` slice of the file: the way home, the nearest
known places that are not already in view, the people in view, kept facts and
recent events. People are remembered by the name the character sees. The file
stores no ckeys or account data, stays on the host, and is only sent to the
local model. Player lines are stored as game text and stay inside the untrusted
observation. To reset a character, delete its file. `--memory DIR` moves the
folder, and `--memory none` turns memory off.

Structures and supports: `character_observe` marks each roof in view `supported` and the nearest
underground rock `safe_to_mine`. If the character stands in an underground tunnel, `here` also says
`cave_supported`. These use the same procs as the game's collapse checks: `/obj/roof/proc/is_supported`
and `/turf/floor/dirt/underground/proc/mine_supported`. An unsupported tunnel or roof becomes the
current goal, `mine` is refused on rock that would cave in, and `MEMORY` lists `REPAIR` lines for
unsupported roofs and for ledger pieces that have gone missing.

Habits: a craft or build the current goal does not ask for is refused once the character has made it
more than a few times recently (3 by default, more for walls, roofing, floors and supports). The
model is then sent back to its goal and the recipe book. Pieces of a blueprint are exempt. A recipe counts the same however the model
spells it (`thatch floor`, `floors/thatch floor (1)`).

Blueprints (`blueprints.py`): a blueprint is a small north-up grid of pieces (`#` wall, `D` door,
`s` roof support, `b` bed, `t` table, `.` floor; every tile inside the walls is roofed). There are
two: `hut` (2x2 room) and `house` (3x3 room). `{"do": "blueprint", "name": "hut"}` plans one on the
nearest clear spot in view (no fixed objects, water or rock, and not next to someone else's
building). `{"do": "build_next"}` builds the next missing piece; it starts a hut when nothing is
planned. The game builds a crafted structure on the tile the crafter stands on, so the autopilot walks
onto the piece's own tile and crafts it there from what she carries (wood logs, stone blocks); a roof
goes on the faced tile, so she stands on a neighbouring tile and uses thatch roofing on it. Walls go
up first, then the support, the roof, the furniture and the door last, so the room stays open. Roofing
is crafted from leaf bundles; it drops at her feet, is picked up, and roofs on the next turn. Recipes
fall back in order (log wall, straw wall, stone wall) when the game does not offer one, and a piece
with no recipe left (a bed needs sawn planks) is skipped. Every placing attempt counts, since the game
answers "craft ok" even when it refuses to build; a piece tried three times is skipped. Progress is
read from what the game shows at each tile, with the structure ledger covering tiles out of view. The
plan is saved as `project` in the memory file. The `PROJECT` line in the prompt gives the next piece
and the materials still needed.

Hands: when a step needs a free hand and both are full, the less useful item is stowed, or
dropped at her feet when no pocket, belt or bag has room, so the step still runs: material before
a tool, and of two tools the weaker weapon (a sharpened stick fits a belt; the hatchet stays in
hand). The same applies when a craft needs a stowed stack and when a skill's product (leaves, a
stick, grass, sinew, stone, logs after `chop`) is picked up afterwards. When a predator
is close, the reflex first takes the best weapon within reach (other hand, a pocket or belt, or the
ground next to her), then fights. A plain click that would swing an axe at rock is refused.
A step the autopilot cannot accept, including `go` or a skill aimed at 0 (herself), is explained to
the model and printed to the run log. A second greeting to someone greeted in the last 10 minutes
is trimmed from what she says. The mining goal names the next concrete step, such as `dig_down`
when she already carries a shovel. The primer and the goal ladder call the chopped stack `wood logs`
(the game's name for it; only beds and doors take finished planks cut from logs with a hatchet).

`visitor_voice.py` voices nomad visits with the same Ollama settings. It
waits for a visit (or starts one with `--start raid|trade`), and when the
leader has a cue, players speak or the state changes, it asks the model for a
line and up to a few orders, which the server checks:

```text
python tools/agent-control/visitor_voice.py --start raid --size 4
python tools/agent-control/visitor_voice.py --once
```

## Latency

Every model turn prints where its time went, from Ollama's own counters:

```text
  model 6.6s, read 812 new tokens in 0.9s, wrote 140 tokens in 5.4s
```

`read` is only what Ollama had to process anew. The autopilot keeps the
system prompt and the kept exchanges byte-identical from one turn to the next
(the history is trimmed in blocks of `WINDOW_MAX - WINDOW_MIN` turns rather
than one exchange per turn), so a turn normally reads the newest observation
only, a few hundred to a thousand tokens. A turn that reads thousands of
tokens did not get a prompt-cache hit: another client (Player Help, a second
autopilot) used the model in between, or the prefix changed. `loaded the
model in N s` means the model was unloaded or was reloaded with other
settings. Both tools send `keep_alive` (default `30m`) so an idle model stays
loaded between questions; set it in the Player Help config or with
`--keep-alive` (`-1` keeps the model loaded until Ollama stops).

What else moves the numbers, on the Ollama host rather than in this repo:

- `wrote` dominates once the cache hits: it is the model's generation speed
  times the reply length. The reply is capped at 200 tokens; a smaller or
  lower-quantized model (for example a Qwen3 8B or 14B instruct model at
  `Q4_K_M`) writes several times faster than a 27B one on the same GPU. Keep
  `think` off for Qwen3 and gemma: a thinking model spends the whole budget
  on reasoning and returns no plan.
- The model must sit entirely in VRAM. `ollama ps` shows `100% GPU`; any CPU
  share slows every phase. The 32768 context Player Help uses costs KV memory;
  `OLLAMA_FLASH_ATTENTION=1` with `OLLAMA_KV_CACHE_TYPE=q8_0` roughly halves
  it with no visible quality change, and a Modelfile alias with a smaller
  `num_ctx` for the autopilot (around 12288 is enough for its window) is the
  next lever when memory is short. A different `num_ctx` on the same model
  name makes Ollama reload it on every switch between clients, which is why
  the autopilot reads Player Help's `num_ctx` by default.
- `OLLAMA_NUM_PARALLEL=1` keeps one prompt cache per model; with more slots
  Ollama multiplies the context memory by the slot count. Two clients then
  take turns and evict each other's prefix only when they really overlap.
- The step loop itself waits `--interval` (default 2 s) between actions and
  for timed game work; that is game pacing, not model latency.

## Tests

```text
python -B -m unittest discover -s tests/agent_control -v
```

The offline suite covers the Topic packet format, client, MCP handshake and
tool calls, catalog sync with the DM action table, autopilot parsing, and the
security contracts above. `tests/agent_observe/run.py --byond-bin BIN` runs
change lists, prompts, sounds, queue repeats and `expect_name` in a pinned
BYOND fixture, and `tests/agent_boats/run.py` covers boats.
