# Practice rooms

From the lobby, a player can open a private practice room
(`code/modules/1713/practice_rooms.dm`, [docs/practice-rooms.md](../../docs/practice-rooms.md))
and follow nine scripted steps with a throwaway body.

```sh
python3 -B -m unittest discover -s tests/practice_rooms -v
python3 tests/practice_rooms/run.py --byond-bin <pinned bin> --evidence-dir <fresh dir>
```

`run.py` compiles the full DME without maps through the existing
`isolated_startup` adapter and runs `probe.dm` on a 60x40 world: the practice
level is admitted by `world_z_budget` and added, other growth is refused while it
exists, multi-z links skip it, a room is built with walls, floor, area and props,
each step is pending and then done from the state its click leaves, the body has
no saved owner, ending wipes the room, the save hook removes the level without
stale turf registrations, and the level can be added again. No client joins: the
lobby link, key transfer, HUD clicks and step messages are not driven.
