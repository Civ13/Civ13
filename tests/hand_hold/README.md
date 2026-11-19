# Body-part grabs and holding hands

`python3 tests/hand_hold/run.py --byond-bin <BYOND bin>` compiles the committed
game sources with normal startup disabled and, on a 12x12 world with real
humans, checks `code/game/mob/grab_hand_hold.dm` and its hooks in
`code/game/mob/grab.dm`:

- a grab records the targeted part, and messages name it (a full hand is
  taken by the wrist);
- grabbing an empty hand holds it: both people get a hand, and either one
  dropping theirs, or a resist, lets go on both sides;
- reinforcing makes the grip firm and goes no further; the held person's other
  hand stays free and they can still move, but only to tiles beside the grabber;
  an ordinary reinforced grab still holds them in place;
- the held person can't drop a firm grip, and each try is a resist that
  eventually frees them; passing out lets go;
- full hands, sleepers and other parts take an ordinary grab, which still
  reinforces to a neck grab; a missing part can't be grabbed;
- no runtime errors.

Random outcomes are retried until they happen. It needs the pinned compiler
(`bash scripts/cloud_byond_setup.sh`).
