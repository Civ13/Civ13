# Naval mines and the hull magnetic signature

Code: `code/modules/naval/naval_mines.dm`, `code/modules/naval/magnetic_signature.dm`.
Test: `tests/naval_carrier/mines_probe.dm`. Sprites: `icons/obj/naval_mines.dmi`,
drawn by `tests/sprites/create_naval_mines.py`.

## Mines

A mine is a heavy item (`/obj/item/naval_mine`, `/obj/item/naval_mine/magnetic`).
Clicking an open water tile next to you with it in hand lays it after five
seconds; it becomes a structure (`/obj/structure/naval_mine/*`) moored under
the surface. It cannot be laid on land, ice, a hull or a tile with another mine.

| Mine | Research | Fires when |
| --- | --- | --- |
| Contact | Naval Mines | A hull's box covers its tile |
| Magnetic | Magnetic Mines & Degaussing | felt signature / max(1, d)^2 >= 15, d <= 4 tiles |

A mine goes off when shot, caught in a blast or hit with anything but a
wrench. A wrench disarms it (8 seconds, a dexterity roll; failing sets it off)
and gives the item back.

When a mine fires, the blast (`explosion()` 1/2/4 for contact, 1/3/5 for
magnetic) is centred on the hull tile nearest the mine, so a magnetic mine
breaks a keel from below. Each body also takes `mine_damage()`: modular boats
lose frame armour like an anti-tank mine, and a submarine springs two leaks.

## The check

Nothing ticks. `craft.check_naval_mines()` runs after every move: from
`craft.on_hop()` for turf-built ships and built hulls, and from the modular
ship movement loop for boats and submarines. It looks only at mines on the
craft's level and within 4 tiles of the box she swept since her last check
(her old box and new box together), so a six-tile hop cannot jump a mine.

Mines answer `craft_left_behind()` TRUE: vessels, built hulls, `aboard()` and
modular boats never carry them, and modular boats do not crush them.

## Signature

`craft.magnetic_signature()` = `body.magnetic_base()` x `craft.magnetic_factor()`.

| Body | Base |
| --- | --- |
| Turf-built ship | `vessel.magnetic_base`: freighter 140, carrier 600, schooner 0 |
| Built hull | 1 per metal floor or wall (`obj/covers/magnetic_hull()`), +5 per running engine |
| Modular boat | 2 per steel ship frame, 1 per non-ship frame, 0 per wooden ship frame, +5 with the engine on |

A Scout submarine is 30, an Explorer 42. The tiller, the turf-built ship's
chart and the submarine systems report read it as none, faint (< 20), strong
(20-100) or very strong. `magnetic_factor()` is 1 until degaussing lands.
