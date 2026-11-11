# Firearm armor impact (issue #4443, phases 1 and 4)

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

## Round profiles (phase 4)

A cartridge's caliber decides which guns and magazines it fits. Its projectile
type holds that caliber's base damage, armor penetration and cover passage
(`penetrating`). A round profile in `code/modules/projectiles/ammo_profiles.dm`
then adjusts those base values within fixed bounds:

| Profile | Damage | Armor penetration | Cover passage |
| --- | --- | --- | --- |
| Normal | base | base | base |
| AP | x0.7 | x1.5, at most +40 (about one protection tier) | +1 layer |
| HP | x1.3 | x0.5 | none |

`checktype()` records the base values once and applies the profile from them,
so repeated calls never compound and switching profiles starts from the base.
Unknown profile ids fall back to normal. Before phase 4, AP tripled armor
penetration (a 7.62x51mm AP round reached 240 and passed every worn armor) and
doubled cover passage, and HP divided penetration by three.

## Protection tiers

Bullet armor (`armor["gun"]`) is shown on examine as a game protection tier,
measured against the standard penetration of each round class (pistol 40,
intermediate rifle 60, full rifle 80). Tiers are game terms, not real-world
ratings.

| Tier | Gun armor | Normal rounds it stops |
| --- | --- | --- |
| Light | 1 to 39 | none; it reduces damage |
| Medium | 40 to 59 | pistol |
| Heavy | 60 to 79 | pistol and intermediate rifle |
| Very heavy | 80 and up | full rifle; AP and heavy rounds still get through |

Casings describe their AP/HP tradeoff on examine, and magazines count their AP
and HP rounds.

## Single impact result

`/mob/living/proc/resolve_projectile_impact` resolves one hit once, in order:
armor on the hit zone, bounded residual damage, nonnegative armor wear, and
whether the armor stopped the round. The projectile keeps the result for that
target and zone (`impact_on`), so the human and living halves of `bullet_act`
read the same numbers. A stopped round:

- does no damage and plays the ricochet sound,
- still wears the armor by `damage * 0.01`,
- applies no stun, weaken or agony rider (`on_hit` gets `blocked = 2`),
- embeds no shrapnel, and
- makes no instant-kill roll for head, eyes or mouth.

Shrapnel now lodges in the organ that was hit; it always went to the chest
before. Its chance uses the residual damage, which equals the old value for
unprotected targets.

Kept on purpose, unchanged: knockback and knockdown (`KD_chance`) still roll for
a stopped round as blunt force; shields, grazing, taser effects and simple
animals keep their own paths; walls and structures use `penetrating` with their
own material chances, and vehicles use `heavy_armor_penetration`, so AP against
body armor never implies unlimited wall passage.

## Matchup matrix

Residual damage per hit, from the native probe (`ammo_matrix.json` in its
evidence directory). Columns are gun armor on the hit zone.

| Round | Profile | 0 | 10 | 30 | 50 | 70 | 90 | 130 | 200 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 9x19mm pistol | normal | 48 | 36 | 12 | 0 | 0 | 0 | 0 | 0 |
| 9x19mm pistol | AP | 33.6 | 28 | 16.8 | 5.6 | 0 | 0 | 0 | 0 |
| 9x19mm pistol | HP | 62.4 | 31.2 | 0 | 0 | 0 | 0 | 0 | 0 |
| 7.62x39mm intermediate | normal | 92 | 76.7 | 46 | 15.3 | 0 | 0 | 0 | 0 |
| 7.62x39mm intermediate | AP | 64.4 | 57.2 | 42.9 | 28.6 | 14.3 | 0 | 0 | 0 |
| 7.62x39mm intermediate | HP | 119.6 | 79.7 | 0 | 0 | 0 | 0 | 0 | 0 |
| 7.62x51mm full rifle | normal | 123 | 107.6 | 76.9 | 46.1 | 15.4 | 0 | 0 | 0 |
| 7.62x51mm full rifle | AP | 86.1 | 78.9 | 64.6 | 50.2 | 35.9 | 21.5 | 0 | 0 |
| 7.62x51mm full rifle | HP | 159.9 | 119.9 | 40 | 0 | 0 | 0 | 0 | 0 |
| 12.7mm heavy | normal | 265 | 251.7 | 225.2 | 198.7 | 172.2 | 145.7 | 92.8 | 0 |
| 12.7mm heavy | AP | 185.5 | 177.8 | 162.3 | 146.9 | 131.4 | 115.9 | 85 | 30.9 |
| 12.7mm heavy | HP | 344.5 | 310 | 241.1 | 172.2 | 103.4 | 34.5 | 0 | 0 |

HP wins against unprotected targets, normal in the middle, and AP once the armor
reaches roughly half the round's penetration. AP does not help heavy rounds
against worn armor until the armor reaches their base penetration.

Regression: `tests/armor_impact/run.py` (README there).
