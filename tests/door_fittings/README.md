# Door fittings

`python3 tests/door_fittings/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 12x12 world with
real humans and doors between solid tiles, checks
`code/game/objects/structures/door_fittings.dm`:

- the door finds its passage axis from the walls beside it and tells its two
  sides apart; a shut door seals its room, an open one does not;
- a fitting needs its tool in the other hand; a spring closer shuts the door
  4 s after it opens, but never while someone stands in the doorway, even
  if they arrive during the closing animation; it retries once they leave;
- a wedge holds a self-closing door open; pulling it out takes it back to the
  hand, kicking it out drops it, and the door then shuts; a door in motion
  leaves a wedge or fusible link in the player's hand;
- the closer comes off with its own tool only and is returned;
- spring hinges shut the door a second after it clears; holding it on grab
  intent keeps it open until the holder drops the hold or walks away;
- the hydraulic delay is clamped to 2-10 s;
- a locked door takes no fittings and can't be taken down;
- taking a wooden door down with a hammer returns its fitting and three
  quarters of its wood; a destroyed door drops its wedge;
- no runtime errors.

It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).
