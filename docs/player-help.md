# Optional Ollama gameplay help

Players use **Help! > Ask for help**. It opens a question dialog, then a private
answer window. The prompt warns that the question goes to the server owner's AI
service and should not contain personal information. Answers can be wrong. The
Crafting Atlas and player wiki remain available without an AI service.

The question dialog opens before service checks. Opening or cancelling it uses
no request allowance. Without configuration, a running bridge, or a fresh
heartbeat, submission shows an unavailable notice. An unanswered request times out after a bounded 60..600
running-server seconds (including the queue budget) and releases its slot. Failed or empty model answers
show an explicit notice rather than a blank window. Wait until the bridge has
published two heartbeats (normally a few seconds) before trying the first question.

## Private follow-up conversations

With a conversation-capable worker, the answer window offers **Follow up** and
**New conversation**. Ask for help also continues the current session. New
conversation clears the context; use Ask for help again to ask a fresh question.
The normal cooldown and one-pending-request-per-account rules still apply.

The authenticated client owns its completed question/answer pairs. No browser
parameter selects an account, session or model role. Action tokens belong to
that client and rotate after accepted responses. Retention is at most three
completed pairs and 4,096 UTF-8 bytes per session; a retained answer is clipped
at a Unicode boundary to 3,000 bytes. Oldest pairs are removed first. This is a
conservative byte budget, not a tokenizer guarantee. The entire serialized
request, including escaped Unicode, IDs, current question, metadata and context,
must also fit 16,384 ASCII-JSON bytes; older complete pairs may be omitted to fit.
The latest game snapshot is authoritative, and prior AI answers may be wrong.

History expires after 15 idle minutes of running-server time, on disconnect,
reset or server restart. Reconnecting, even to the same account, starts empty.
At most 128 client sessions retain history; reaching that limit evicts the oldest
tracked session. Session fields live on clients, not saved player mobs; the
service explicitly excludes its pending questions and runtime registries from
custom datum persistence. Reset or expiry invalidates the generation of an
in-flight request. Its late reply is discarded, and its account lock remains
until completion or timeout. Failed, timed-out, mismatched and duplicate replies
never append turns. A worker restart retains no private conversation cache:
the next request carries the bounded server-owned snapshot. Existing startup
cleanup discards queued files, so an interrupted request can time out.

Worker health advertises conversation protocol 1. A new game omits conversation
fields for old workers and permits standalone questions. Follow up requires an
acknowledged conversation response. If a worker rolls back and fails to acknowledge
a request containing history, the game discards that answer and clears context
instead of displaying it as a contextual reply. Old game/new worker and existing
plain/Markdown response negotiation remain supported.

Conversation snapshots are written to the existing private spool with questions
and responses. Normal completion/timeout removes them and startup clears old
slots. Disconnect alone leaves a pending file until completion/timeout. A crash,
stopped server, filesystem failure or backup can retain residual files. This is
not encryption or guaranteed immediate erasure. Restrict spool access and avoid
personal information. The configured inference endpoint can retain data under
its own policy; the local-first transport selection is unchanged.

**Activation metadata:** both a game/server build restart and a separately
coordinated worker update/restart are required for full conversation support.
This source change does not authorize either restart, deployment or live inference.

## Answer formatting

The game converts the model's Markdown to a bounded display subset based on
[CommonMark 0.31.2](https://spec.commonmark.org/0.31.2/). It renders ATX headings,
bulleted and numbered lines (including indentation), bold/italic text, same-line
code spans, fenced code blocks, inline HTTP/HTTPS links and paragraph breaks.
Each ordinary source line remains a visible line break. Lists use explicit
bullets/numbers and paragraphs rather than relying on unsupported terminal list
tags. The generated markup uses the conservative tags in BYOND's
[supported HTML reference](https://www.byond.com/docs/guide/app3.html), without
answer-supplied CSS or JavaScript, for the native browser dialog.

This is not a full CommonMark implementation: reference links, link titles,
autolinks, setext headings, block quotes, indented code blocks and complex
delimiter nesting remain literal text. HTML entities also remain literal text.
Unmatched inline delimiters remain text; an unclosed code fence extends to the
end of the answer. Code is escaped without interpreting its Markdown contents.
Raw HTML is escaped, and Markdown images never create images or remote fetches.
Links require an explicit HTTP or HTTPS scheme and reject whitespace, control
characters, quotes, angle brackets and backslashes; relative, BYOND, file, data
and JavaScript destinations remain text. No model-generated HTML is trusted.
The existing 4,000-character answer limit is also enforced at rendering.

Rendering happens after the bridge's bounded response validation, immediately
before `browse()`. No prompt change, dependency, model request or bridge reload
is required for this conversion. A source change does require a game build and
separately coordinated save/update before affecting a running host.

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
   `https://ollama.example.net` its `/v1` base URL, or its `/api/chat` URL. A `/v1` base is normalized to
   the same host's native `/api/chat` endpoint so context size and thinking controls
   are honored; OpenAI-compatible proxy-only servers are not supported. The service follows the
   [Ollama chat API](https://docs.ollama.com/api/chat), with streaming disabled.
3. Set `num_ctx` to 1024..32768 and `think` to `true` or `false`.
   Set `timeout_seconds` to 1..120 and `workers` to 1..2. The game permits eight
   outstanding questions, one per account, and a 30-second per-account cooldown.
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

The bridge treats request IDs as bounded opaque correlation strings. Native
BYOND may format the realtime component in scientific notation. Spool markers
accept the ID alone or the single LF/CRLF ending appended by `text2file`; other
whitespace and embedded or repeated line endings are rejected. The same parsing
applies when admitting a request and committing its answer. Filenames always use
the eight fixed slot numbers, never the request ID.

## Request limits

The optional `limits` configuration sets the same policy in the bridge and game
(published through a bounded local `limits.json`). Defaults allow three requests
per account per 120 seconds, ten per 600 seconds, and thirty across the server
per 60 seconds, in addition to the cooldown and one outstanding request per
account. The bridge enforces admission again immediately before model dispatch,
including direct calls and copied/replayed spool requests. Only 1..2 configured
workers run model calls; eight fixed spool slots bound the queue. Requests
rejected for size, unavailability, rate or capacity never reach the model.

Cooldown and quotas use the authenticated client's account, rather than its
connection, so reconnecting does not reset them. Guest accounts cannot submit
questions because a new guest identity would evade account limits. The bridge receives a salted
account hash used only for admission; it is excluded from model payloads. Each
game process creates its own salt. Limits are per running game/bridge, not a
cross-server or restart-persistent account ban. Local spool write access is
trusted server access; it is not a player authentication mechanism.

Limiter storage caps at 2,048 accounts by default (configurable up to 4,096),
refusing new accounts while full rather than evicting active cooldowns. Expired
histories are reclaimed on admission. Limits use positive integer seconds or
counts; time settings cap at 86,400 seconds, counts at 4,096, and queue slots at
eight. Failed dispatches/timeouts release pending locks but retain consumed
allowance, preventing failures from becoming a retry flood. Disconnecting does
not cancel a pending model call; the game retains its account lock until a
response or timeout. After changing worker configuration, restart the worker
through the normal authorized service procedure.

## Running the bridge

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
TimeoutStopSec=130
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
are omitted. At most six matching code/wiki/guide/recipe entries and 16,000 context characters
are sent per question. Unmatched or truncated recipe details must be checked in
the atlas, including current map and research availability.

Question text, approved guidance and the bounded gameplay/inventory snapshot
described below are sent. No account name, chat history, filesystem, developer
MCP tools or administration API is exposed.
There is no conversational memory, command execution or tool calling. Questions
are temporary spool files, removed when completed, disconnected or timed out;
the remote service may keep its own logs, so owners should disclose its policy.
Raw model HTML is escaped; the renderer generates only allowlisted formatting and validated HTTP/HTTPS links.

The worker is separate from the developer MCP server: player requests do not
receive developer tools. Do not expose MCP credentials to the worker.

## Verification

### Worker and renderer compatibility

Updated servers attach `render_contract: {"version":1,"capabilities":["markdown-basic-v1"]}`
to each question. The worker snapshots this capability before asynchronous dispatch.
Missing capabilities (older servers), or version 1 with an empty capability list,
select `plain-v1`. Unsupported versions, unknown/duplicate capabilities and malformed
contracts return unavailable before consuming model quota or contacting the model.
There is no inference from server revision, map or answer text.

Successful responses contain one `answer` plus `render_protocol: 1` and
`answer_format: "plain-v1"` or `"markdown-basic-v1"`. An updated server accepts
old-worker responses only when both metadata keys are absent. Partial, null or
unknown metadata fails closed. Plaintext is HTML-escaped verbatim in a preformatted
block, so literal Markdown is never parsed a second time. Markdown uses the bounded
renderer described above. An older server ignores the additional metadata and
displays the worker's readable plaintext through its existing escaped block.

Plaintext cleanup removes matched basic headings, emphasis, inline code and fenced
code markers, preserves code contents and bullet/number prefixes, and expands
HTTP/HTTPS links as `label (URL)`. Raw HTML remains literal text. Unmatched and
unsupported syntax is conservatively retained; this is not full CommonMark.
The raw model answer exists only ephemerally before projection. Only the chosen
display answer is written to the spool, with at most 4000 Unicode codepoints
and 4000 UTF-8 bytes. BYOND 516's `length()` measures string bytes, so the byte
bound is required for both legacy and updated servers. For example, 1300 CJK
characters (3900 bytes) and 1000 four-byte characters fit; 3900 CJK characters do not.
The entire ASCII-escaped JSON response, including ID and metadata, must also fit
24000 bytes. Oversized or malformed Unicode responses return unavailable.

A worker-only update can provide this plaintext cleanup without restarting an
older game host. Full Markdown requires the updated compiled game and a later
authorized host restart. During a managed worker replacement Help is temporarily
unavailable: gracefully stop the manager, drain active requests, and preserve
queued request files until ordinary game consumption or timeout clears all eight
slots. The worker limiter is in memory, so wait a full maximum configured cooldown,
burst, account-window and global-window interval after the old worker's final
completion before replacement. Do not reset manager attempts, replay requests,
inject spool files or clear queued work. Verify empty slots before startup because
the current worker clears slots at startup. Preserve the same manager record and
run identity; the replacement consumes the next existing attempt. This procedure
does not restart the game or change its credentials or network configuration.

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

## Code and wiki retrieval

The reviewed gameplay evidence also includes the generic material-shard behavior
and constructed names for flint, steel, glass and obsidian shards. This lets the
worker ground questions such as “flint shrapnel” even when that exact name is not
a literal in source. It does not assert a material-specific crafting recipe or
availability. Source markers and material naming assumptions are checked at
worker startup; unexpected changes require review. Arbitrary game files remain
outside the retrieval allowlist.

The answer window shows the submitted question and, below the wiki and atlas
links, previous questions from the same bounded client conversation. Questions
are rendered as text. Existing session, expiry and disconnect limits apply; an
older worker still displays the current standalone question.

The bridge retrieves reviewed gameplay excerpts from the game's bloomery and
anvil implementation in addition to generated recipe data. Excerpt boundary
changes fail startup rather than silently supplying unrelated code. Source hashes
identify the files used. This is read-only evidence retrieval, not an admin MCP
connection or model-controlled source browser.

Set `wiki_root` in the private config to an up-to-date checkout of `civ13-wiki`.
The bridge reads only `src/guides/Guide_to_Crafting.md`,
`src/guides/Guide_to_Metallurgy.md` and `src/Starter_Guide.md` at launch.
No network downloads or recursive repository scans occur. Update that checkout
and restart the bridge to refresh wiki knowledge. Missing configured pages fail
startup; omitted `wiki_root` disables wiki retrieval. Code takes precedence over
conflicting wiki prose. Retrieved text is untrusted evidence, never instructions.

Retrieval reserves space for code, wiki and recipes. Explicit Nomads/Gaia questions
exclude other material catalogs and prefer global recipes. Without map context,
the helper must explain gates rather than promise a recipe is unlocked. Adding
other gameplay systems requires reviewing their source excerpts and player wiki
pages before extending the allowlist. No hidden loot, credentials, player data,
admin commands or private reference repositories are indexed.

Each question automatically includes the server's public map title/ID, game mode,
era/ordinal and civilization flag. These are captured from map metadata at
submission, not inferred from player wording. No account identity, coordinates,
hidden map state or faction secrets are included. The bounded asking-player
inventory snapshot is described below. Unknown/uninitialized
map metadata is marked unknown. Era does not prove faction research unlocks.

### Player and environment snapshot

Each question includes the current map, mode, era, season and time of day. For the asking human it also includes health, nutrition, hydration and wetness percentages, body temperature in kelvin, indoor/outdoor exposure, local weather and active fire/incapacitation/weather exposure. This is a detached snapshot taken when submitting the question, not continuous monitoring. No account identity, other players, hidden disease diagnoses or private admin events are sent. Missing context remains unknown; the effects list is not an exhaustive event catalog. The input dialog tells players their gameplay condition is sent to the configured AI service. Collection performs no world scan, HTTP request or spawned timer.

Inventory context includes occupied equipment/hand/pocket slots and carried storage contents, with item names, stack quantities and their slot/container labels. It excludes body internals and item IDs, and stops at 24 items, 64 inspected entries or two container levels. An explicit truncation flag tells the model that omitted ingredients may still be present. Item labels are untrusted text, not instructions. The request file budget is 16 KiB to accommodate bounded inventory snapshots.
