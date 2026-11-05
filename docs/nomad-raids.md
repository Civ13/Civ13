# Nomad visits

Admins can send a party of nomads to a settled group of players: raiders who
demand tribute and fight if refused, or a trader caravan. Code:
`code/modules/nomad_raids/`. Test: `tests/nomad_raids/`.

The party members are human NPCs
(`/mob/living/simple_animal/hostile/human/nomad_raider`). They fight with the
shared NPC combat AI (target choice, cover, retreating when badly hurt,
calling for backup, pathfinding). A party controller (`nomad_visit.dm`)
decides when they may fight and where they walk. An optional LLM coordinator
can voice the leader and choose tactics through agent control; it only gives
orders the controller checks, and the visit plays out the same without it.
Visits are not started at random.

| File | Purpose |
| --- | --- |
| `nomad_raid.dm` | Settings, targeting, edge spawn sites, cooldowns, item worth |
| `nomad_raider.dm` | The NPC party member |
| `nomad_visit.dm` | The party controller: march, parley, assault, loot, leave |
| `nomad_trade.dm` | Trader caravans |
| `nomad_reputation.dm` | What the clans think of each player |
| `nomad_coordinator.dm` | What a coordinator sees and may order |
| `nomad_admin.dm` | Admin verbs |

## Crossing water

A party first checks that it can walk from its map-edge spawn to the target.
When it cannot (an island, a river with no ford), it comes by water instead
(`nomad_boats.dm`): it starts on unseen deep water at the nearest edge that
has a route with a single water crossing, each member on their own raft, and
paddles in single file at a raft's speed to the first dry tile by the target
(state `sail`, then `march`). The rafts stay moored at the landing. When the
party leaves, members walk back to the landing, board (a fresh raft replaces
a lost one) and paddle out, leaving the map where they came from. Party rafts
are never saved and are removed when the visit ends. A target with no route
by land or by one crossing gets the old behaviour: the party walks as far as
it can and the march limit sends it home. A coordinator may order a retreat
while the party is still afloat.

## Admin verbs (Fun, R_FUN)

- **Start Nomad Visit** asks for raiders or traders, a target (the busiest
  settlement, a player, or the admin's turf) and a party size of 2 to 6
  including the leader.
- **End Nomad Visit** sends the party home or removes it at once. Removed
  members drop what they carry where they stand; unsold goods are packed away
  and unspent payments handed back.
- **Nomad Reputation** lists players' standing with the clans and can clear
  one player's record.
- **Nomad Visit Status** shows the state, members standing, items taken or
  goods sold, and whether a coordinator is attached.

Every start, state change and end is written to the admin log and shown to
online admins.

## Raids

1. **Spawn.** The party appears on open, outdoor, unroofed ground near the map
   edge closest to the target, on the same level, out of every player's sight.
   If that edge is more than 120 tiles away, it appears 120 tiles out on that
   heading. Edges too close to the target to hide behind are skipped. Players
   near the target hear distant war horns.
2. **March.** The chieftain walks to the target (the middle of the targeted
   group); the others follow. Being attacked by people starts the fight; an
   animal's bite does not. After 10 minutes, or if nobody is home, the
   party turns back.
3. **Parley.** When an active player is within 10 tiles, the chieftain halts
   faces the nearest awake player, names them and demands tribute at their
   feet (5 worth per raider, at least 8). Paying
   in 90 seconds ends the threat: the raiders take only the tribute and leave.
   Only items laid down during the parley count; gear already lying nearby
   does not, unless someone picks it up and lays it at the chieftain's feet.
   Attacking them, or letting the time run out, starts the fight.
4. **Assault.** Raiders fight awake people near the target, preferring anyone
   holding a weapon. Downed people are left alone, and animals only when they
   attack first. The fight ends after 15 quiet seconds or 5 minutes.
5. **Loot.** Raiders take loose items near the target (best value first) and
   open unlocked, unwelded crates and closets. They do not take worn clothing,
   items in hands, or anything locked, and do not damage buildings.
6. **Leave.** The party walks back and despawns near its spawn point, or once
   it is 40 tiles from the target, when no player can see it. Items it carries
   off are gone.

The party flees when the leader goes down or half the party falls. A fallen
member drops everything they carried, and their weapon like other NPCs. A
visit lasts at most 30 minutes; after that, remaining members are removed and
drop what they carry.

Weapons follow the map's age: a spear, an iron spear, a small sword, and from
age 6 a revolver.

## Trader caravans

The caravan marches in like a raid, with caravan bells instead of horns. When
a player is near, the trader lays up to six goods on the tiles around them
(leather, pelts, bone, rope, bandages and meat; bronze and cloth, then iron
and an iron knife in later ages).

- **Paying.** Drop items at the trader's feet. Their worth is credited to
  whoever last handled them. Gear already lying near the stall when trading
  starts is not payment unless someone moves it.
- **Buying.** Pick up a good. If your credit covers its price, it is yours.
- **Theft.** Taking a good without enough credit gets a warning. Put it back
  or pay within 15 seconds, or the guards attack the thief.
- **Leaving.** After 12 minutes, or when sold out, the trader packs up and
  hands back payments that were not spent. Attacking the caravan also ends the
  trade and starts a fight.

Laid-out goods are not saved until sold.

## Reputation

The clans share what they think of each player (by ckey), whichever clan
visits:

| Deed | Change |
| --- | --- |
| Buying from a caravan | +1 |
| Paying a raid's tribute (each player near the chieftain) | +2 |
| Keeping a stolen good past the warning | -4 |
| Striking a party that had not drawn weapons (once a visit) | -3 |
| Killing a trader or guard | -6 |

Killing raiders who attacked is self-defence and costs nothing. The score is
capped at 30 either way and fades toward zero by one point per real day.

| Standing | Score | Effect |
| --- | --- | --- |
| Friend | 15 or more | Goods cost 25% less; a raid asks half the usual tribute when a friend is present |
| Trusted | 5 or more | Goods cost 10% less |
| Stranger | -3 to 4 | Normal prices |
| Distrusted | -4 or less | Goods cost 25% more |
| Wanted | -8 or less | Traders refuse their payments; raiders who see them attack on sight, going for them first |

Reputation is stored with `world.realtime` in `data/nomad_reputation.json`.
The coordinator sees each person's score and standing.

## Coordinator

A coordinator is an agent with the `visits` scope (see
[agent control](agent-control.md#nomad-visits)). While it reads
`visit_status` at least every 10 seconds, the controller's lines become cues
it has 8 seconds to say its own way, and it may order:

| State | Orders |
| --- | --- |
| march | `say`, `retreat` |
| parley | `say`, `bargain` (accept, counter, refuse), `retreat`; `assault` after 30 s |
| trade | `say`, `price`, `retreat` |
| assault | `say`, `tactic` (advance, hold, flank), `focus`, `retreat`; `loot` for raids |
| loot | `say`, `tactic`, `focus`, `retreat` |

Bounds the server enforces: speech is sanitized, at most 200 characters, and
once every 3 seconds; a counter-demand stays between half and double the
starting tribute and can be accepted only at the lower bound or above; a
refusal waits 30 seconds into the parley; a focus target must be an awake
person near the party; prices stay between half and double the starting
price. A coordinator cannot start a fight before the parley grace time, hurt
a downed person, or make the party take anything a scripted visit would not.

`tools/agent-control/visitor_voice.py` is a coordinator that uses the Player
Help Ollama model. Players' speech reaches the model as quoted data. It keeps
a short memory per player in `data/nomad-visit-memory.json` (who paid, fought,
bought or stole), so a later clan can remember them.

## Fairness rules

- One visit at a time on the server.
- Automatic targeting ("busiest settlement") only picks groups of at least two
  active, awake players, and skips any group with a member visited in the last
  two hours. Offline players are never targets.
- The target score adds the group's size, nearby roofs and walls, and the
  ecology activity heatmap when an admin has ecology spawning running.

## Persistence

Party members, the party and laid-out goods are never saved
(`should_save = FALSE`), so a restart ends a visit. The controller does nothing
while a save or recovery runs. Items the party carries are lost if the server
restarts mid-visit, as if they had escaped. Cooldowns are stored as
`world.realtime` in `data/nomad_raids.json` and never use `world.time`.
