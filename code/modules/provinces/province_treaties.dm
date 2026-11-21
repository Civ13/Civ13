// Nation treaties and provinces (docs/provinces.md, "Treaties"). Treaties
// (tools/transfer_storage/nation_treaties.py, read here from the nation
// snapshot) bind only nations; a faction outside a nation keeps the plain
// rules, and windows are unchanged.
// - Allies and pact partners never contest each other's provinces: stake
//   from one does not count as a rival to the other (province_holding.dm).
// - A nation may besiege another nation's province only while at war with
//   it; peace, a pact or an alliance calls a declared siege off with no
//   cooldown and the deposit kept (province_siege.dm).
// - Allies of the holder at the seat defend it; allies of the attacker who
//   are not also allied to the holder help the attack.
// Nothing here is stored: it reads nation_registry each call.

// The kinds of treaty in force between two province groups, or an empty
// list when either is not a nation.
/proc/province_treaty_kinds(group_a, group_b)
	. = list()
	if (!istext(group_a) || !istext(group_b) || group_a == group_b)
		return
	if (findtext(group_a, "nation:") != 1 || findtext(group_b, "nation:") != 1)
		return
	var/other = copytext(group_b, 8)
	for (var/list/R in nation_treaties_of(copytext(group_a, 8))["in_force"])
		if (R["other"] == other)
			. += R["kind"]

/proc/province_groups_at_war(group_a, group_b)
	return ("war" in province_treaty_kinds(group_a, group_b))

/proc/province_groups_allied(group_a, group_b)
	return ("alliance" in province_treaty_kinds(group_a, group_b))

// TRUE when group_a may not contest group_b's provinces (alliance or pact).
/proc/province_groups_friendly(group_a, group_b)
	var/list/kinds = province_treaty_kinds(group_a, group_b)
	return ("alliance" in kinds) || ("pact" in kinds)

// Why attacker may not besiege holder under their treaties, or null.
/proc/province_treaty_siege_block(attacker, holder)
	if (findtext(attacker, "nation:") != 1 || findtext(holder, "nation:") != 1)
		return null
	if (province_groups_at_war(attacker, holder))
		return null
	return "Your nation must be at war with [province_group_name(holder)] to besiege it: declare war under Nation > Foreign affairs."

// Which side a person at the seat stands for: "attack", "defend" or null.
/proc/province_siege_side(group, attacker, holder)
	if (group == attacker)
		return "attack"
	if (group == holder)
		return "defend"
	var/for_holder = province_groups_allied(group, holder)
	if (for_holder)
		return "defend"
	if (province_groups_allied(group, attacker))
		return "attack"
	return null
