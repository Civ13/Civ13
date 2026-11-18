// Province stake (docs/provinces.md, "Stake"). A faction's stake in a
// province comes from members who really live and play there, and from its
// hall. This is the reckoning only: Faction > Province Holdings and Admin >
// Land Status show it. Holding a province (timers, caps, stations) builds on
// it later.
//
// Resident, 1 point: an account on the faction's roster for 72 hours whose
// bed has been theirs for 72 hours, within 40 tiles of one of the faction's
// fastened halls or on a plot the faction registered, and which has played
// 10 hours in all and 4 active hours over at least 3 different days of the
// last 7 here. A resident counts in the one province their bed stands in.
// Hall: 2 points per tier for the faction's best standing hall in the
// province, never more than the faction's resident points there.
// Nations pool their members' stake; residents count less past 10 and 30 in
// one province, so the biggest bloc cannot simply swamp it.
// Leading: the largest stake with at least 6 points from at least 4 accounts,
// 35% of all the stake there and 1.25 times the runner-up.
//
// Activity is counted here, per account, in map.faction_recruitment
// ["province_activity"] (durable): account -> list(total minutes,
// list(day number text -> minutes)). Nothing here sleeps.

#define STAKE_TICK 6000 // 10 minutes between activity counts
#define STAKE_TICK_MINUTES 10
#define STAKE_AFK 6000 // a client idle this long is not active
#define STAKE_DAYS 7
#define STAKE_BED_HOURS 72
#define STAKE_ROSTER_HOURS 72
#define STAKE_TOTAL_MINUTES 600
#define STAKE_ACTIVE_MINUTES 240
#define STAKE_ACTIVE_DAYS 3
#define STAKE_HALL_RANGE 40
#define STAKE_HALL_PER_TIER 2
#define STAKE_LEAD_POINTS 6
#define STAKE_LEAD_ACCOUNTS 4
#define STAKE_LEAD_SHARE 0.35
#define STAKE_LEAD_MARGIN 1.25
#define STAKE_CACHE 6000

var/global/province_activity_timer = null
var/global/list/all_beds = list() // every bed; bed.dm New and Destroy keep it
var/global/list/province_stake_cache = null
var/global/province_stake_cached_at = 0

/proc/province_day()
	return round(world.realtime / 864000)

/obj/map_metadata/proc/province_activity()
	var/list/S = recruitment_state()
	if (!islist(S["province_activity"]))
		S["province_activity"] = list()
	return S["province_activity"]

/proc/province_activity_start()
	if (province_activity_timer || !map || !map.province_map())
		return
	province_activity_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(province_activity_tick)), STAKE_TICK, TIMER_LOOP | TIMER_STOPPABLE)

// Adds STAKE_TICK_MINUTES for every active player with a living character.
/proc/province_activity_tick()
	if (!map || !map.province_map())
		return
	var/list/A = map.province_activity()
	var/today = province_day()
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (!istype(H) || H.stat == DEAD || C.inactivity >= STAKE_AFK || IsGuestKey(C.key))
			continue
		var/account = faction_roster_account(H)
		if (!account)
			continue
		var/list/row = A[account]
		if (!islist(row) || row.len != 2 || !isnum(row[1]) || !islist(row[2]))
			row = list(0, list())
			A[account] = row
		row[1] = min(row[1] + STAKE_TICK_MINUTES, 1000000)
		var/list/days = row[2]
		var/key = "[today]"
		days[key] = (isnum(days[key]) ? days[key] : 0) + STAKE_TICK_MINUTES
		for (var/d in days.Copy())
			if (!isnum(text2num(d)) || text2num(d) <= today - STAKE_DAYS)
				days -= d
	province_holding_update() // province_holding.dm

// list(total minutes, minutes in the last 7 days, days played of the last 7).
/proc/province_activity_of(account)
	var/list/row = map ? map.province_activity()[account] : null
	if (!islist(row) || row.len != 2 || !isnum(row[1]) || !islist(row[2]))
		return list(0, 0, 0)
	var/today = province_day()
	var/recent = 0
	var/days = 0
	var/list/D = row[2]
	for (var/d in D)
		var/n = text2num(d)
		if (isnum(n) && n > today - STAKE_DAYS && isnum(D[d]) && D[d] > 0)
			recent += D[d]
			days++
	return list(row[1], recent, days)

// --- Residents ----------------------------------------------------------------

// The faction whose roster holds the account here, or null.
/proc/province_faction_of(account)
	if (!map || !account)
		return null
	for (var/faction in map.faction_rosters())
		if (map.faction_on_roster(faction, account))
			return faction
	return null

// TRUE when the turf is within reach of one of the faction's fastened halls,
// or on a plot it registered.
/proc/province_near_faction_seat(faction, turf/T)
	for (var/obj/structure/faction_hall/H in faction_halls)
		if (QDELETED(H) || H.faction != faction || !H.anchored || !isturf(H.loc))
			continue
		if (max(abs(H.x - T.x), abs(H.y - T.y)) <= STAKE_HALL_RANGE)
			return TRUE
	var/list/plot = map.land_plot_at(T)
	return islist(plot) && plot[1] == faction

// Why an account's bed does not count here, or null when it does. B may be null.
/proc/province_resident_problem(account, faction, obj/structure/bed/B)
	if (!faction)
		return "you are on no faction's roster here"
	var/list/roster = map.faction_roster(faction)
	var/list/row = roster[account]
	if (!islist(row) || !isnum(row[1]) || row[1] > world.realtime - STAKE_ROSTER_HOURS * 36000)
		return "you joined [faction] less than [STAKE_ROSTER_HOURS] hours ago"
	if (!B || QDELETED(B) || !B.anchored || !isturf(B.loc))
		return "you have no bed here"
	if (isnum(B.persistence_bed_assigned_at) && B.persistence_bed_assigned_at > death_legacy_now() - STAKE_BED_HOURS)
		return "your bed has been yours for less than [STAKE_BED_HOURS] hours"
	var/turf/T = get_turf(B)
	if (!province_name_at(T))
		return "your bed is in no province"
	if (!province_near_faction_seat(faction, T))
		return "your bed is not within [STAKE_HALL_RANGE] tiles of a hall of [faction] or on its land"
	var/list/act = province_activity_of(account)
	if (act[1] < STAKE_TOTAL_MINUTES)
		return "you have played [round(act[1] / 60)] of [STAKE_TOTAL_MINUTES / 60] hours here"
	if (act[2] < STAKE_ACTIVE_MINUTES || act[3] < STAKE_ACTIVE_DAYS)
		return "you played [round(act[2] / 60, 0.1)] active hours on [act[3]] days of the last [STAKE_DAYS]; it takes [STAKE_ACTIVE_MINUTES / 60] hours over [STAKE_ACTIVE_DAYS] days"
	return null

// account -> claimed bed, for every fastened claimed bed in the world.
/proc/province_claimed_beds()
	var/list/beds = list()
	for (var/obj/structure/bed/B in all_beds)
		if (B.persistence_bed_owner_ckey && !QDELETED(B) && B.anchored && isturf(B.loc) && !beds[B.persistence_bed_owner_ckey])
			beds[B.persistence_bed_owner_ckey] = B
	return beds

// --- Stake ----------------------------------------------------------------------

// Pooled residents count in full up to 10, half up to 30, a quarter past it.
/proc/province_resident_points(count)
	return min(count, 10) + 0.5 * Clamp(count - 10, 0, 20) + 0.25 * max(count - 30, 0)

// The group a faction's stake pools into: its nation, or the faction itself.
/proc/province_group_of(faction)
	var/nid = nation_of_id(nation_faction_id(faction))
	return nid ? "nation:[nid]" : "faction:[faction]"

/proc/province_group_name(group)
	if (findtext(group, "nation:") == 1)
		var/list/N = nation_registry[copytext(group, 8)]
		return islist(N) && istext(N["name"]) ? N["name"] : "a nation"
	return copytext(group, 9)

// province char -> list("groups" = group -> list(stake, accounts, list(faction -> residents)),
// "lead" = group or null, "total" = all stake). Cached for STAKE_CACHE.
/proc/province_stakes(force = FALSE)
	if (!map)
		return list()
	var/datum/province_map/P = map.province_map()
	if (!P)
		return list()
	if (!force && islist(province_stake_cache) && world.time - province_stake_cached_at < STAKE_CACHE)
		return province_stake_cache
	// Residents per province, per faction.
	var/list/residents = list() // char -> faction -> count
	var/list/beds = province_claimed_beds()
	for (var/account in beds)
		var/faction = province_faction_of(account)
		var/obj/structure/bed/B = beds[account]
		if (province_resident_problem(account, faction, B))
			continue
		var/c = P.char_at(B.x, B.y)
		if (!residents[c])
			residents[c] = list()
		var/list/R = residents[c]
		R[faction] = (isnum(R[faction]) ? R[faction] : 0) + 1
	// Halls: best tier per faction per province.
	var/list/halls = list() // char -> faction -> tier
	for (var/obj/structure/faction_hall/H in faction_halls)
		if (QDELETED(H) || !H.faction || !H.anchored || !isturf(H.loc) || !H.tier || !H.tier_stands(H.tier))
			continue
		var/c = P.char_at(H.x, H.y)
		if (!c)
			continue
		if (!halls[c])
			halls[c] = list()
		var/list/L = halls[c]
		L[H.faction] = max(isnum(L[H.faction]) ? L[H.faction] : 0, H.tier)
	var/list/out = list()
	for (var/c in P.names)
		var/list/R = residents[c] || list()
		var/list/L = halls[c] || list()
		var/list/groups = list()
		var/list/pooled = list() // group -> residents
		for (var/faction in R)
			var/group = province_group_of(faction)
			pooled[group] = (isnum(pooled[group]) ? pooled[group] : 0) + R[faction]
			if (!groups[group])
				groups[group] = list(0, 0, list())
			var/list/G = groups[group]
			G[2] += R[faction]
			var/list/members = G[3]
			members[faction] = R[faction]
			if (isnum(L[faction]))
				G[1] += min(L[faction] * STAKE_HALL_PER_TIER, R[faction])
		var/total = 0
		for (var/group in groups)
			var/list/G = groups[group]
			G[1] += province_resident_points(pooled[group])
			total += G[1]
		var/lead = null
		var/best = 0
		var/second = 0
		for (var/group in groups)
			var/list/G = groups[group]
			if (G[1] > best)
				second = best
				best = G[1]
				lead = group
			else if (G[1] > second)
				second = G[1]
		if (lead)
			var/list/G = groups[lead]
			if (best < STAKE_LEAD_POINTS || G[2] < STAKE_LEAD_ACCOUNTS || best < STAKE_LEAD_SHARE * total || (second && best < STAKE_LEAD_MARGIN * second))
				lead = null
		out[c] = list("groups" = groups, "lead" = lead, "total" = total)
	province_stake_cache = out
	province_stake_cached_at = world.time
	return out

/proc/province_stake_text(n)
	return "[round(n, 0.5)]"

// --- Views ------------------------------------------------------------------------

/proc/province_standings_html(viewer_faction = null)
	var/datum/province_map/P = map ? map.province_map() : null
	if (!P)
		return "<p>This land has no provinces.</p>"
	var/list/stakes = province_stakes()
	var/viewer_group = viewer_faction ? province_group_of(viewer_faction) : null
	var/list/lines = list("<table class='regions'><tr><th>Province</th><th>Held</th><th>Leading</th><th>Stake there</th>[viewer_group ? "<th>Yours</th>" : ""]</tr>")
	for (var/c in P.names)
		var/list/S = stakes[c]
		var/list/groups = S["groups"]
		var/list/parts = list()
		for (var/group in groups)
			var/list/G = groups[group]
			parts += "[html_encode(province_group_name(group))] [province_stake_text(G[1])] ([G[2]] residents)"
		var/lead = S["lead"] ? html_encode(province_group_name(S["lead"])) : (groups.len ? "nobody yet" : "nobody")
		var/mine = ""
		if (viewer_group)
			var/list/G = groups[viewer_group]
			mine = "<td>[G ? "[province_stake_text(G[1])] ([G[2]] residents)" : "none"]</td>"
		lines += "<tr><td>[html_encode(P.names[c])]</td><td>[province_holding_text(c)]</td><td>[lead]</td><td>[parts.len ? jointext(parts, "; ") : "none"]</td>[mine]</tr>"
	lines += "</table>"
	return jointext(lines, "")

/mob/living/human/proc/province_holdings()
	set name = "Province Holdings"
	set category = "Faction"
	set desc = "See who has a stake in this land's provinces, and whether you count as a resident."
	if (!map || !map.province_map())
		to_chat(src, SPAN_WARNING("This land has no provinces."))
		return
	var/account = faction_roster_account(src)
	var/faction = account ? province_faction_of(account) : null
	var/list/beds = account ? province_claimed_beds() : list()
	var/obj/structure/bed/B = account ? beds[account] : null
	var/problem = account ? province_resident_problem(account, faction, B) : "guests do not count"
	var/here = province_name_at(get_turf(src))
	var/list/lines = list("<p>[here ? "You are in the <b>[html_encode(here)]</b>." : "You are in no province."]</p>")
	if (problem)
		lines += "<p>You do not count as a resident: [html_encode(problem)].</p>"
	else
		lines += "<p>You count as a resident of the [html_encode(province_name_at(get_turf(B)))] for [html_encode(faction)].</p>"
	lines += "<p>Stake: each resident member is 1 point, and a hall adds 2 points a tier, never more than the faction's residents there. Nations pool their members' stake. A side leads a province with at least [STAKE_LEAD_POINTS] points from [STAKE_LEAD_ACCOUNTS] people, [STAKE_LEAD_SHARE * 100]% of the stake there and [STAKE_LEAD_MARGIN] times the next side. Updated every 10 minutes.</p>"
	lines += "<p>[province_rules_text()]</p>"
	var/resources = continent_resources_text() // continent_resources.dm
	if (resources)
		lines += "<p>[resources]</p>"
	lines += province_standings_html(faction)
	var/datum/browser/popup = new(src, "province_holdings", "Province Holdings", 760, 520)
	popup.add_head_content("<style>table.regions{border-collapse:collapse;width:100%}table.regions th,table.regions td{padding:3px 6px;text-align:left;border-bottom:1px solid #444}</style>")
	popup.set_content(jointext(lines, ""))
	popup.open(FALSE)

#undef STAKE_TICK
#undef STAKE_TICK_MINUTES
#undef STAKE_AFK
#undef STAKE_DAYS
#undef STAKE_BED_HOURS
#undef STAKE_ROSTER_HOURS
#undef STAKE_TOTAL_MINUTES
#undef STAKE_ACTIVE_MINUTES
#undef STAKE_ACTIVE_DAYS
#undef STAKE_HALL_RANGE
#undef STAKE_HALL_PER_TIER
#undef STAKE_LEAD_POINTS
#undef STAKE_LEAD_ACCOUNTS
#undef STAKE_LEAD_SHARE
#undef STAKE_LEAD_MARGIN
#undef STAKE_CACHE
