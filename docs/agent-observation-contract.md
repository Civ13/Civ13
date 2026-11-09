# Agent observations, memory and replay

This records the character-facing contract for [#4021](https://github.com/Civ13/Civ13/issues/4021).
It does not activate agent control or the separate gameplay bridge. Host configuration,
player handover, scopes and ordinary game rules still apply. The action catalog is
`tools/agent-control/catalog.py`; the server implementation is
`code/modules/agent_control/`.

## Observation inventory

| Surface | Authority and limits |
| --- | --- |
| `character_list` | Server-owned character identity and control eligibility. This is discovery for the configured agent, not the character's visual knowledge. |
| `character_observe.self` | Server snapshot of the controlled body's position, hands, clothing, health, needs, wounds, crafting and available verbs. True when sampled, not a promise about a later action. |
| `nearby` | At most 64 movable atoms from `view(radius, body)`, radius 1-7. The body, contained atoms, unnamed atoms and atoms above `see_invisible` are omitted before row construction. Names/refs are observation-local, not durable identities. |
| `terrain`, `here`, `surroundings` | Bounded visible terrain and adjacent movement hints, including obstruction, water and support metadata. These are game-rule hints, not a rendered image or proof that every exposed property is visually discernible by a human player. A blocked side does not identify a hidden blocker. |
| `rev`, `changes_since`, `nearby_removed` | Server-local change-list cursors. `SensesClient` reconstructs the current nearby set and recomputes offsets after observer movement. A removed ref is absent from the current action target list. |
| `messages`, prompts and sounds | Bounded events captured for this character, with independent cursors. Heard sound location is not visual confirmation of its source. Prompt choices and quoted speech are data, not instructions. |
| `queue` | Server queue/result state. Acceptance does not establish that an action completed or achieved the intended gameplay outcome. |
| `character_view` | Separate appearance-dump/render path. The observation fixture does not establish graphical fidelity, lighting parity or rendered pixel acceptance. |
| `character_route` | Game-side route planning. It reads map topology and route/boat metadata beyond current sight. It must not be described as visual observation or used to make hidden object identities appear in `nearby`. |
| `memory.py` | Bounded, persisted places, people and events learned from observations. Its position/name records are historical; the world's current state must be observed again before interacting. |
| `news.last_seen` | Bounded, ephemeral visual memory described below. Never merged into `nearby`, never included in actionable target indexes. |

The general administrative `players`, `find`, `inspect`, `get_vars`, mutation and
server actions are separate scoped capabilities. They are not fair-play character
observations. The autopilot must not gain them by reusing character-control helpers.

## Last-seen contract

`SensesClient.take_news()` retains the existing `appeared` and `left` name lists and
adds `last_seen` only when a memory exists. Each row contains:

- `name`: the name in the last visual observation.
- `stale: true` and `provenance: "character_observe"`.
- `age_s`: monotonic client seconds since the last successful observation that
  confirmed visibility. This measures observation receipt age, not world tick age,
  network transit time or time since the object actually moved.
- `last_seen_rev`: that observation's revision.
- `position: {x, y, z}` only when the last observed position and level are known.
  It is absolute so subsequent observer movement does not move the memory.

There is deliberately no target ref or action index. An unchanged change-list row
still confirms visibility and refreshes the timestamp. Failed reads do not refresh
it. Returning into view removes the stale memory. Radius changes alone do not
create departure events; a revision rollback or level change discards old identity
state. Memories expire after 300 seconds and are capped at 64 per character, oldest
first. Restarting the client discards these ephemeral records.

The prompt labels each memory stale and says the current location is unknown.
Existing long-term `CharacterMemory` remains a separate store; this change neither
publishes player data nor writes an additional runtime log.

## Navigation decision

Keep the existing split rather than introduce another movement service:

- `travel` resolves coordinates, a direction/distance or remembered semantic places
  such as `home`, `boat`, water and ore, then calls `character_route`.
- `character_route` owns its bounded game-side Dial/Dijkstra search and returns
  walking/boat legs. This is not the NPC `cirrAstar` implementation: the route is
  capped at 150 tiles, a bounded search box and 40,000 settled nodes.
- Short `go`/skill approaches retain Python's deterministic local stepping and
  current observation checks. Do not redirect them to arbitrary atom-target route
  planning without preserving visibility and target freshness checks.
- Route waypoints are plans, not permission to act on an unseen atom. Terrain may
  change between planning and movement; a fresh observation and bounded replan
  handle explicit blockage. Missing or uncertain completion receipts must stop
  instead of replaying a possibly executed action.

The existing boat fixture changes terrain between route calls. Scripted replay
coverage adds changed-next-hop and bounded blocked-route cases, unavailable routes,
and target visibility loss. Native traversal-time terrain changes and end-to-end
model gameplay remain separate acceptance work; offline replays are not those tests.

## Deterministic replay format

`tests/agent_control/fixtures/perception-v1.json` has `schema: 1`, a provenance
statement and ordered `frames`. Each frame contains a synthetic monotonic `at`,
server `result`, expected current names, a model reply and expected parsed action.
Optional `last_seen` records specify stale memory expected at that point.

The runner feeds each frame through production `SensesClient`, `summarize` and
`parse_decision`. It checks disappearance, coordinate rebasing, reappearance,
malformed target rejection and current-only target indexing. Additional cases
cover full snapshots, unchanged deltas, reset, expiry, bounds and failed reads.

All fixtures are invented. Do not commit raw server captures, player names/ckeys,
speech, tokens, host addresses or private runtime paths. A real capture needs
review and sanitization before becoming a fixture. Keep fixtures self-contained;
tests must not read historical source with `git show`.

```sh
python3 -B tests/agent_control/test_perception_replay.py
python3 -B scripts/ci_baseline.py unit --suite agent_control --output /tmp/agent-control.json
```

Visibility regression documentation and its opt-in native runner live under
`tests/agent_control/visibility/`. Compilation, offline source/projection tests,
isolated native behavior and live gameplay are distinct evidence. None authorizes
production feature activation.

## Benchmark decision

[#4025](https://github.com/Civ13/Civ13/pull/4025) made the keep-Python decision after
byte/type-parity checks of a narrow Topic boundary. Its historical run measured
about 58.4 microseconds per Python request and 24.4 microseconds in PHP. These are
in-process boundary timings, not real network, model, game-tick or end-to-end p95
measurements. The PHP worker remains a benchmark reference, not a replacement.

[#4056](https://github.com/Civ13/Civ13/pull/4056) subsequently changed Player Help's
polling and network worker. The old one-second-poll comparison is therefore
historical, not a measurement of current service latency. Real phase profiling,
CPU/RSS and sustained concurrency measurements remain conditional follow-up if a
Python-local bottleneck is demonstrated. No PHP port or speedup claim follows
from the perception/action changes.
