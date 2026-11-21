# Door locks

`python3 tests/door_locks/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 12x12 world with
real humans, doors, crates and a basket, checks
`code/game/objects/structures/key_doors/fitted_locks.dm` and the door facing
in `door_fittings.dm`:

- a door on open ground has no inside until the builder picks one, and its
  facing text tells the reader which side they are on;
- a warded lock gives up its key, needs a screwdriver to fit, puts its keyhole
  on the fitter's side and the hinges on the other;
- only its own key locks and unlocks it (a tumbler key with the same cut does
  not); the far side has a thumb-turn; a key blank filed to the key opens it;
- a locked door cannot be taken down from outside; from inside, unlocked, it
  comes down and the lock is returned;
- a pen label shows after the key's own name, replaces rather than stacks,
  leaves the cut and family alone so the key still locks and unlocks, is carried
  by a filed copy, clears back to the original name when empty, and can only be
  written with the pen in hand on a key the writer holds or stands beside (not
  one inside a container);
- a spring latch locks itself when the door shuts;
- a padlock fits a crate with no tool, keeps it shut, and a crowbar on harm
  intent breaks it;
- a jail door built without a key takes a padlock, locks with its key and
  returns the padlock when dismantled; a jail door keyed when built refuses a
  warded lock but takes a padlock, and each key works only its own lock;
- a clay seal stops nobody and breaks on opening; a knot ties and unties; a
  hidden catch lets its maker in and stops a stranger;
- no runtime errors.

It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).
