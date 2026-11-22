// Holding provinces (docs/provinces.md, "Holding"). Stake (province_stake.dm)
// says who leads a province now; holding adds time, so a raid or a quiet
// week does not flip a province at once:
// - A side that leads an unheld province for 72 hours in a row takes it.
// - A holder keeps it until a rival out-stakes it (6+ points from 4+ people,
//   35% of the stake and 1.25 times the holder, more for a ranked settlement,
//   province_ranks.dm) for 72 hours in a row. A nation allied to the holder
//   or bound to it by a pact is never a rival (province_treaties.dm).
// - A holder that falls below 6 points from 4 people is warned and loses the
//   province after 48 hours (up to 72 for a ranked settlement) unless it recovers. A destroyed bed or hall is a
//   fall like any other, so it has the same 48 hours to be rebuilt.
// - A nation, or a faction outside one, holds at most 3 provinces of a land.
// - A take or a loss that falls due waits for the province's daily defence
//   window (province_siege.dm), so a side asleep in another time zone is safe.
// A recruitment station works on a continent only in a province its side
// holds, and only for a faction with 3 residents of its own there. Lands
// without provinces (islands, expedition lands, older maps) keep every
// station working. Station rules start PROVINCE_PREVIEW_DAYS after this
// world first counted stake, so factions can see where they stand first.
//
// State: map.faction_recruitment["province_holders"] (durable):
//   province char -> list(holder group, held since, short since,
//                         challenger group, challenging since)
// Times are world.realtime; 0 means none. "province_rules_from" is the
// realtime the station rules start. Nothing here sleeps.

#define PROVINCE_GAIN_HOURS 72
#define PROVINCE_CAP_PER_LAND 3
#define PROVINCE_STATION_RESIDENTS 3
#define PROVINCE_PREVIEW_DAYS 21

/obj/map_metadata/proc/province_holders()
	var/list/S = recruitment_state()
	if (!islist(S["province_holders"]))
		S["province_holders"] = list()
	return S["province_holders"]

// The realtime station rules start here; set the first time stake is counted.
/obj/map_metadata/proc/province_rules_from()
	var/list/S = recruitment_state()
	if (!isnum(S["province_rules_from"]))
		S["province_rules_from"] = world.realtime + PROVINCE_PREVIEW_DAYS * 864000
	return S["province_rules_from"]

/proc/province_rules_active()
	return map && map.province_map() && world.realtime >= map.province_rules_from()

/proc/province_holder_row(c)
	var/list/H = map.province_holders()
	var/list/row = H[c]
	if (!islist(row) || row.len != 5)
		row = list(null, 0, 0, null, 0)
		H[c] = row
	return row

/proc/province_holder_of(c)
	if (!map || !c)
		return null
	var/list/H = map.province_holders()
	var/list/row = H[c]
	return islist(row) && row.len == 5 ? row[1] : null

/proc/province_holdings_count(group)
	var/count = 0
	for (var/c in map.province_holders())
		if (province_holder_of(c) == group)
			count++
	return count

// Why a group cannot take another province of this land, or null. The cap
// counts the group's whole bloc (province_blocs.dm): factions staff marked as
// one bloc and factions led by the same player share it, and a bloc never
// holds more than half of a land's provinces.
/proc/province_cap_refusal(group)
	if (province_claims_frozen(group))
		return "staff froze its claims"
	var/held = province_bloc_holdings(group)
	if (held >= PROVINCE_CAP_PER_LAND)
		return "its bloc already holds [held] provinces of this land"
	var/datum/province_map/P = map.province_map()
	if (P && (held + 1) * 2 > length(P.names))
		return "its bloc would hold more than half of this land"
	return null

// TRUE when the group's stake meets the minimum to lead or keep a province.
/proc/province_stake_enough(list/G)
	return islist(G) && G[1] >= 6 && G[2] >= 4

// The strongest rival able to take a held province from its holder, or null.
/proc/province_rival(list/S, holder, margin = 1.25)
	var/list/groups = S["groups"]
	var/list/HG = groups[holder]
	var/holder_stake = islist(HG) ? HG[1] : 0
	var/best = null
	var/best_stake = 0
	for (var/group in groups)
		if (group == holder || province_groups_friendly(group, holder)) // allies and pact partners never contest (province_treaties.dm)
			continue
		var/list/G = groups[group]
		if (!province_stake_enough(G) || G[1] < 0.35 * S["total"] || G[1] < margin * holder_stake)
			continue
		if (G[1] > best_stake)
			best = group
			best_stake = G[1]
	return best

/proc/province_tell_leaders(group, message)
	for (var/mob/living/human/H in human_mob_list)
		if (!H.client || H.stat == DEAD || !H.civilization || H.civilization == "none")
			continue
		if (province_group_of(H.civilization) == group && map.is_faction_leader(H, H.civilization))
			to_chat(H, SPAN_WARNING(message))

// Moves holdings on by the current stake. Called after each activity count.
/proc/province_holding_update()
	var/datum/province_map/P = map ? map.province_map() : null
	if (!P)
		return
	map.province_rules_from()
	var/list/stakes = province_stakes(TRUE)
	var/now = world.realtime
	for (var/c in P.names)
		var/list/S = stakes[c]
		if (!islist(S))
			continue
		var/list/row = province_holder_row(c)
		var/holder = row[1]
		var/name = P.names[c]
		// A ranked settlement is harder to take and slower to lose (province_ranks.dm).
		var/rank = holder ? province_rank_effective(c) : 0 // province_siege.dm
		// Who holds it changes only in its defence window (province_siege.dm).
		var/window = province_in_window(c)
		var/contender = holder ? province_rival(S, holder, province_rank_margin(rank)) : S["lead"]
		if (holder)
			var/list/groups = S["groups"]
			if (province_stake_enough(groups[holder]))
				if (row[3])
					province_tell_leaders(holder, "Your hold on the [name] is secure again.")
				row[3] = 0
			else if (!row[3])
				row[3] = now
				province_tell_leaders(holder, "Your hold on the [name] is slipping: you need at least 6 stake from 4 residents there. You lose it in [province_rank_lose_hours(rank)] hours unless you recover.")
			else if (now - row[3] >= province_rank_lose_hours(rank) * 36000 && window)
				province_tell_leaders(holder, "You have lost the [name].")
				row[1] = null
				row[2] = 0
				row[3] = 0
				holder = null
		province_rank_update(c, holder, S, name)
		if (!contender)
			row[4] = null
			row[5] = 0
			continue
		if (row[4] != contender)
			row[4] = contender
			row[5] = now
			if (holder)
				province_tell_leaders(holder, "[province_group_name(contender)] now has more stake than you in the [name]. Hold it for [PROVINCE_GAIN_HOURS] hours or lose it.")
			continue
		if (now - row[5] < PROVINCE_GAIN_HOURS * 36000 || !window)
			continue
		if (province_cap_refusal(contender))
			continue
		if (holder)
			province_tell_leaders(holder, "[province_group_name(contender)] has taken the [name] from you.")
		row[1] = contender
		row[2] = now
		row[3] = 0
		row[4] = null
		row[5] = 0
		province_tell_leaders(contender, "You now hold the [name]. Your recruitment stations there work.")
	province_ruins_update(stakes) // province_upkeep.dm

// Why a station here cannot recruit under the province rules, or null.
/proc/province_station_problem(obj/structure/recruitment_station/S, faction = null)
	faction = faction || S.faction
	if (!faction || !province_rules_active())
		return null
	var/datum/province_map/P = map.province_map()
	var/c = P.char_at(S.x, S.y)
	if (!c)
		return "it stands in no province"
	var/group = province_group_of(faction)
	if (province_holder_of(c) != group)
		return "[faction] does not hold the [P.names[c]]"
	var/list/stakes = province_stakes()
	var/list/G = stakes[c] ? stakes[c]["groups"][group] : null
	var/list/members = islist(G) ? G[3] : null
	var/own = islist(members) && isnum(members[faction]) ? members[faction] : 0
	if (own < PROVINCE_STATION_RESIDENTS)
		return "[faction] has [own] of the [PROVINCE_STATION_RESIDENTS] residents it needs in the [P.names[c]]"
	return null

/proc/province_holding_text(c)
	var/holder = province_holder_of(c)
	var/list/H = map.province_holders()
	var/list/row = H[c]
	var/list/parts = list(holder ? "held by [html_encode(province_group_name(holder))]" : "unheld")
	var/rank = holder ? province_rank_text(c) : null
	if (rank)
		parts += html_encode(rank)
	if (islist(row) && row.len == 5)
		if (holder && row[3])
			parts += "slipping, [round(max(0, province_rank_lose_hours(province_rank_effective(c)) * 36000 - (world.realtime - row[3])) / 36000)] h left"
		if (row[4])
			parts += "[html_encode(province_group_name(row[4]))] taking it in [round(max(0, PROVINCE_GAIN_HOURS * 36000 - (world.realtime - row[5])) / 36000)] h"
	return jointext(parts, ", ")

/proc/province_rules_text()
	if (!map || !map.province_map())
		return ""
	if (province_rules_active())
		return "Recruitment stations here work only in a province your side holds, for a faction with [PROVINCE_STATION_RESIDENTS] residents of its own there."
	var/days = round((map.province_rules_from() - world.realtime) / 864000, 0.1)
	return "In [days] days, recruitment stations here will work only in a province your side holds. Taking a province takes [PROVINCE_GAIN_HOURS] hours of leading it; a side holds at most [PROVINCE_CAP_PER_LAND] provinces of a land."

#undef PROVINCE_GAIN_HOURS
#undef PROVINCE_CAP_PER_LAND
#undef PROVINCE_STATION_RESIDENTS
#undef PROVINCE_PREVIEW_DAYS
