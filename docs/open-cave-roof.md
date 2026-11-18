# Opening dug-out rock to the sky

Mountain rock on the surface lies in a cave area (`/area/caribbean/void/caves`),
so a mined tile stays roofed: no weather or sun, no outdoor crops, and the
cave-in rule needs supports. `code/modules/1713/open_cave_roof.dm` lets a
player with a pickaxe click a mined tile that touches open sky orthogonally;
after 12 s (divided by strength and pickaxe speed) the tile joins that
neighbour's outdoor area with `ChangeArea`. The roof clears from an open edge
inward, one tile at a time.

Balance (Fable review, 2026-11-18, `/mnt/project-files/open-cave-roof/`):
no drops and no strength xp (mining already paid for the tile), no cave-in
roll (an outdoor neighbour already supports a mine tile), pickaxe only, and a
tile holding a structure other than a mine support, a floor or another mob is
refused, so a cave base cannot be stripped from under its occupants.

Refused on the dug underground level, under a floor, roof or ground on the
level above, and on ore floors. Re-roofing uses the normal roof builder. The
area change is saved with the level's per-cell zone membership.
