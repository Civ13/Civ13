# Player activity records

Each region can record who plays, for how long and what happens to them, so the
host can see who is active, what players have done and where they stop. Plan:
https://claude.ai/artifact/Rr7NGiEdMCwRaXtpbfP3PV

## Switching it on

Add `PLAYER_ACTIVITY 1` to the region's `config/config.txt` (the host overlay).
It is off when absent or 0. Nothing else changes when it is off.

## What the game writes

`code/modules/player_activity/player_activity.dm` buffers small JSON lines and
appends them once a minute, after every world save, when the last player leaves
(the host may freeze an empty world) and on restart, to
`data/player_activity/<yyyy-mm-dd>.jsonl` in the region's folder. The folder is
outside `data/logs/`, so the getlogs verb does not hand it out.

Every line has `e` (event) and `s` (seconds since the host's local midnight,
from `world.timeofday`). Each file starts with a `boot` line naming the boot id,
region, map and `world.timezone`.

| Event | Fields |
| --- | --- |
| `boot` | `v`, `boot`, `region`, `tz`, `map` |
| `join` | `a` account or `anon` id, `ck` (ckey when the account is a Discord key), `via` (byond, discord, guest), `staff` |
| `leave` | `a`/`anon`, `min` minutes connected, `why` (quit, travel, restart), `to` |
| `hb` | every 5 minutes per player: `a`/`anon`, `act` (1 active, 0 idle over 5 minutes), `st` (lobby, alive, dead, observer) |
| `health` | every 5 minutes: `p` players, `living` owned living characters, `dil` time dilation %, `cpu` |
| `save` | `ok`, `sec` seconds |
| `death` | `a`, `cause` (player, npc, starved, thirst, cold, heat, disease, burned, drowned, suffocated, poison, wounded, unknown), `by` killer account for player kills, `tod`, `season`, `fac`, `smin` session minutes, `gib`, `agent` |
| `depart` | `a`, `to`, `how` (trail, edge, ship, aircraft, lander, train, raid, admin) |
| `arrive` | `a`, `from`, `how`, `back` when a refused trip came home |
| `refused` | `a`, `to`, `why` (destination_down, too_much, too_far, busy, no_account, closed, other) |
| `counts` | `a`, `c` counter name to amount since the last flush |
| `dropped` | `n` lines dropped because the 2000-line buffer was full |

The account is `account_key()`: the ckey for a BYOND key, `d:<discord id>` for
a launcher or verified player. Unsigned guests get a random `anon` id per
session. Host agents are marked `agent`. No IP, computer id, chat text,
coordinates or character names are written. The aggregator (`tools/player_activity`,
next) reads every region's files into one host database and deletes them.
