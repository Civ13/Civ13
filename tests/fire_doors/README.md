# Fire doors

`python3 tests/fire_doors/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 12x12 world with
real humans, walls and doors, checks `code/game/objects/structures/fire_doors.dm`
and the fire hooks in `door.dm`, `door_fittings.dm` and `1713/oil_fires.dm`:

- a fire door set between stone walls is rated while shut; in a wooden wall,
  or standing open, it is not;
- fire can't spread onto the tile of a rated door, and spreads past an
  unrated one;
- a rated door takes a small share of a fire's heat, a wooden door all of it;
- the closer of a fire door can't be taken off;
- nearby fires share a five-second rating interval, then the seals burn
  when the budget is exhausted; overlapping repairs consume only the first
  successful set of replacements;
- a fusible link holds the door open past its closer until fire comes within
  two tiles, then melts and the door shuts; a hand unhooks it;
- a panic bar needs a screwdriver, goes on the fitter's side, and from that
  side alone opens a locked and bolted door;
- the steel fire door is rated longer;
- no runtime errors.

It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).
