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
- Weapon roles: a blow the armor stops still bruises for a quarter of its
  force, a stopped blow wears the armor three times as much as a cut, and a
  thrust gets 10 extra penetration against mail and lamellar (not plate or
  armor without a family).

Negative controls restore one old behavior each and must fail:
`--negative-control weapon-melee` (weapon hits checked against `melee`),
`no-fallback`, `no-override`, `no-bruise`, `no-gap` and `no-blunt-wear`.

Part of the armor rework (cut, pierce and blunt), phases 1 and 3.
