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
- Profiles are bounded: AP adds at most 40 armor penetration and one layer of
  cover passage, HP has none. A matchup matrix (pistol, intermediate, full
  rifle and 12.7mm rounds against gun armor 0 to 200) checks that HP beats
  normal beats AP on unprotected targets, AP beats normal against some armor,
  and no residual exceeds the round's own damage. It is written to
  `ammo_matrix.json` in the evidence directory.
- A round the armor stops does no damage and applies no stun, shrapnel or
  instant-kill roll (60 eye shots into a gun-300 helmet), but still wears the
  armor. An unprotected hit applies the round's stun, and shrapnel lodges in
  the organ that was hit, not the chest.

Negative controls restore one old behavior each and must fail:
`--negative-control amplify`, `compound`, `negative-wear`, `unbounded-ap`,
`stopped-effects` and `stopped-embed`.

Part of issue #4443 phases 1 and 4; see `docs/firearm-armor-impact.md`.
