# Balcony railings

`python3 tests/balcony_railings/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 16x16 world,
checks `code/game/objects/structures/railing_built.dm`:

- every built railing kind is fixed down, has its sprite state, falls with its
  floor and is a building part for impacts;
- nobody walks off the edge a railing runs along, but can walk along it;
- one railing a side: a corner is allowed, a second railing or a parapet along
  the same side is refused, as are diagonals; other recipes are unaffected;
- shots fly over a wooden railing both ways; a stone balustrade lets shots out
  and covers someone lying behind it from about 30% of shots coming in;
- a hammer gives back the recipe cost (2 planks, 3 stone), a brick railing its
  bricks; a heavy impact or enough damage breaks a railing;
- no runtime errors.

The probe runs on `git archive HEAD`, so commit first. It needs the pinned
compiler (`bash scripts/cloud_byond_setup.sh`).
