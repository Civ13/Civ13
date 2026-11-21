// Kinds of melee hit: cut, pierce and blunt (HIT_* in code/__defines/damage.dm).
// A hit's kind decides which armor value resists it. An armor list without a
// key for that kind falls back to its "melee" value, so armor that has not
// been given per-kind values protects exactly as before.

// Set on a type whose sharp/edge flags give the wrong kind of hit.
/obj/var/hit_kind = null

// Edged things cut, pointed things pierce, everything else is blunt.
/proc/hit_kind_for(sharp, edge)
	if (edge)
		return HIT_CUT
	if (sharp)
		return HIT_PIERCE
	return HIT_BLUNT

/obj/proc/get_hit_kind()
	if (hit_kind)
		return hit_kind
	return hit_kind_for(sharp, edge)

/proc/is_melee_hit_kind(type)
	return type == HIT_CUT || type == HIT_PIERCE || type == HIT_BLUNT

// The protection an armor list gives against one kind of hit.
/proc/armor_rating(list/armor, type)
	if (!islist(armor))
		return 0
	var/value = armor[type]
	if (isnull(value) && is_melee_hit_kind(type))
		value = armor["melee"]
	return isnum(value) ? value : 0

// Weapons whose sharp/edge flags name the wrong kind of hit.
/obj/item/weapon/material/spear
	hit_kind = HIT_PIERCE
/obj/item/weapon/material/spear/halberd
	hit_kind = HIT_CUT
/obj/item/weapon/material/spear/naginata
	hit_kind = HIT_CUT
/obj/item/weapon/material/twohanded/spear
	hit_kind = HIT_PIERCE
/obj/item/weapon/material/pike
	hit_kind = HIT_PIERCE
/obj/item/weapon/material/pilum
	hit_kind = HIT_PIERCE
/obj/item/weapon/material/harpoon
	hit_kind = HIT_PIERCE
/obj/item/weapon/material/sword/rapier
	hit_kind = HIT_PIERCE
/obj/item/weapon/attachment/bayonet
	hit_kind = HIT_PIERCE
/obj/item/weapon/material/tes13/mace
	hit_kind = HIT_BLUNT
/obj/item/weapon/attachment/bayonet/flag
	hit_kind = HIT_BLUNT
