# Explosion remains above the ground

Explosions, demolished walls and pried-up floors used to leave the area base
turf (earth) on every level. On upper levels such as the Reichstag roof that put
diggable dirt in the sky, and players tunnelled down through it.
`code/modules/multiz/explosion_remains.dm` now leaves plating above the ground,
never replaces open air, skips shell scorching there, and tunnel digging refuses
turfs above the ground.

- `run.py --static-only` checks that the production callers use the helpers.
- `run.py --byond-bin <BYOND-516.1688-bin>` runs the production helpers in a
  16x16x4 offline world. `--negative-control dirt` (earth remains above the
  ground) and `--negative-control sky` (no open-air guards) must fail their
  named assertions.
- `map_audit.py` prints how every multi-level map's levels classify, using the
  same sampling as the game (every 4th tile, at least 1/20 open air). `--check`
  only verifies the known maps.
- `test_explosion_remains.py` is the offline CI suite (wiring + map audit).

Not covered: the real explosion engine, in-game rendering, and maps whose upper
levels have less than 1/20 open air (they keep earth remains, as before).
