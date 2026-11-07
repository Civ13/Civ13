# Gun sprite states after unloading

A gun asks for a different sprite when it is unloaded or opened, usually
`"<base_icon>_open"` (and `_empty`, `_open_empty` for launchers). Many icon
files have no such state, and BYOND then draws its error icon on the ground,
in hand, on the back or on the shoulder. `code/_helpers/sprite_states.dm`
falls back to a state the file does have: the name with those suffixes dropped
one at a time, then the gun's `base_icon`, `item_state` and `icon_state`
defaults. The in-hand, back and shoulder overlays in
`code/game/mob/living/carbon/human/update_icons.dm` apply it for every item,
and guns settle their own `icon_state` in `update_held_icon()`.

`python3 -B -m unittest discover -s tests/gun_icon_states -v` runs offline (the
`gun_icon_states` CI suite). It checks that every gap in `known_missing.txt`
is still missing from its DMI file and that the render paths keep the
fallback.

`python3 tests/gun_icon_states/run.py --byond-bin <BYOND bin>` is the runtime
sweep. It compiles the production game with normal startup disabled, builds
all gun types and calls `update_icon()` as spawned, unloaded, and with
`bolt_open`, `cover_open`, `cover_opened` or `open` toggled. It fails on a
state that is still missing after the fallback and not listed in
`known_missing.txt`, and on a listed gap that no longer happens.
`--negative-control` disables the fallback and must fail. The remaining
listed gaps are guns with no sprite at all in that file (art gaps).
