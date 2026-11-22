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
// - An overlord and its vassal (tools/transfer_storage/nation_vassals.py)
//   count as allies here. A siege won by one nation against another at war is
//   reported to the coordinator, which lets the winner impose vassalage.
// - Tribute: once every VASSAL_TRIBUTE_DAYS, each vassal member faction founded
//   in this world moves VASSAL_TRIBUTE_SHARE of its strongbox coin, at most
//   VASSAL_TRIBUTE_CAP, to the strongbox of an overlord member faction founded
//   here. Real coin moves; nothing is minted. With no such box here, none is due.
// State: map.faction_recruitment["vassal_tribute"]: faction id -> realtime of the
// last tribute. Everything else reads nation_registry each call.

#define VASSAL_TRIBUTE_DAYS 7
#define VASSAL_TRIBUTE_SHARE 0.1
#define VASSAL_TRIBUTE_CAP 100

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

// An alliance, or an overlord and its vassal.
/proc/province_groups_allied(group_a, group_b)
	var/list/kinds = province_treaty_kinds(group_a, group_b)
	return ("alliance" in kinds) || ("overlord" in kinds) || ("vassal" in kinds)

// TRUE when group_a may not contest group_b's provinces (allied, a pact, or vassalage).
/proc/province_groups_friendly(group_a, group_b)
	return province_groups_allied(group_a, group_b) || ("pact" in province_treaty_kinds(group_a, group_b))

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

// --- Vassals -------------------------------------------------------------------------

// Tells the coordinator that faction (a besieger) won a siege against holder.
/proc/province_siege_report(faction, holder)
	var/id = nation_faction_id(faction)
	if (!id || findtext(holder, "nation:") != 1 || findtext(province_group_of(faction), "nation:") != 1)
		return
	nation_send(list("op" = "siege_won", "actor" = "world", "faction" = id, "other" = copytext(holder, 8)))

// The overlord of nation nid, or null.
/proc/nation_overlord_of(nid)
	for (var/list/R in nation_treaties_of(nid)["in_force"])
		if (R["kind"] == "vassal")
			return R["other"]
	return null

// Moves up to worth in whole coins from box A to box B, largest first.
/proc/province_coin_move(obj/structure/closet/crate/faction_strongbox/A, obj/structure/closet/crate/faction_strongbox/B, worth)
	var/list/stacks = A.coin_stacks()
	var/list/sorted = list()
	while (stacks.len)
		var/obj/item/stack/money/best = stacks[1]
		for (var/obj/item/stack/money/M in stacks)
			if (M.value > best.value)
				best = M
		stacks -= best
		sorted += best
	var/atom/into = B.opened ? B.loc : B
	var/paid = 0
	for (var/obj/item/stack/money/M in sorted)
		var/count = min(M.amount, round((worth - paid + 0.001) / M.value))
		if (count <= 0)
			continue
		var/obj/item/stack/money/out = count < M.amount ? M.split(count) : M
		if (!out)
			continue
		out.forceMove(into)
		M.update_icon()
		out.update_icon()
		paid += count * out.value
	return round(paid, 0.1)

// Called with each nation refresh (nation.dm). Nothing sleeps.
/proc/province_vassal_tribute()
	if (!map || !shard_group || !shard_group.enabled)
		return
	var/list/state = map.recruitment_state()
	if (!islist(state["vassal_tribute"]))
		state["vassal_tribute"] = list()
	var/list/last = state["vassal_tribute"]
	var/prefix = "civ:[shard_group.region]:"
	var/now = world.realtime
	for (var/nid in nation_registry)
		var/lord = nation_overlord_of(nid)
		var/list/L = lord ? nation_registry[lord] : null
		if (!islist(L))
			continue
		var/obj/structure/closet/crate/faction_strongbox/to_box = null
		for (var/id in L["members"])
			if (istext(id) && findtext(id, prefix) == 1)
				to_box = map.faction_strongbox(copytext(id, length(prefix) + 1))
				if (to_box)
					break
		if (!to_box)
			continue
		var/list/N = nation_registry[nid]
		for (var/id in N["members"])
			if (!istext(id) || findtext(id, prefix) != 1)
				continue
			if (isnum(last[id]) && now - last[id] < VASSAL_TRIBUTE_DAYS * 864000)
				continue
			var/name = copytext(id, length(prefix) + 1)
			var/obj/structure/closet/crate/faction_strongbox/from_box = nation_home_faction(name) ? map.faction_strongbox(name) : null
			if (!from_box)
				continue
			last[id] = now
			var/due = min(VASSAL_TRIBUTE_CAP, round(from_box.coin_worth() * VASSAL_TRIBUTE_SHARE))
			var/paid = due > 0 ? province_coin_move(from_box, to_box, due) : 0
			if (paid > 0)
				province_tell_leaders(province_group_of(name), "[name] paid [paid] silver in tribute to [nation_name_of(lord)].")
				province_tell_leaders("nation:[lord]", "[name] of [nation_name_of(nid)] paid [paid] silver in tribute to [to_box.faction].")
				log_game("Nations: [name] paid [paid] tribute to [to_box.faction] ([lord]).")

#undef VASSAL_TRIBUTE_DAYS
#undef VASSAL_TRIBUTE_SHARE
#undef VASSAL_TRIBUTE_CAP
