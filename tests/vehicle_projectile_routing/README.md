# Vehicle projectile routing

Vehicle movement transports occupants and interior structures before its component
frames. Projectile collision must resolve frame armor before visiting those
occupants, regardless of the resulting turf.contents order.

The production change moves the existing frame-specific block into a prepass.
It preserves penetration math, angle classification, frame ordering, own-axis
turret immunity, untouchable exclusions, and the later generic structure pass.
It does not add roof-target classification or change armor values.

Run source preparation without a compiler or daemon:

```
<verified-python> tests/vehicle_projectile_routing/run.py --source-check
```

Native checks require allocated BYOND 516.1681 execution and distinct fresh output
directories:

```
<verified-python> tests/vehicle_projectile_routing/run.py --byond-bin <bin> --output <new-positive-directory>
<verified-python> tests/vehicle_projectile_routing/run.py --byond-bin <bin> --output <new-control-directory> --negative-control ordering
```

The full-game include graph supplies production handleTurf, CheckPen,
get_direction, get_wall_name, axis.do_move and forceMove. Normal world/controller
startup is disabled. A renamed immutable handleTurf from cc03b199128f8afed58713912c551ad7556e6bc4
provides frame-first callback parity for ordinary bullets, shells and missiles at
eight angles. The causal control compiles that same original collision procedure
and must fail after real vehicle movement places an occupant before its frame.

Additional checks cover protected mobs, a co-located turret and gunner seat,
dense interior structures, penetrated armor, multiple frames, null firers,
own-axis/start-tile immunity, and untouchable frames. Armor decisions use actual
frame procedures and trajectory setup uses the production plotter. Hit-roll,
frame damage, impact and explosion callbacks use counters; callback parity is
not full explosion, audio, projectile-process or human damage acceptance. Existing shell
callback behavior is compared rather than redesigned.

Each probe closes the native port in world.New(). This is not OS network isolation
and does not prevent a pre-world.New listener. CI uses the existing trusted runtime
policy and retains source hashes, compiler logs and fixture results for seven days.

The audit was motivated by SepuIka's RuCiv13 changes
[ad7d62c5](https://github.com/SepuIka/RuCiv13/commit/ad7d62c5a89e52783531080c65e41c0540a5bf63)
and [d8903804](https://github.com/SepuIka/RuCiv13/commit/d8903804f4c806607025a5c2db36db836e3e9fc8).
This fix reorders Civ13's existing block. It does not import the fork's absent
shooting_roof_object/handle_roof_hit architecture, direction replacement, debug
output, or frame destruction changes.
