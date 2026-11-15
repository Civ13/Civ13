# Siege engines and castle defences

Code: `code/modules/1713/siege/siege_engines.dm` (the trebuchet extends
`catapult.dm`). Art: `icons/obj/siege_engines.dmi`, `icons/obj/trebuchet.dmi`
and `icons/obj/siege_tower.dmi` from `tests/sprites/create_siege_engines.py`.
Probe: `tests/siege_engines/probe.dm`.

Siege Engines (313 B.C.) unlocks the ram, the ballista and its bolts, and the
siege tower. Fortifications (1013) unlocks the trebuchet, the portcullis, the
drawbridge, the gate winch and the murder hole. On TDM maps they work only once
the sides may cross (`siege_can_fight`).

- **Battering ram** (30 wood): push it up to a gate, door, barricade, castle
  gate or built wall and face it there. A swing takes 3 s and does 60 damage
  for each able person standing beside it, up to four (240). A gate (600) falls
  in three full-crew swings.
- **Ballista** (25 wood, bolts 2 wood): fasten with a hammer, load a bolt and
  loose it. The bolt flies straight along the facing for up to 24 tiles, does
  90 damage and passes through two targets.
- **Siege tower** (60 wood): push it against a wall and face it there. Lowering
  the drop bridge takes 3 s; then anyone beside the tower climbs it and lands on
  the first clear tile beyond the wall after 2 s. The tower is opaque, so the
  defenders can't see who is massing behind it. Moving or turning it raises the
  bridge.
- **Trebuchet** (80 wood): a catapult with a 30 to 140 tile range, a bigger
  blast and a 6 s wind-up.
- **Portcullis** (12 wood) and **drawbridge** (15 wood): castle gates that can't
  be moved by hand. A **gate winch** (8 wood) raises (4 s) or drops (1.5 s)
  every portcullis and drawbridge within two tiles. A shut portcullis stops men
  but not arrows; a raised drawbridge blocks sight as well. Both have 900
  health and take ram, explosive and weapon damage.
- **Murder hole** (3 stone): pour a container through it onto the level below
  (or, on a single level, the tile it faces). With a lit fire or brazier beside
  the hole the liquid is boiling: water burns for 8-12, oil (corn, olive or fat
  oil) for 20-30.

Moats need no new object: dig a ditch next to the wall and flood it with the
existing river and flood mechanics, then span it with a drawbridge.

**Undermining.** When a tile is dug or mined open on a level directly under a
wall, gate, door or barricade on the level above, the wall falls 30 s later
unless a mine support stands within one tile of that tunnel tile. Pulling out
or burning the prop brings it down at once. Natural rock walls are not
affected. Defenders countermine by digging toward the tunnel.
