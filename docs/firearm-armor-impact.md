# Firearm armor impact (issue #4443, phase 1)

## Residual damage

`/mob/living/bullet_act` resolves a projectile against `getarmor(def_zone, P.check_armor)`
through `projectile_armor_residual(damage, penetration, armor)`:

| Armor | Damage taken |
| --- | --- |
| 0 or less | the round's full damage |
| between 0 and the round's penetration | `damage * (1 - armor / penetration)` |
| at or above the round's penetration (or a round with 0 penetration) | none, with a ricochet sound |

Before this, armor below penetration multiplied damage by `penetration / armor`:
a gun-10 helmet took eight times a rifle round (penetration 80), and the
negative "absorbed" amount healed the armor. Armor now only removes damage, and
`damage_armor` ignores zero or negative wear. Wear stays `absorbed * 0.01`, so
unarmored hits wear nothing and a stopped round wears `damage * 0.01`.

Gameplay effect: light armor (gun 5 to 40) now reduces bullet damage instead of
raising it. Heavy armor at or above a round's penetration still stops it fully,
as before.

## AP and HP rounds

`/obj/item/projectile/proc/checktype()` records the round's base damage,
`penetrating` and `armor_penetration` the first time a profile applies and
derives AP (damage x0.7, penetration x3, `penetrating` doubled, at least 2) or HP
(damage x1.3, penetration /3, no passthrough) from them. A repeated call with
the same `btype` does nothing, a different `btype` starts from the base values,
and a casing's name carries one (AP)/(HP) suffix. The multipliers are unchanged;
bounded per-caliber profiles are phase 4.

## Secondary effects audit

Unchanged in phase 1 and recorded here for phase 4's single impact result:

- `P.on_hit(src, 0, def_zone)` applies stun/weaken/agony effects with
  `blocked = 0` even when armor stopped the round (`human_defense.dm` passes
  `blocked = 2` only for shields).
- Knockback and knockdown (`KD_chance`) roll before armor is checked, so a round
  stopped by armor can still knock the target down.
- Shrapnel embedding uses its own `max(P.damage - armor, 10)` chance, not the
  residual damage.
- Instadeath rolls for head, eyes and mouth happen regardless of armor.
- Shrapnel (`projectile.dm`) and bayonets (`gun.dm`) use helmet/armor-suit
  `block_check` or type checks, separate from armor values.
- Mob passthrough (`bullet/check_penetrate`) depends on `penetrating` and damage,
  not on the target's armor; walls use their own material chance.
- Simple animals override `bullet_act` and ignore armor; only humans wear armor.

Regression: `tests/armor_impact/run.py` (README there).
