# Transfer storage (phases 1 to 3)

`region.py` is the per-region SQLite store from
[TRANSFER-STORAGE-SQLITE.md](../server-management/TRANSFER-STORAGE-SQLITE.md).
It uses only the Python standard library and opens no network port itself.

- `RegionStore.enroll(peer, direction)`: the operator step that permits one
  direction with one peer.
- `begin_escrow`, `begin_import`, `begin_return`: record a tentative world
  effect. DM may change the world only after the call returns, and lists the
  returned effect ID in its next world save.
- `report_save` (after `save_complete.txt`) and `reconcile_load` (at world
  load): confirm the effects a committed save lists and void the rest. Loading
  a save older than the store's ledger puts the region on hold.
- `outbox()` and `receive(envelope)`: the messages between regions. A step's
  envelope enters the outbox only after its effects are confirmed.
  Retransmissions and stale steps change nothing.

`agent.py` serves one store over HTTP for DM (through `rustg_http_request_async`)
and the coordinator:

```
python3 tools/transfer_storage/agent.py --db transfers.sqlite --region gaia \
    --group pilot --port 47201 --token-file transfer-token.txt
```

It binds 127.0.0.1 only, refuses any other client address, requires the
token (at least 32 characters) in `X-Transfer-Token`, caps bodies at 1 MiB, and
handles one request at a time. Every route is a POST with a JSON body:
`/status`, `/outbox`, `/receive`, `/escrow`, `/import`, `/return`, `/abort`,
`/save` and `/load`. A refusal answers 409 with `ok: false` (and `held: true`
while the region is on hold).

`coordinator.py` keeps the region directory in its own SQLite file and moves
outbox envelopes between agents (`relay_once`). It holds no custody, and for
the pilot it only enrolls loopback agents.

## DM bridge (off by default)

`code/modules/persistence/transfer_bridge.dm` connects a world to its agent.
It stays off unless `config/transfer_agent.json` exists with a `port`
(1024-65535) and a `token_file` holding the same token the agent uses:

```
{"port": 47201, "token_file": "config/transfer-token.txt"}
```

When on, a world save writes `round_state["transfer"]` (generation, the effect
IDs applied in memory, and the last acknowledged ledger sequence) and reports
it to `/save` after `save_complete.txt`. A world load reports the loaded
capture to `/load`, retrying every minute until the agent answers. No effect
can be applied before that reconcile succeeds, while a save is running, or
while the region is on hold.

## Trade post (admin-placed)

`code/modules/persistence/transfer_trade_post.dm` adds
`/obj/structure/transfer_trade_post`. It has no recipe; an admin spawns it.
It stays closed while the bridge is off or `peers` is empty in the config:

```
{"port": 47201, "token_file": "config/transfer-token.txt", "peers": ["beta"]}
```

- A player hands it a stack of an allowlisted material (wood, stone, clay,
  rope, cloth, leather, copper, tin, bronze, iron, steel, silver or gold; exact
  types only, up to one full stack) and names the recipient's key. The post
  holds the stack while the agent records the escrow, then deletes it. If the
  agent refuses, or a save starts meanwhile, the stack is put back.
- Every 30 seconds the world asks its agent for committed arrivals and
  refused shipments. It imports them into the first trade post, under the
  recipient's key (or the sender's for a return). If that post was deleted
  during the request, a new one is built on the same tile.
- A player uses the post empty-handed to collect what waits under their key.
  Holdings are saved with the post.

Only the kind and amount travel, never the object, so no other field of a stack
crosses regions.

## Region travel (characters)

`code/modules/persistence/region_travel.dm` moves a player's character
through the same agent. It uses the payload kind `"character"`: JSON with the
identity, looks, skills, hunger and thirst, and up to 40 items.

- Only items that can be rebuilt exactly may travel: allowlisted material
  and medical stacks and coins by kind and amount; empty clothing, untouched
  packaged food and drink, syringes and pills, basic tools and unloaded
  projectile guns by type; and magazines as `ammo:<type>` with a count of
  their own live rounds. A gun is rebuilt unloaded. The gate refuses until
  everything else is left behind.
- The body waits inside the gate while the escrow is recorded. Then the body
  and items are removed and the player is sent to the destination server.
- `status` reports `pending_kinds` for each pending transfer, so the world
  can route a character to a gate or late-join point, not to a trade post.
- The arrived body keeps `region_arrival_pending` and the owner's key. It is
  saved with the world and handed over when that key joins. A refused trip
  rebuilds the character at the source the same way.
- Character effects are journaled (`fast`): the agent confirms them at once
  and sends the next step, so a trip takes seconds, not two world saves. The
  journal keeps each effect's payloads until a world save lists it. `/load`
  returns `replay`, the journaled effects the loaded save lacks; the world
  removes the departed body again (one durable body per account) or rebuilds
  the arrival, then lists them in its next save. Goods cannot be journaled,
  because a stack cannot be found again by owner.

## Home worlds (one land per player)

The coordinator also keeps the home ledger: the one region each account may
play in. `code/modules/persistence/region_home.dm` asks the region's agent
(`/account`) before an account starts a character, takes back a saved body or
claims a travelling one; anywhere else the player is told where their
character lives, with a join link.

- With `--mainland REGION` (the shard group always passes it), a new account
  starts only on the mainland. Elsewhere it is told to start there.
- A trip moves the home: the gate records `depart` (the source refuses a new
  character at once), and the arrival records `arrive`. A refused trip
  rebuilt at the source records `arrive` there, so the home comes back.
- A death records `release`, which sends the home back to the mainland unless
  the account still has a living character in that region, or an assigned bed
  there (Sleep in a bed assigns it). With a bed, nothing is recorded: the home
  stays and the next character starts at that bed.
- Each coordinator pass (`homes_once`, after the relay) reads every agent's
  queued requests (`/accounts`), decides each region's requests in the order
  it made them, with new claims after everything else, and sends each agent the
  ledger rows it has not seen (`/homes`). An agent that misses a pass catches
  up on the next; a request decided but not acknowledged is never decided
  again.
- Losing `coordinator.sqlite` starts a new ledger epoch: agents drop their
  copies and accounts claim their homes again. A region holding a living
  character of an unhomed account claims custody of it (`body` on the claim),
  so that character stays where it is; other accounts start on the mainland.
  Journal replays after a reload record nothing: the ledger already saw them.
- A trip, departure or death note keeps retrying (backing off to every five
  minutes) until the agent has it.
- A world's agent unreachable means no character can start there (the player
  is asked to retry). Guests are not tracked; they cannot travel.

## Player-built trails

Admins can still place `/obj/structure/region_gate` with a destination. Players
can build a **trail marker** from 10 wood (construction). It starts closed:
the first player to use it picks the land it should lead to, which notifies
the admins (Approve, Reject and Jump links). Each player may ask once every
ten minutes and have three requests waiting at most; only the asker may
change a waiting request. Unapproved markers never receive arriving
travellers, and players cannot dismantle gates. Admins also see waiting markers under OOC >
Regions. Approving confirms or changes the destination, and the marker then
works like an admin gate. The approval is saved with the marker
(`code/modules/persistence/region_trails.dm`). There is no ferry yet; a
player-made ferry can reuse the same approval later.

A **launch pad** (`code/modules/space/lander.dm`) is a trail marker that can
only lead to a region with a survey map in `config/space/survey/`, approved
the same way. Crew launch together from a crewed lander beside it; each
travels as an ordinary character payload with three extra fields (`lander`,
`landing` as a survey cell and the `surveyed`/`rough` flags), which the
decoder checks. The destination builds the landed lander for the first
arrival of a flight and puts the rest of the crew in it. A pad on a mapped
world may also lead home to the mainland: that flight carries only `lander`
and `"return": 1`, builds no lander and arrives like any traveller.

Group setup, autosave timing and agent startup are in
[scripts/shard-group](../../scripts/shard-group/README.md#travel-between-regions).

## Pilot command lines

```
python3 tools/transfer_storage/agent.py --db alpha.sqlite --region alpha --group pilot \
    --port 47201 --token-file alpha-token.txt --enroll beta:out --enroll beta:in
python3 tools/transfer_storage/coordinator.py --db coordinator.sqlite --group pilot \
    --region alpha=http://127.0.0.1:47201=alpha-token.txt \
    --region beta=http://127.0.0.1:47202=beta-token.txt
```

The coordinator relays every five seconds (`--interval`). A pass that can't
reach an agent is reported on stderr, and that agent's outbox waits for the
next pass.

## Cross-region radio

The same agent carries radio between regions whose long-range relays share a
network key (`docs/cross-shard-radio.md`). `radio.py` keeps an in-memory ring
of 200 envelopes per direction, each deliverable for 30 seconds, and the relay
heartbeats of this region and its peers. The world posts `/radio/send` and
`/radio/heartbeat` and polls `/radio/inbox` and `/radio/status`; the
coordinator drains `/radio/outbox` and fans each envelope out to every other
region's `/radio/deliver` once a second (`--radio-interval`, never longer than
`--interval`). Nothing touches the SQLite ledger: a restart loses what was in
flight, duplicates, stale envelopes, wrong-group envelopes and envelopes from
unknown or self regions are dropped and counted in `/radio/status`.

## Two-region pilot (phase 3)

`tests/transfer_storage/pilot/run.py` runs two DreamDaemon regions built from
the real `transfer_bridge.dm`, `transfer_trade_post.dm`, `http.dm` and the
transfer hooks in `functions.dm`, against two agents and a relay. Each region
keeps wood on a stock tile, ships stacks to the other region's player and
collects what arrives. Its save writes the world and `round_state["transfer"]`
and then a completion marker, as the world save does. The driver kills and
restarts the regions at random moments, drains every transfer, stops both
after a final save, and fails unless:

- the committed saves hold exactly the wood the run started with
- no transfer is in flight and no region is on hold
- no world logged a runtime error

```
python3 tests/transfer_storage/pilot/run.py --byond-bin ~/byond-516.1688/byond/bin \
    --rust-g librust_g.so --seconds 120 --seed 7
```

On Linux it needs the i686 `librust_g.so` from rust-g 3.0.0 (SHA-256 checked).
On Windows it uses the repository's `rust_g.dll`. The "Transfer storage"
workflow runs it when dispatched by hand. `--workdir` keeps the run directory.

Not here yet: envelope signing for agents on different hosts.

## Tests

```
python3 -I -B tests/transfer_storage/run.py
```

`tests/transfer_storage/sim.py` models two DM worlds around the store: an
in-memory item set, the last committed save, and crashes that reload that save.
The tests cover the failure cases listed in the design. `RandomFaults` adds 150
seeded runs of random transfers, saves, lost save reports, crashes, aborts, and
dropped or duplicated messages. After every step it checks that no item is live
in two worlds. At the end it checks that every item survives exactly once and
no transfer is stuck.
