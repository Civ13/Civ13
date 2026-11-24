# Practice rooms

From the lobby, a player can open a private practice room
(`code/modules/1713/practice_rooms.dm`, [docs/practice-rooms.md](../../docs/practice-rooms.md))
and follow nineteen scripted steps with a throwaway body.

```sh
python3 -B -m unittest discover -s tests/practice_rooms -v
python3 tests/practice_rooms/run.py --byond-bin <pinned bin> --evidence-dir <fresh dir>
```

`run.py` compiles the full DME without maps through the existing
`isolated_startup` adapter and runs `probe.dm` on a world of the tutorial
map's size (397 x 257): the practice level is admitted by `world_z_budget` and
added, other growth is refused while it exists, multi-z links skip it, a room
is built with walls, floor, area and props, each step is pending and then done
from the state its click leaves, the body has no saved owner, ending wipes the
room while another room keeps the level, reopening a room replaces its turfs,
the last player out removes the level, the save hook removes the level without
stale turf registrations, and the level can be added again.

The tutorial region (hand-made group) refuses Join, returns players to the
mainland and builds its 64 x 62 plot on the map's own ground level: lesson
rooms on one corridor line with every prop reachable on foot and the exit off
the path, the office private to its trainee, and the two yards. The stores
hand out full stacks to the plot's trainee only. The map's underground is
admitted and each plot is walled by bedrock on every underground level, so
tunnels and cave pockets stay inside; the building levels are admitted and the
trainee cannot step off the plot on any level; plans fit either yard on any
level and never cross the rooms or the wall. The press, airship, train (60
tiles of track), ship (5 x 5 and 29 x 40 hulls) and rocket exercises fit the
paved yard; switching at the desk clears both yards on every level (tunnels
refill, storeys go, the pool drains, the track lifts) and keeps the rooms and
stores; leaving clears the whole plot and keeps the levels; the map holds 24
plots and admits its full stack of levels; and other regions' lobbies send
players there only while it is up. No client joins: the lobby link, key
transfer, HUD clicks, step messages, tool digging and construction menus are
not driven.
