# Nomad raids

Admins can send a party of nomad raiders after a settled group of players.
Code: `code/modules/nomad_raids/nomad_raid.dm`. Test: `tests/nomad_raids/`.

This is phase 1 of the visitor plan: scripted raids started by an admin. There
is no random chance and no LLM voice yet.

## Admin verbs (Fun, R_FUN)

- **Start Nomad Raid** picks a target (the busiest settlement, a player, or
  the admin's turf) and a party size of 2 to 6 including the chieftain.
- **End Nomad Raid** sends the party home or removes it at once. Removed
  raiders drop what they stole where they stand.
- **Nomad Raid Status** shows the state, raiders standing and items taken.

Every start, state change and end is written to the admin log and shown to
online admins.

## How a raid plays out

1. **Spawn.** The party appears on open, outdoor, unroofed ground near the map
   edge closest to the target, on the same level, out of every player's sight.
   If that edge is more than 120 tiles away, it appears 120 tiles out on that
   heading. Edges too close to the target to hide behind are skipped. Players
   near the target hear distant war horns.
2. **March.** The chieftain walks to the target; the others follow. Being
   attacked starts the fight. After 10 minutes, or if nobody is home, the
   party turns back.
3. **Parley.** When an active player is within 10 tiles, the chieftain halts
   and demands tribute at their feet (5 worth per raider, at least 8). Paying
   in 90 seconds ends the threat: the raiders take only the tribute and leave.
   Attacking them, or letting the time run out, starts the fight.
4. **Assault.** Raiders fight the nearest awake person within 12 tiles.
   Downed people are left alone. The fight ends after 15 quiet seconds or 5
   minutes.
5. **Loot.** Raiders take loose items near the target (best value first) and
   open unlocked, unwelded crates and closets. They do not take worn clothing,
   items in hands, or anything locked, and do not damage buildings.
6. **Leave.** The party walks back and despawns near its spawn point, or once
   it is 40 tiles from the target, when no player can see it. Items it carries
   off are gone.

The party flees when the chieftain goes down or half the raiders fall. A
fallen raider drops everything they stole, plus their weapon and bag. A raid
lasts at most 30 minutes; after that, remaining raiders are removed and drop
their loot.

## Fairness rules

- One raid at a time on the server.
- Automatic targeting ("busiest settlement") only picks groups of at least two
  active, awake players, and skips any group with a member raided in the last
  two hours. Offline players are never targets.
- The target score adds the group's size, nearby roofs and walls, and the
  ecology activity heatmap when an admin has ecology spawning running.

## Persistence

Raiders and the raid are never saved (`should_save = FALSE`), so a restart
ends a raid. The controller does nothing while a save or recovery runs.
Items raiders carry are lost if the server restarts mid-raid, as if they had
escaped. Cooldowns are stored as `world.realtime` in `data/nomad_raids.json`
and never use `world.time`.

## Not yet covered

Raider gear is melee only (spear, iron spear or small sword by era). Ranged
raiders, an LLM chieftain who bargains, traders and random raids are later
phases.
