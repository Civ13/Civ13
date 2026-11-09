# Gunfire over hills

`run.py --byond-bin <pinned-bin>` compiles the production sources without maps
or normal startup into a 16x6 plating world, writes a height file with one case
per row and runs `probe.dm` once with real projectiles through `handleTurf`:

- A ridge between shooter and target stops the shot on the ridge; shrapnel gets
  no height line.
- On flat ground a wall stops a level shot and a level shot never passes over
  cover.
- From a hilltop the same wall lower down the slope is shot over, and the shot
  then lands in the ground beyond the target.
- A roofed tile under the line is passed over with its wall; the roofed wall
  still stops a level shot.
- Someone standing well below the line is not hit.
- Shooting up a slope at someone on the crest clears the hillside.
- NPC sight: `ai_check_los` and a wolf's `FindTarget` do not see a target
  behind the ridge, and do on flat ground.
- The cost of the height work per tile is printed.

`--negative-control ridge` (no ground stop), `cover` (walls ignore height),
`margin` (no body-height margin) and `npc` (target finding ignores hills) change
a generated copy; each must fail its
named check. Evidence goes to a fresh temporary directory. No client, save or
live server.
