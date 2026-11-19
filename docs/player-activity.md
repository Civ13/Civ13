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
| `hb` | every 5 minutes per player: `a`/`anon`, `act` (1 active, 0 idle over 5 minutes), `st` (lobby, alive, asleep, dead, observer; asleep is a sleeping or unconscious character) |
| `health` | every 5 minutes: `p` players, `living` owned living characters, `dil` time dilation %, `cpu`, `era` |
| `save` | `ok`, `sec` seconds |
| `death` | `a`, `cause` (player, npc, starved, thirst, cold, heat, disease, burned, drowned, suffocated, poison, wounded, unknown), `by` killer account for player kills, `tod`, `season`, `fac`, `smin` session minutes, `gib`, `agent` |
| `depart` | `a`, `to`, `how` (trail, edge, ship, aircraft, lander, train, raid, admin) |
| `arrive` | `a`, `from`, `how`, `back` when a refused trip came home |
| `refused` | `a`, `to`, `why` (destination_down, too_much, too_far, busy, no_account, closed, other) |
| `learn` | `a`, `node` research node a character newly learned |
| `node_done` | `fac`, `node`, `era` when it moved the world into a new era |
| `faction_found`, `faction_join`, `faction_leave` | `a`, `fac` |
| `first_craft` | `a`, `type`: the first time since this boot anyone made that recipe |
| `tutorial` | `a`/`anon`, `step` (each tutorial step id, then `finished`) |
| `voyage` | `a`, `kind` when a boat sets out from a tiller |
| `reach` | once a day: `levels`, level number to [visited chunks, all chunks] from the visited record; no per-player data |
| `counts` | `a`, `c` counter name to amount since the last flush: `craft:<family>` (for example `craft:item/weapon`), `locked:<node>` when a hand action was refused for missing research, `use:<feature>` (atlas, crafting_within_reach, check_movement, player_help, click_route, tree_climb, signal_fire, voice, bug_report), `help:<outcome>` (ok, rate_limited, busy, failed, timeout; never the question) |
| `dropped` | `n` lines dropped because the 2000-line buffer was full |

The account is `account_key()`: the ckey for a BYOND key, `d:<discord id>` for
a launcher or verified player. Unsigned guests get a random `anon` id per
session. Host agents are marked `agent`. No IP, computer id, chat text,
coordinates or character names are written.

## The host database

`tools/player_activity/aggregate.py` reads every region's files into one SQLite
database. The host service does this every 15 minutes from `supervise()` into
`<group root>/player-activity.sqlite` (stamp file `player-activity.stamp`). It
never opens `coordinator.sqlite` or a transfer agent's store.

- Each file's read position is kept, so a re-run never counts a line twice and a
  half-written line waits for the next run.
- A past day's file is deleted once fully read; a compressed copy stays in
  `data/player_activity/read/` for 7 days.
- Event rows are kept 90 days, daily rollups per account and region 1 year, and
  per-account first and last seen until the account is forgotten.
- Times are stored in UTC from the file's date, `s` and the boot line's `tz`.
  Lines written just before local midnight that land in the next day's file are
  put back on the right day.
- A leave on one region and a join on another within 5 minutes count as one
  play session. Host agents (`agent@...`) are left out of player numbers.

Commands, run from the repository:

```
python3 tools/player_activity/aggregate.py --group <group.json> --db <root>/player-activity.sqlite
python3 tools/player_activity/aggregate.py --db <root>/player-activity.sqlite --report
python3 tools/player_activity/aggregate.py --db <root>/player-activity.sqlite --report --json
python3 tools/player_activity/aggregate.py --db <root>/player-activity.sqlite --forget <account>
```

Each host read also writes `<group root>/player-activity-weekly.json`: totals only
(active players, new players, sessions, deaths, trips, hours per region), never
account keys, research nodes or recipe types. The Discord bot's `<key>activity`
command shows it. While the recorder is on, the join message tells players in one
line what is counted.

In the launcher's Host tab, All regions > More > **Player activity…** shows the
same report. It runs `shard_group.py --config <group.json> activity`, which reads
new lines from every region first and says which regions have the recorder on.

The report shows active players for 1, 7 and 30 days, new players this week,
session count and median length, playtime per region, deaths by cause (all and
in the first session hour), travel between lands, refused trips, lag by player
count, peak players by hour, day 1 and day 7 retention, accounts that went
quiet, the new-player funnel (joined, finished the tutorial, crafted, learned
research, joined a faction, travelled, died, came back another day), tutorial
steps reached, research walls (nodes players were refused for most), crafting
by family, how many players know each research node, faction events, era by
region, how many recipes were made at least once, features used, AI help
outcomes, voyages and how much of each level anyone has reached.

Research node ids come only from `research_node.dm` and crafted types only from
the `config/crafting` recipe files; `tests/player_activity/test_source.py`
checks that neither holds anything from the hidden modules, and that those
modules never call the recorder. `--forget` deletes one account's rows, removes it as a killer from other
rows, and skips its lines in files not yet read.
