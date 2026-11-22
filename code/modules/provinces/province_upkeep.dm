// Upkeep and ruins (docs/provinces.md, "Upkeep and ruins"). Reviewed by Fable.
//
// Upkeep: a ranked settlement (province_ranks.dm) costs its seat's faction a
// weekly charge in coin from the faction's strongbox: nothing for a Camp,
// 50 silver for a Village, 150 for a Town, 400 for a City. A side's second
// ranked province on a land costs 1.5 times, its third twice (highest rank
// first). The first week is free. Unpaid upkeep fails the settlement's
// checklist, so it is warned and drops a rank after 48 hours unless paid; the
// box is tried again at every check. The coin is spent, not paid to anyone.
//
// Ruins: once the station rules have started, a faction whose registered plots
// lie in a province where it has had fewer than RUIN_RESIDENTS residents for
// RUIN_DAYS days in a row loses those plots: the register drops them and their
// deeds go void. The buildings stay for others to take over. Lands without
// provinces (claimed islands) have no ruins.
//
// State: map.faction_recruitment["province_upkeep"]: char -> list(group, paid
// through, unpaid); ["province_ruins"]: "char|faction" -> short since.
// Nothing here sleeps.

#define UPKEEP_WEEK 6048000
#define RUIN_RESIDENTS 3
#define RUIN_DAYS 14

/proc/province_upkeep_base(rank)
	switch (rank)
		if (2) return 50
		if (3) return 150
		if (4) return 400
	return 0

/obj/map_metadata/proc/province_upkeep_state()
	var/list/S = recruitment_state()
	if (!islist(S["province_upkeep"]))
		S["province_upkeep"] = list()
	return S["province_upkeep"]

// What province c costs its holder this week, in silver.
/proc/province_upkeep_cost(c, group)
	var/rank = province_rank_of(c)
	var/base = province_upkeep_base(rank)
	if (!base)
		return 0
	// Rank this province among the side's ranked provinces here, highest first.
	var/before = 0
	for (var/other in map.province_holders())
		if (other == c || province_holder_of(other) != group)
			continue
		var/other_rank = province_rank_of(other)
		if (province_upkeep_base(other_rank) && (other_rank > rank || (other_rank == rank && "[other]" < "[c]")))
			before++
	if (before == 1)
		return round(base * 1.5)
	if (before >= 2)
		return base * 2
	return base

// Takes worth in coin from the box, largest coins first and one more small coin
// for any remainder; nothing when the box holds too little. TRUE when paid.
/proc/province_upkeep_take(obj/structure/closet/crate/faction_strongbox/B, worth)
	if (!B || worth <= 0)
		return worth <= 0
	if (B.coin_worth() < worth)
		return FALSE
	var/list/stacks = B.coin_stacks()
	var/list/sorted = list()
	while (stacks.len)
		var/obj/item/stack/money/best = stacks[1]
		for (var/obj/item/stack/money/M in stacks)
			if (M.value > best.value)
				best = M
		stacks -= best
		sorted += best
	var/paid = 0
	for (var/obj/item/stack/money/M in sorted)
		var/count = min(M.amount, round((worth - paid + 0.001) / M.value))
		if (count > 0 && M.use(count))
			paid += count * M.value
	if (paid + 0.05 < worth)
		for (var/i in sorted.len to 1 step -1)
			var/obj/item/stack/money/M = sorted[i]
			if (QDELETED(M) || M.amount < 1)
				continue
			while (paid + 0.05 < worth && !QDELETED(M) && M.amount >= 1 && M.use(1))
				paid += M.value
			if (paid + 0.05 >= worth)
				break
	return paid + 0.05 >= worth

// TRUE when province c's upkeep is paid up; charges it when due. Called by
// province_rank_check for the province's seat.
/proc/province_upkeep_paid(c, group, obj/structure/faction_hall/seat)
	var/list/U = map.province_upkeep_state()
	var/cost = province_upkeep_cost(c, group)
	var/list/row = U[c]
	if (!cost)
		if (islist(row))
			U -= c
		return TRUE
	var/now = world.realtime
	if (!islist(row) || row.len != 3 || row[1] != group || !isnum(row[2]))
		U[c] = list(group, now + UPKEEP_WEEK, FALSE) // the first week is free
		return TRUE
	if (now < row[2] && !row[3])
		return TRUE
	var/obj/structure/closet/crate/faction_strongbox/B = seat ? map.faction_strongbox(seat.faction) : null
	if (!province_upkeep_take(B, cost))
		if (!row[3])
			row[3] = TRUE
			province_tell_leaders(group, "The week's upkeep of [cost] silver for your settlement in the [map.province_map().names[c]] is unpaid: put coin in [seat ? seat.faction : "your faction"]'s strongbox, or the settlement drops a rank.")
		return FALSE
	map.treasury_log(seat.faction, "Upkeep of [cost] silver paid for the settlement in the [map.province_map().names[c]].")
	row[2] = (row[3] ? now : row[2]) + UPKEEP_WEEK
	row[3] = FALSE
	return TRUE

/proc/province_upkeep_text(c)
	var/list/U = map.province_upkeep_state()
	var/list/row = U[c]
	var/group = province_holder_of(c)
	var/cost = group ? province_upkeep_cost(c, group) : 0
	if (!cost)
		return "No upkeep is due at this rank."
	if (islist(row) && row.len == 3 && row[3])
		return "This week's upkeep of [cost] silver is unpaid."
	var/days = islist(row) && row.len == 3 && isnum(row[2]) ? max(0, round((row[2] - world.realtime) / 864000, 0.1)) : 7
	return "Upkeep: [cost] silver a week from the strongbox, next due in [days] days."

// --- Ruins ------------------------------------------------------------------------

// Drops plots of factions that have left a province. Called after each stake count.
/proc/province_ruins_update(list/stakes)
	if (!province_rules_active())
		return
	var/datum/province_map/P = map.province_map()
	var/list/S = map.recruitment_state()
	if (!islist(S["province_ruins"]))
		S["province_ruins"] = list()
	var/list/R = S["province_ruins"]
	var/list/plots_in = list() // "char|faction" -> list(plot ids)
	var/list/LS = map.land_state()
	for (var/faction in LS)
		for (var/id in map.land_plots(faction))
			var/list/row = map.land_plot(faction, id)
			if (!row)
				continue
			var/c = P.char_at(round((row[2] + row[4]) / 2), round((row[3] + row[5]) / 2))
			if (!c)
				continue
			var/key = "[c]|[faction]"
			if (!plots_in[key])
				plots_in[key] = list()
			var/list/ids = plots_in[key]
			ids += id
	var/now = world.realtime
	for (var/key in R.Copy())
		if (!plots_in[key])
			R -= key
	for (var/key in plots_in)
		var/list/parts = splittext(key, "|")
		var/c = parts[1]
		var/faction = copytext(key, length(c) + 2)
		var/list/stake = stakes[c]
		var/list/groups = islist(stake) ? stake["groups"] : null
		var/list/G = islist(groups) ? groups[province_group_of(faction)] : null
		var/list/members = islist(G) ? G[3] : null
		var/residents = islist(members) && isnum(members[faction]) ? members[faction] : 0
		if (residents >= RUIN_RESIDENTS)
			R -= key
			continue
		if (!isnum(R[key]))
			R[key] = now
			continue
		if (now - R[key] < RUIN_DAYS * 864000)
			continue
		var/list/rows = map.land_plots(faction)
		var/list/ids = plots_in[key]
		for (var/id in ids)
			rows -= id
		R -= key
		map.recruitment_audit(faction, "[ids.len] plots in the [P.names[c]] fell to ruin: fewer than [RUIN_RESIDENTS] members lived there for [RUIN_DAYS] days.", "")
		province_tell_leaders(province_group_of(faction), "[faction]'s plots in the [P.names[c]] have fallen to ruin: too few members lived there. Their deeds are void; the buildings stand for anyone.")
		log_game("Provinces: [faction]'s [ids.len] plots in province [c] lapsed as ruins.")

// Shown in Province Holdings for a faction with plots short of residents.
/proc/province_ruin_text(faction)
	if (!map || !faction || !province_rules_active())
		return null
	var/list/S = map.recruitment_state()
	var/list/R = S["province_ruins"]
	if (!islist(R))
		return null
	var/datum/province_map/P = map.province_map()
	var/list/parts = list()
	for (var/key in R)
		var/list/split = splittext(key, "|")
		if (copytext(key, length(split[1]) + 2) != faction || !isnum(R[key]))
			continue
		var/days = max(0, round((RUIN_DAYS * 864000 - (world.realtime - R[key])) / 864000, 0.1))
		parts += "the [P.names[split[1]]] in [days] days"
	if (!parts.len)
		return null
	return "Your plots fall to ruin unless [RUIN_RESIDENTS] members live there: [jointext(parts, "; ")]."

#undef UPKEEP_WEEK
#undef RUIN_RESIDENTS
#undef RUIN_DAYS
