# Dead animal sprites

A killed simple animal must show `icon_dead`, and the state must exist in its
icon file. Sheep and camels used to redraw their standing sprite in
`update_icons()`, which `death()` calls through `update_canmove()`, so a dead
ram looked alive. Young animals also "grew up" five minutes after birth even
when dead, and a sheared sheep corpse regrew its wool. Overrides now set
`icon_state` only while alive and let the base proc in
`code/game/mob/living/simple_animal/riding.dm` show `icon_dead`; the timers
skip a corpse.

`python3 -B -m unittest discover -s tests/animal_dead_states -v` runs offline
(the `animal_dead_states` CI suite). It checks that every gap in
`known_missing.txt` is still missing from its DMI file, that no simple animal
`update_icons()` override sets `icon_state` without checking `stat`, and that
the grow-up and wool-regrowth timers skip dead animals.

`python3 tests/animal_dead_states/run.py --byond-bin <BYOND bin>` is the
runtime sweep. It compiles the production game with normal startup disabled,
builds every `/mob/living/simple_animal` type as an adult and as a lamb, calf,
piglet, baby deer or sheared animal where it has that variable, kills it, then
calls `update_canmove()` and `update_icons()`. It reports a corpse still drawn
with another state (`STANDING`) and an `icon_dead` missing from the icon file
(`MISSING`), and fails on any not listed in `known_missing.txt` or on a listed
gap that no longer happens. `--negative-control` makes the base proc draw
`icon_living` on a corpse and must fail.

The remaining listed gaps are abstract base types, a type deleted on death, an
unused type with no sprite, and two dead sprites still to be drawn
(`bullterrier_dead`, `shrieking_shrub_dead`).
