# Armor against projectiles

`python3 tests/armor_impact/run.py --byond-bin <BYOND bin>` compiles the
production game with normal startup disabled and checks, on a 6x4x1 world:

- `projectile_armor_residual` keeps damage between 0 and the round's own
  damage, falls as armor rises and stops the round at or above its penetration.
  Armor below a round's penetration used to multiply damage by
  penetration/armor, so a gun-10 helmet took eight times a rifle round's damage.
- A real human wearing a gun-40 helmet takes less than the round's damage from
  an 80-penetration shot, and the helmet loses health instead of gaining it.
  `damage_armor` ignores zero or negative wear.
- AP and HP profiles apply once from the round's base values, so repeated
  `checktype()` calls do not compound, switching profiles starts from the base,
  and a casing's name gets one (AP)/(HP) suffix.

Negative controls restore one old behavior each and must fail:
`--negative-control amplify`, `compound` and `negative-wear`.

Part of issue #4443 phase 1. Secondary effects (stun, knockdown, embedding)
still apply after armor as before; see `docs/firearm-armor-impact.md`.
