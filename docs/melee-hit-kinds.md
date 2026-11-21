# Melee hit kinds

Every melee hit, thrown object and unarmed or animal attack has a kind: cut,
pierce or blunt (`HIT_CUT`, `HIT_PIERCE`, `HIT_BLUNT` in
`code/__defines/damage.dm`). Armor resists each kind separately.

## Choosing the kind

`/obj/proc/get_hit_kind()` in `code/game/objects/hit_kinds.dm` returns the
object's `hit_kind` when set, otherwise `hit_kind_for(sharp, edge)`:

| Flags | Kind |
| --- | --- |
| `edge` set | cut |
| `sharp` set, `edge` not set | pierce |
| neither | blunt |

Types whose flags name the wrong kind set `hit_kind` in `hit_kinds.dm`:
spears, pikes, pilums, harpoons, rapiers and bayonets pierce; halberds and
naginatas under the spear path cut; the flag bayonet and the tes13 mace are
blunt.

Unarmed attacks use `hit_kind_for(attack.sharp, attack.edge)`, so claws cut
and punches are blunt. Kicks, shoves, boxing, grab headbutts and joint locks,
and chair collisions are blunt. Piranha, snake and sea-life bites pierce;
mammoth, zombie and tactical AI attacks cut. Traps, poured liquids and
generic animal attacks still check `melee`.

## Armor values

`armor_rating(armor, type)` reads `armor["cut"]`, `armor["pierce"]` or
`armor["blunt"]` when the armor list has that key, and `armor["melee"]`
otherwise. Other keys (`arrow`, `gun`, `bomb` and so on) never fall back.
`getarmor_organ` uses it for worn clothing and accessories, and armor plates
count toward the three kinds as they do toward `melee`.

Clothing reads its values through `armor_value(type)`, which gives family
armor its family values (`docs/armor-families.md`) and everything else
`armor_rating` of its own list.

Tested by `tests/melee_hit_kinds` (see its README).
