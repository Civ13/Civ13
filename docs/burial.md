# Buried alive

`code/modules/1713/burial.dm`, with the grave in
`code/game/objects/structures/religious.dm` (`cover_grave()`, `uncover_grave()`).

Filling a grave with a shovel buries everything on its tile. Any living human,
whether lying in the open or shut in a coffin (`/obj/structure/closet/coffin` and its
sarcophagi), is buried alive (`burial_start()`). The dead are laid in as
before. A buried person sees the grave and nothing else.

- Air (`burial_air`, life ticks): 90 in a closed coffin, 10 (a held breath)
  in bare earth. Each life tick uses one. When it runs out, the person takes 5
  oxygen damage every life tick until they die or are freed. Before this,
  they suffocated once, 30 s after burial, and were then stuck for good.
- Clawing out: Resist while buried (`burial_resist()`, which runs before the
  closet breakout). In a coffin, 4 presses force the lid first. A locked or
  welded coffin will not give, so a nailed coffin can only be opened from
  outside. Then 15 successful presses claw up through the earth, each
  succeeding with chance 70% x strength coefficient, and 30 under a burial
  mound. Every press costs 2 air. Breaking out uncovers the grave, opens the
  coffin and trains strength.
- Digging the grave up (`uncover_grave()`) frees everyone in it, clears a
  raised mound back to an open grave and logs nothing new. Filling a grave and
  clawing out are logged with `log_game`.
- Saves: `buriedalive`, `burial_air`, `burial_work` and `burial_lid_forced`
  are ordinary saved vars. Each life tick re-checks that the person is still in
  a closed grave (`burial_grave()`), puts their view back on the grave, and
  frees them if they are anywhere else.

## Tests

- Native: `python3 tests/ecology_spawning/run_linux.py . tests/burial/probe.dm`
  (pinned BYOND).
- Offline: `python3 -m unittest tests/burial/test_burial.py`.

Not established: real client view and Resist clicks, and a buried person
surviving an actual save and load.
