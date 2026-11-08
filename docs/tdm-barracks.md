# TDM Barracks and battle worlds

TDM runs as a region group of two worlds (shard kinds `BARRACKS` and `BATTLE`,
code in `code/modules/tdm_barracks/`):

- **Barracks** (port 1714, listed on the hub): always up and never rebooted for
  a round. Players arrive here, practise, follow the battle, and keep their record.
- **Battle** (port 1715, hidden from the hub): runs the TDM rounds and the map vote.

Val chose the ports and the name on 2026-11-08: the Barracks keeps the address
everyone already uses, so players never hit a dead port while a map loads.

## How players move

1. The battle world reports its state to the Barracks every 10 seconds, and at
   once when its phase changes: map, era, mode, phase (`pregame`, `playing`,
   `finished`, `returning`, `rotating`), countdown or round clock, players per
   side alive and fielded, the win condition text and scores.
2. When a battle forms (`pregame`), the Barracks announces it with a join link.
   **Join Battle** links the player to the battle world, where they ready up and
   pick a job on its usual pregame screen; during a round the same link joins late.
   **Auto-join Battle** sends the player to every new battle when it forms.
3. When the round ends the battle world shows its end screen and runs the map
   vote as before. At reboot it sends every player's round to the Barracks,
   links everyone back to the Barracks, and only then reboots, after waiting for
   the voted map to compile (see the shard-group README).
4. **Return to Barracks** (OOC) leaves a battle early.

Joining wakes a sleeping battle world through the doorman, and both worlds use
the routing relay when the group has one (`shard_group.send_player`).

## Records

At the end of each round the battle world sends, per player: key, character
name, side, kills, deaths, seconds alive on a side, and win, loss or draw (the
round's winner against the player's side; no winner is a draw). A kill counts
for the last human who harmed the dead (`last_harmed`, else `lastattacker`),
never for a team kill. The Barracks adds each round to the player's record in
`data/tdm_barracks/stats.json` (rounds, wins, losses, draws, kills, deaths,
best single battle, time in battle, auto-join) with the last 10 battles. This
file is the only thing the Barracks keeps; neither world saves.

Players see it with **My Battle Record** and **Leaderboard** (most kills, most
wins, best kill ratio over 5+ battles, best single battle, most time in battle),
and the **Battle Status** panel shows the live battle and recent battles.

## Running it

See [the shard-group README](../scripts/shard-group/README.md#tdm-barracks-and-battle-worlds)
and `scripts/shard-group/tdm.example.json`. The reports travel over loopback
with the group token `config/tdm-token.txt`, so both worlds must run on one host.
