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
| Shaft clutch (`transmission.dm`) | Thrown: in. Thrown back: out. One pull: toggles |
| Counterweight drum (`contraptions.dm`) | Thrown: releases. Thrown back: brakes. One pull: toggles |
| Relay (`contraptions.dm`) | Thrown: closes. Thrown back: opens. One pull: toggles |
| Hopper machine gate (`hopper_machines.dm`) | Thrown: opens. Thrown back: shuts. One pull: toggles |
| Sluice gate (`flood_defences.dm`) | Thrown: draws up. Thrown back: lowers. One pull: toggles |
| Mechanism port | Sends Pulled into its circuit |
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

## Bridges to electricity and circuits

A **relay** (3 copper, Electricity; `contraptions.dm`) is an actuator set on
the same tile as a lamp, outlet or other cabled device. Open, it cuts that
device's power through `smart_power_cut()` (`mechanism_relay_open_on`);
closed, the device draws again. A lever thrown over closes it, thrown back
opens it, and a pull cord or plate toggles it. It can also be thrown by hand.

A **mechanism port** (5 electronics, Digital Computing;
`code/modules/wiremod/shell/mechanism_port.dm`) is a circuit shell that is
both a trigger and an actuator while it lies on the floor:

- Rope on it ties cords like any trigger. A signal on its component's **Pull**
  input pulls them, at most once every 2 s; **Mode** picks `throw`,
  `throw back` or `toggle` (the default).
- A lever's or plate's cord tied to it fires **Pulled** and sets **Thrown**
  (FALSE for a lever thrown back), but only while a circuit is inserted.
- Picking it up drops its cords. Like the compact remote it is not saved.
