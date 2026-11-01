# Vehicle HUD axis characterization

Run with a verified Python executable from the repository root:

```powershell
& $PythonPath -B -m unittest discover -s tests/vehicle_hud -v
```

The tests execute the complete three production handler bodies and the shared
resolver through the existing offline `tests/save_movement/source_adapter.py`.
Only type tests, parent callbacks, chat/sound output, screen writes and string
interpolation use inert Python boundaries. They do not launch BYOND, a client,
sound playback, processes or network services, and install no dependencies.

`fixtures/axis_handlers_before.dm` freezes the original HUD source at master
`4e26d5794fcf197a13111d1f40b637b7be962d61`. The original source bytes before its
two provenance comments have SHA256
`ed1afd743df9d769a2d796f88037a8146bb121e012bb465bc29b1de25fc66838`.
This is offline data, absent from every DME. Tests never read Git history.

Characterization compares absent parent, unbuckled/wrong chair, absent/wrong
axis, inherited chair/axis types, both directions, missing/off/on engines and
zero/positive/negative speeds. It checks unchanged invalid icons, parent-call
order, exact chat/sound/toggle/icon-update effects, repeated clicks and a parent
callback changing the driver's current axis. The resolver neither mutates nor
retains a resolved axis. It does not introduce a human-only admission gate.

Mutation controls remove each type gate, duplicate sound, reset invalid icons,
or move the parent callback after resolution; each must break characterization.
Wheel handlers and their distinct human/wheel requirements remain separate.

This refactor consolidates validation without a claimed FPS/performance gain.
DM compilation, connected-client input/rendering, native sound/timing and
vehicle gameplay acceptance remain separate and unexecuted in the offline lane.
