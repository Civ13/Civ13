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

A plate or cord waits 2 s between pulls.

## Between levels

A **pulley block** (3 wood, Resource Processing) within a tile of a trigger
lets its cords reach actuators one level up or down (`multiz_level_above` /
`multiz_level_below`), same 7-tile square. Those cords are saved as
`"dx,dy,dz"` and only pull while a fastened pulley still stands beside the
trigger; without one they hang slack.

## Clock alarms

A water clock and a tower clock are triggers too. Tie cords with rope and use
the **Set Alarm** verb:

| Clock | Alarm settings | Pulls |
| --- | --- | --- |
| Water clock | off, or an hour | Once as that hour begins, while it holds water (checked on its 2 s drip) |
| Tower clock | off, every hour, or an hour | When it strikes, while wound |

`alarm_hour` is -1 off, 24 every hour, or 0 to 23. Both use the same pull as a
pull cord (toggle doors and gates, ring bells, drop rocks).
