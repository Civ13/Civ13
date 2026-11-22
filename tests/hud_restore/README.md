# HUD controls after a restore

`python3 tests/hud_restore/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled, saves a human whose species HUD
list (`ProcessHUD`) lacks "combat stance", as a character saved before that
button existed, and loads the world. The restored character must have the
current list.

On 2026-11-22 the stance button (#6685) never showed on Gaia: the list was
saved with each character, so restored characters kept their old one. It is
now `var/tmp`, which the loader skips.

`--negative-control saved-process-hud` makes the list saved again and must fail.
