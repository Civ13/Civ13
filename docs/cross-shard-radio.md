# Cross-region radio

Radio inside one world is unchanged: a handset or a radio desk on a frequency
hears every broadcast on that frequency in its own world. This page covers the
one way a radio message crosses to another region of a shard group: a
long-range radio relay station on each side, both keyed to the same network,
both powered and both kept in repair.

Everything here is an independent Civ13 implementation. SS13's subspace
telecommunications (receivers, hubs, buses, processors, servers) was reviewed
and deliberately not ported: Civ13 has one frequency space per world, no
z-level gates and no radio datum pipeline, and the players build and maintain
everything in survival. What carried over is the shape of the idea, that the
infrastructure is a thing in the world that can be powered, worn, sabotaged
and repaired, and that an operator can see from the station itself whether the
far side is listening.

## For players

The **long-range radio relay** is a Modern age (2013) structure made from
electronics once the `factories` research node is complete. It needs:

- a laid cable with power (40 units, like the broadcast station);
- a broadcast antenna within one tile;
- a network key, set from the relay's menu: 1 to 16 characters of `a-z`,
  `0-9`, `-` and `_`;
- a condition above zero.

While it is on the air, every radio broadcast in this world on any frequency
is forwarded to the other regions, and every message those regions forward on
the same key is heard here by radios tuned to the message's frequency. The
listener sees the speaker's name, the far region and the far relay, for
example `Bea (via south mast, Beta Land)`. Languages carry across; a listener
who does not understand the language hears it scrambled as usual.

A relay in use wears out. Condition drops by 1 every ten minutes of running
time with players present, by 3 in rain and by 6 in extreme weather, and
explosions take a bite too. Below 40 the relay garbles what it carries;
at 0 it falls silent. Repair it, switched off, with electronics (25 condition)
or copper wire (10 condition); it takes crafting 100. A relay with no antenna,
no power, no key or no condition is simply off the air.

Examine a relay to see its key, its condition and the state of every other
region: down, asleep, no key set, no working relay on this key, or linked with
the far relay's condition. A region whose relay is off the air hears nothing
and is heard by nobody, so both sides have to keep their station tended.

Each relay forwards at most ten messages every ten seconds; anything beyond
that is heard locally only. Messages are limited to 256 characters.

## For hosts

The link uses the transfer agent each region already runs for travel
(`tools/transfer_storage/README.md`). Nothing new has to be started:

- the world posts each outbound message to its agent (`/radio/send`) and
  polls arrivals (`/radio/inbox`) once a second while a relay is on the air;
- the agent keeps an in-memory ring of 200 envelopes per direction, each good
  for 30 seconds, and drops duplicates, stale envelopes, messages from
  unknown regions and messages for the wrong group;
- the coordinator moves envelopes between agents every second
  (`--radio-interval`, independent of the five-second ledger pass) along with
  each region's relay heartbeats, which is how a world can show whether a
  peer's relay is up.

Nothing is written to the ledger or to any save. A restart of the world, the
agent or the coordinator loses whatever was in flight, which for a chat line
is the right trade. A sleeping region's agent keeps answering, so messages
queued for it expire unheard rather than waking it, and its relay stops
heartbeating so other regions show it as unlinked.

The world never listens for pushes: `world/Topic` rate-limits callers to one
request every two seconds per address and bans repeat offenders for the round,
so the agent cannot deliver by Topic. Polling costs one loopback request a
second only while a relay is on the air.

The relay's key and condition save with the world. Condition is a plain number
and never a `world.time` stamp. The outbound rate window is runtime only.

Agent control's `logs` action with `kind` `radio` returns the last 200 relayed
lines in and out, with the speaker's key, the region and the relay.

## Protocol

Envelope fields, all validated on both sides (`tools/transfer_storage/radio.py`):

| field | meaning |
| --- | --- |
| `id` | agent-assigned, deduplicated per region |
| `group`, `source` | the shard group and the sending region |
| `key` | network key; only relays on this key hear it |
| `frequency` | 150 to 300, or a named faction channel as text |
| `name`, `message`, `language`, `verb` | what the listener hears |
| `relay`, `condition` | the far relay's name and condition, shown to listeners |
| `ckey` | for the receiving world's log only |
| `age` | seconds since it was heard, so stale envelopes expire in transit |

Routes on the agent: `/radio/send`, `/radio/heartbeat`, `/radio/inbox`,
`/radio/status` (the world's side) and `/radio/outbox`, `/radio/deliver` (the
coordinator's side). All require the agent token like every other route.

## Later

- Sleeping worlds: once the host service exposes sleep state, the examine line
  shows `asleep` from that instead of from the missing heartbeat.
- Space: a satellite dish and a station transceiver (2026 age) link a surface
  region to a station region over the same envelope path, with the station's
  own relay condition tied to its habitat ledger. See
  `docs/space-settlement-roadmap.md`.
- Telephones over the link, as a keyed trunk between two exchanges.

## Tests

- `python3 -I -B tests/transfer_storage/run.py` covers the ring, the agent
  routes and the coordinator fan-out (`test_radio.py`).
- `tests/modern_telecom/game.dm` builds a relay in the telecom fixture and
  checks keying, power, wear, garbling, the send window, arrivals through a
  tuned handset, every drop rule and the saved key and condition
  (`tests/modern_telecom/run.py --byond-bin <pinned bin>`).
