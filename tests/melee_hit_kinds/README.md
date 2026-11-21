# Melee hit kinds

`python3 tests/melee_hit_kinds/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and checks, on a 6x4x1 world:

- `hit_kind_for` maps edged to cut, pointed to pierce and the rest to blunt.
- Real weapons hit as the right kind, including the `hit_kind` overrides for
  spears, pikes, rapiers, bayonets and mace-like items whose flags are wrong.
- `armor_rating` reads a `cut`, `pierce` or `blunt` armor key when present and
  falls back to `melee` otherwise; other keys never fall back.
- Armor without a family (`tests/armor_families` covers the families) gives
  the same protection against every kind as its melee value.
- A weapon hit on a human is resisted by the armor value for its own kind: a
  cuirass with only cut armor stops a sword but not a spear or a mace.

Negative controls restore one old behavior each and must fail:
`--negative-control weapon-melee` (weapon hits checked against `melee`),
`no-fallback` and `no-override`.

Part of the armor rework (cut, pierce and blunt), phase 1.
