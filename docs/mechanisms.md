# Mechanisms

Code: `code/modules/1713/mechanisms.dm`. Sprites: `icons/obj/mechanisms.dmi`,
drawn by `tests/sprites/create_mechanisms.py` (edit the script, not the DMI).
Probe: `tests/mechanisms` (see its README).

Triggers are tied by cord to actuators. Use rope on a trigger to pick
something within 7 tiles on the same level to tie a cord to (one rope a cord,
4 cords at most), or to cut a cord (the rope comes back). A cord is saved on
the trigger as an offset (`links`, `"dx,dy;dx,dy"`); the actuator on that
tile is looked up at each pull. Nothing ticks.

| Trigger | Recipe | Research | Pull |
| --- | --- | --- | --- |
| Lever | 3 wood | Basic Toolmaking | Thrown: open/drop/raise. Thrown back: shut. |
| Pull cord | 1 rope | Basic Toolmaking | One pull: toggles each door or gate |
| Pressure plate | 3 stone, set from the hand | Field Defenses | One pull when a stranger or a medium or larger animal steps on it; the setter's people (name, civilization, or side on team maps) pass safely |
| Tripwire alarm | existing | Basic Toolmaking | Rattles and gives one pull |

| Actuator | What a pull does |
| --- | --- |
| Door, window, shutter, trapdoor (not keypad, key slot or faction doors) | Opens or shuts; a bar, a locked lock or `locked` holds it shut |
| Castle drop trapdoor | Drops or shuts |
| Gate winch | Raises or drops its gates at once |
| Bell | Rings an alarm (not on a lever thrown back) |
| Rock drop (6 stone, Field Defenses) | Stones fall on its tile: 15 brute, armour applies, knockdown. Hung up again by hand (4 s) |

A plate or cord waits 2 s between pulls. This is the first PR of the
primitive automation plan; shafts, hopper mills, timers and the circuit
bridge come later.
