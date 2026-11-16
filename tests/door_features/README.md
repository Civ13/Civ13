# Door features

`python3 tests/door_features/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 12x12 world with
real humans, walls, doors and a cat, checks
`code/game/objects/structures/door_features.dm` and its hooks in `door.dm`
and `door_fittings.dm`:

- a peep-hole needs a screwdriver, serves the fitter's side, and looks out
  one way only;
- every feature on a door serves the same side;
- a judas hatch slides only from its side, and open it lets both sides see
  through the shut door, even after the door opens and shuts again;
- papers posted from outside drop through the mail slot to the inside, into
  a crate standing there if there is one; nothing goes out through it, and
  only papers, photos and tiny things fit;
- a pet door lets a cat through the shut door but not a person, and locks
  only from its side;
- a screwdriver from the features' side takes one off and returns it;
- windows and shutters refuse them, and taking the door down returns them;
- no runtime errors.

It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).
