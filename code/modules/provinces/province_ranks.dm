// Settlement ranks (docs/provinces.md, "Ranks"). Val (2026-11-18): a faction
// that holds an area must get a clear objective for city building and defence,
// and a reason to spend time building up. Reviewed by Fable.
//
// A held province's seat is the holder's best standing hall there (not a nation
// assembly). The settlement is everything within RANK_SETTLEMENT tiles of it.
// It ranks Camp, Village, Town or City by a checklist the game can count, and
// no higher than the seat's hall tier allows (council fire, longhouse, town
// hall, capitol). Each rank needs its own list and every lower one.
// - A rank rises as soon as its list is met. A settlement that falls short is
//   told what to repair and drops one rank after RANK_DROP_HOURS hours, then
//   another 48 hours later, and so on.
// - What ranks give: a rival needs 1.25 / 1.35 / 1.5 / 1.6 times the holder's
//   stake (Camp to City), the loss warning lasts 48 / 48 / 60 / 72 hours, the
//   side's best province adds 3 members a rank to each of its factions' limits,
//   and a bed start inside a Town costs 1.5 times instead of double, inside a
//   City 1.25 times.
// - The wall ring is one flood fill from the seat inside the settlement box.
//   Walls, palisades, parapets, barricades and natural rock close it; a door or
//   castle gate with open sky on both sides is a gate in it, and a door with a
//   roof on either side is an inner door that the fill passes through.
//
// State: map.faction_recruitment["province_ranks"] (durable):
//   province char -> list(rank, short since)
// Checks are run at most every RANK_CHECK_INTERVAL and kept in
// province_rank_checks (runtime). Nothing here sleeps.

#define RANK_SETTLEMENT 40
#define RANK_DROP_HOURS 48
#define RANK_CHECK_INTERVAL 36000 // an hour
#define RANK_MEMBERS_PER_RANK 3
#define RANK_WATCHTOWER_RANGE 10

// char -> list(checked at, seat, rank met, rows); rows: list(rank, label, met)
var/global/list/province_rank_checks = list()

/proc/province_rank_names()
	var/static/list/names = list("Camp", "Village", "Town", "City")
	return names

/proc/province_rank_name(rank)
	return rank >= 1 && rank <= 4 ? province_rank_names()[rank] : "no rank"

/obj/map_metadata/proc/province_ranks()
	var/list/S = recruitment_state()
	if (!islist(S["province_ranks"]))
		S["province_ranks"] = list()
	return S["province_ranks"]

/proc/province_rank_row(c)
	var/list/R = map.province_ranks()
	var/list/row = R[c]
	if (!islist(row) || row.len != 2 || !isnum(row[1]) || !isnum(row[2]))
		row = list(0, 0)
		R[c] = row
	return row

/proc/province_rank_of(c)
	if (!map || !c)
		return 0
	var/list/R = map.province_ranks()
	var/list/row = R[c]
	return islist(row) && row.len == 2 && isnum(row[1]) ? clamp(row[1], 0, 4) : 0

// --- What ranks give ------------------------------------------------------------

// How many times the holder's stake a rival needs to take the province.
/proc/province_rank_margin(rank)
	switch (rank)
		if (2) return 1.35
		if (3) return 1.5
		if (4) return 1.6
	return 1.25

// How long a holder that falls short keeps the province.
/proc/province_rank_lose_hours(rank)
	switch (rank)
		if (3) return 60
		if (4) return 72
	return 48

// Extra members a faction may take in, from its side's best ranked province.
/proc/province_rank_member_bonus(faction)
	if (!map || !faction || !map.province_map())
		return 0
	var/group = province_group_of(faction)
	var/best = 0
	for (var/c in map.province_holders())
		if (province_holder_of(c) == group)
			best = max(best, province_rank_effective(c)) // province_siege.dm
	return best * RANK_MEMBERS_PER_RANK

// The extra a bed start costs in death knowledge, as returns (2 ** extra times
// the loss): double outside a Town or City of the account's own side, 1.5 times
// inside a Town, 1.25 times inside a City.
/proc/province_rank_bed_extra(account, turf/T)
	if (!map || !account || !T || !map.province_map())
		return 1
	var/faction = province_faction_of(account)
	if (!faction)
		return 1
	var/group = province_group_of(faction)
	var/datum/province_map/P = map.province_map()
	var/c = P.char_at(T.x, T.y)
	if (!c || province_holder_of(c) != group)
		return 1
	var/rank = province_rank_effective(c)
	if (rank < 3)
		return 1
	var/obj/structure/faction_hall/seat = province_seat(c, group)
	if (!seat || seat.z != T.z || max(abs(seat.x - T.x), abs(seat.y - T.y)) > RANK_SETTLEMENT)
		return 1
	return rank >= 4 ? 0.3219 : 0.585 // log2(1.25), log2(1.5)

/proc/province_rank_bed_text(rank)
	return rank >= 4 ? "1.25 times" : (rank == 3 ? "1.5 times" : "double")

// --- The seat ---------------------------------------------------------------------

// The holder's best standing hall in province c, or null.
/proc/province_seat(c, group)
	var/datum/province_map/P = map ? map.province_map() : null
	if (!P || !c || !group)
		return null
	var/obj/structure/faction_hall/best = null
	for (var/obj/structure/faction_hall/H in faction_halls)
		if (QDELETED(H) || !H.faction || !H.anchored || !isturf(H.loc) || !H.tier || !H.tier_stands(H.tier))
			continue
		if (istype(H, /obj/structure/faction_hall/nation_assembly))
			continue
		if (province_group_of(H.faction) != group || P.char_at(H.x, H.y) != c)
			continue
		if (!best || H.tier > best.tier)
			best = H
	return best

// The factions of a side (a nation's members, or the faction itself).
/proc/province_group_factions(group)
	var/list/out = list()
	for (var/faction in map.custom_civs)
		if (province_group_of(faction) == group)
			out += faction
	return out

// --- The wall ring -----------------------------------------------------------------

/proc/province_ring_door(turf/N)
	for (var/obj/O in N)
		if (istype(O, /obj/structure/simple_door) || istype(O, /obj/structure/castle_gate))
			return O
	return null

/proc/province_ring_wall(turf/N)
	if (N.density)
		return N
	for (var/obj/O in N)
		if (!O.density)
			continue
		if (istype(O, /obj/structure/window/barrier/railing) || istype(O, /obj/structure/barricade/velvet_rope))
			continue
		if (istype(O, /obj/covers) || istype(O, /obj/structure/window) || istype(O, /obj/structure/barricade))
			return O
	return null

/proc/province_ring_stone(atom/A)
	if (isturf(A))
		return TRUE
	return istype(A, /obj/covers/stone_wall) || istype(A, /obj/covers/brick_wall) || istype(A, /obj/covers/marble_wall) || istype(A, /obj/covers/cement_wall) || istype(A, /obj/covers/tiled_wall) || istype(A, /obj/covers/sandstone_wall) || istype(A, /obj/structure/barricade/stone_h) || istype(A, /obj/structure/barricade/stone_v) || istype(A, /obj/structure/barricade/sandstone_h) || istype(A, /obj/structure/barricade/sandstone_v) || istype(A, /obj/structure/window/barrier/rock) || istype(A, /obj/structure/window/barrier/sandstone) || istype(A, /obj/structure/window/barrier/concrete)

/proc/province_ring_slit(atom/A)
	if (istype(A, /obj/covers))
		var/obj/covers/C = A
		return C.slit != SLIT_NONE
	if (istype(A, /obj/structure/barricade))
		return is_battlement_type(A)
	return istype(A, /obj/structure/window/barrier/rock/parapet) || istype(A, /obj/structure/window/barrier/sandstone/parapet)

/proc/province_indoors(turf/T)
	var/area/A = T ? get_area(T) : null
	return A && A.location != AREA_OUTSIDE

// One flood fill from the seat: list("closed", "gates", "stone", "slits", "paved").
/proc/province_ring(obj/structure/faction_hall/seat)
	var/turf/start = get_turf(seat)
	var/list/result = list("closed" = FALSE, "gates" = list(), "stone" = FALSE, "slits" = 0, "paved" = 0)
	if (!start)
		return result
	var/list/seen = list()
	seen[start] = TRUE
	var/list/queue = list(start)
	var/list/gates = list()
	var/walls = 0
	var/stone = 0
	var/slits = 0
	var/paved = 0
	var/i = 1
	while (i <= queue.len)
		var/turf/T = queue[i]
		i++
		if (istype(T, /turf/floor/plating))
			paved++
		for (var/d in cardinal)
			var/turf/N = get_step(T, d)
			if (!N || max(abs(N.x - start.x), abs(N.y - start.y)) > RANK_SETTLEMENT)
				return result
			if (seen[N])
				continue
			seen[N] = TRUE
			if (province_ring_door(N))
				if (province_indoors(N) || province_indoors(T))
					queue += N
				else
					gates += N
				continue
			var/atom/W = province_ring_wall(N)
			if (!W)
				queue += N
				continue
			walls++
			if (province_ring_stone(W))
				stone++
			if (province_ring_slit(W))
				slits++
	result["closed"] = TRUE
	result["gates"] = gates
	result["stone"] = walls > 0 && stone == walls
	result["slits"] = slits
	result["paved"] = paved
	return result

// A roofed upper floor within RANK_WATCHTOWER_RANGE of one of the gates.
/proc/province_watchtower(list/gates)
	for (var/turf/G in gates)
		var/up = multiz_level_above(G.z)
		if (!up)
			continue
		for (var/turf/T in block(locate(max(1, G.x - RANK_WATCHTOWER_RANGE), max(1, G.y - RANK_WATCHTOWER_RANGE), up), locate(min(world.maxx, G.x + RANK_WATCHTOWER_RANGE), min(world.maxy, G.y + RANK_WATCHTOWER_RANGE), up)))
			if (istype(T, /turf/floor) && !building_open_turf(T) && province_indoors(T))
				return TRUE
	return FALSE

// Gates with a portcullis on or beside them, or a murder hole above.
/proc/province_strong_gates(list/gates)
	var/count = 0
	for (var/turf/G in gates)
		var/strong = FALSE
		for (var/turf/T in range(1, G))
			if (locate(/obj/structure/castle_gate/portcullis) in T)
				strong = TRUE
				break
		var/up = multiz_level_above(G.z)
		if (!strong && up)
			for (var/turf/T in range(1, locate(G.x, G.y, up)))
				if (locate(/obj/structure/murder_hole) in T)
					strong = TRUE
					break
		if (strong)
			count++
	return count

// --- The checklist ------------------------------------------------------------------

// Rows list(rank, label, met) for the settlement around seat.
/proc/province_rank_rows(obj/structure/faction_hall/seat, group, residents)
	var/list/rows = list()
	var/list/factions = province_group_factions(group)
	var/tier = seat.tier
	var/houses = 0
	var/guests = 0
	var/list/housed = list()
	for (var/obj/structure/bed/B in all_beds)
		if (QDELETED(B) || !B.anchored || !isturf(B.loc) || B.z != seat.z || max(abs(B.x - seat.x), abs(B.y - seat.y)) > RANK_SETTLEMENT)
			continue
		var/account = B.persistence_bed_owner_ckey
		if (!account)
			guests++
			continue
		if (housed[account] || !province_indoors(B.loc))
			continue
		for (var/faction in factions)
			if (map.faction_on_roster(faction, account))
				housed[account] = TRUE
				houses++
				break
	var/well = FALSE
	var/stall = FALSE
	var/bench = FALSE
	for (var/obj/structure/O in range(RANK_SETTLEMENT, seat))
		if (istype(O, /obj/structure/sink/well) || istype(O, /obj/structure/fluid_tank/cistern) || istype(O, /obj/structure/reagent_dispensers/cistern))
			well = TRUE
		else if (istype(O, /obj/structure/vending/sales/market_stall))
			stall = TRUE
		else if (istype(O, /obj/structure/research_bench) && !istype(O, /obj/structure/research_bench/adminbench))
			bench = TRUE
	var/station = FALSE
	for (var/obj/structure/recruitment_station/S in recruitment_stations)
		if (!QDELETED(S) && (S.faction in factions) && isturf(S.loc) && S.z == seat.z && max(abs(S.x - seat.x), abs(S.y - seat.y)) <= RANK_SETTLEMENT && !province_station_problem(S))
			station = TRUE
			break
	var/taxbox = FALSE
	for (var/obj/structure/closet/crate/faction_strongbox/B in faction_strongboxes)
		if (QDELETED(B) || !(B.faction in factions) || !isturf(B.loc) || B.z != seat.z || max(abs(B.x - seat.x), abs(B.y - seat.y)) > RANK_SETTLEMENT)
			continue
		var/list/civ = map.custom_civs[B.faction]
		if (islist(civ) && civ.len >= 10 && ((isnum(civ[9]) && civ[9] > 0) || (isnum(civ[10]) && civ[10] > 0)))
			taxbox = TRUE
			break
	var/plots = 0
	for (var/faction in factions)
		var/list/plotted = map.land_plots(faction)
		for (var/id in plotted)
			var/list/row = map.land_plot(faction, id)
			if (row && row[6] == seat.z && max(abs((row[2] + row[4]) / 2 - seat.x), abs((row[3] + row[5]) / 2 - seat.y)) <= RANK_SETTLEMENT)
				plots++
	var/list/ring = tier >= 3 ? province_ring(seat) : list("closed" = FALSE, "gates" = list(), "stone" = FALSE, "slits" = 0, "paved" = 0)
	var/list/gates = ring["gates"]
	rows += list(list(1, "a council fire as the seat", tier >= 1))
	rows += list(list(1, "4 resident members (now [residents])", residents >= 4))
	rows += list(list(2, "a longhouse as the seat", tier >= 2))
	rows += list(list(2, "7 resident members", residents >= 7))
	rows += list(list(2, "3 members' beds under a roof (now [houses])", houses >= 3))
	rows += list(list(2, "a well or cistern", well))
	rows += list(list(2, "a working recruitment station", station))
	rows += list(list(2, "4 registered plots (now [plots])", plots >= 4))
	rows += list(list(2, "2 guest beds, fastened and unclaimed (now [guests])", guests >= 2))
	rows += list(list(3, "a town hall as the seat", tier >= 3))
	rows += list(list(3, "11 resident members", residents >= 11))
	rows += list(list(3, "a closed wall or palisade ring around the seat with a gate", ring["closed"] && length(gates) > 0))
	rows += list(list(3, "a watchtower: a roofed upper floor within [RANK_WATCHTOWER_RANGE] tiles of a gate", length(gates) > 0 && province_watchtower(gates)))
	rows += list(list(3, "the faction's strongbox here, with a sales or business tax set", taxbox))
	rows += list(list(3, "10 registered plots", plots >= 10))
	rows += list(list(3, "a market stall", stall))
	rows += list(list(3, "4 guest beds", guests >= 4))
	rows += list(list(4, "a capitol as the seat", tier >= 4))
	rows += list(list(4, "16 resident members", residents >= 16))
	rows += list(list(4, "the whole ring of stone, brick or concrete", ring["closed"] && ring["stone"]))
	rows += list(list(4, "12 arrow slits, gun loops or battlements in the ring (now [ring["slits"]])", ring["closed"] && ring["slits"] >= 12))
	rows += list(list(4, "2 gates with a portcullis or a murder hole above", ring["closed"] && province_strong_gates(gates) >= 2))
	rows += list(list(4, "60 paved tiles inside the ring (now [ring["paved"]])", ring["closed"] && ring["paved"] >= 60))
	rows += list(list(4, "a research bench", bench))
	rows += list(list(4, "20 registered plots", plots >= 20))
	rows += list(list(4, "6 guest beds", guests >= 6))
	return rows

// The highest rank whose list, and every lower one, is met.
/proc/province_rank_met(list/rows)
	var/rank = 0
	for (var/r in 1 to 4)
		for (var/list/row in rows)
			if (row[1] == r && !row[3])
				return rank
		rank = r
	return rank

// Rechecks province c held by group, at most every RANK_CHECK_INTERVAL unless forced.
/proc/province_rank_check(c, group, residents, force = FALSE)
	var/list/check = province_rank_checks[c]
	if (!force && islist(check) && world.time - check[1] < RANK_CHECK_INTERVAL && check[5] == group)
		return check
	var/obj/structure/faction_hall/seat = province_seat(c, group)
	var/list/rows = seat ? province_rank_rows(seat, group, residents) : list()
	var/rank = province_rank_of(c)
	if (seat && rank >= 2) // a ranked settlement pays its upkeep (province_upkeep.dm)
		rows += list(list(rank, "this week's upkeep paid from the strongbox", province_upkeep_paid(c, group, seat)))
	check = list(world.time, seat, seat ? province_rank_met(rows) : 0, rows, group)
	province_rank_checks[c] = check
	return check

// Moves ranks on; called by province_holding_update for every province.
/proc/province_rank_update(c, holder, list/stake, name)
	var/list/row = province_rank_row(c)
	if (!holder)
		row[1] = 0
		row[2] = 0
		province_rank_checks -= c
		return
	var/list/groups = islist(stake) ? stake["groups"] : null
	var/list/G = islist(groups) ? groups[holder] : null
	var/residents = islist(G) ? G[2] : 0
	var/list/check = province_rank_check(c, holder, residents)
	var/met = check[3]
	if (met > row[1])
		row[1] = met
		row[2] = 0
		province_tell_leaders(holder, "Your settlement in the [name] is now a [province_rank_name(met)].")
		return
	if (met == row[1])
		if (row[2])
			province_tell_leaders(holder, "Your [province_rank_name(met)] in the [name] is whole again.")
		row[2] = 0
		return
	var/now = world.realtime
	if (!row[2])
		row[2] = now
		province_tell_leaders(holder, "Your [province_rank_name(row[1])] in the [name] has fallen short of its rank. Repair it within [RANK_DROP_HOURS] hours or it drops a rank; its hall shows what is missing.")
		return
	if (now - row[2] < RANK_DROP_HOURS * 36000)
		return
	row[1] = max(0, row[1] - 1)
	row[2] = row[1] > met ? now : 0
	province_tell_leaders(holder, "Your settlement in the [name] has dropped to [row[1] ? "a [province_rank_name(row[1])]" : "no rank"].")

/proc/province_rank_text(c)
	var/rank = province_rank_of(c)
	if (!rank)
		return null
	var/list/R = map.province_ranks()
	var/list/row = R[c]
	if (islist(row) && row.len == 2 && row[2])
		return "[province_rank_name(rank)], short of its rank: drops in [round(max(0, RANK_DROP_HOURS * 36000 - (world.realtime - row[2])) / 36000)] h"
	return province_rank_name(rank)

// --- The Province ledger -----------------------------------------------------------

// Shown by a seat's hall to anyone who uses it (faction_hall.dm).
/proc/province_ledger_show(mob/user, obj/structure/faction_hall/hall)
	if (!user || !hall || !hall.faction || !map || !map.province_map())
		return FALSE
	var/datum/province_map/P = map.province_map()
	var/c = P.char_at(hall.x, hall.y)
	if (!c)
		return FALSE
	var/group = province_group_of(hall.faction)
	var/holder = province_holder_of(c)
	var/name = P.names[c]
	var/list/lines = list("<h3>Province ledger: the [html_encode(name)]</h3>")
	if (holder != group)
		lines += "<p>[html_encode(province_group_name(group))] does not hold the [html_encode(name)] ([html_encode(province_holding_text(c))]). A side that leads a province for 72 hours takes it; its best hall there becomes the seat of a settlement that can rank from Camp to City.</p>"
	else
		var/list/stakes = province_stakes()
		var/list/S = stakes[c]
		var/list/groups = islist(S) ? S["groups"] : null
		var/list/G = islist(groups) ? groups[group] : null
		var/list/check = province_rank_check(c, group, islist(G) ? G[2] : 0, TRUE)
		var/obj/structure/faction_hall/seat = check[2]
		var/rank = province_rank_effective(c)
		if (seat != hall)
			lines += "<p>This hall is not the seat: [seat ? "the [html_encode(seat.name)] at [seat.x],[seat.y] is" : "no standing hall is"].</p>"
		lines += "<p>Rank: <b>[html_encode(province_rank_text(c) || "no rank yet")]</b>. Held [html_encode(province_holding_text(c))].</p>"
		lines += "<p>[province_upkeep_text(c)]</p>"
		if (province_rich_resource(c)) // province_rich.dm
			lines += "<p>The [html_encode(name)] is rich in [province_rich_resource(c)]: its seam gives [province_rich_cap(c)] loads a day at this rank ([province_rich_left(c)] left today).</p>"
		lines += "<p>[html_encode(province_siege_text(c))] Rivals can besiege the seat only in this window, and who holds the province changes only then.</p>"
		lines += "<p>A rival needs [province_rank_margin(rank)] times your stake to take it, a hold that slips lasts [province_rank_lose_hours(rank)] hours, your side's best province adds [RANK_MEMBERS_PER_RANK] members a rank to each faction's limit, and a resident's bed start in this settlement costs [province_rank_bed_text(rank)] what a station start does.</p>"
		var/list/table = list("<table class='regions'><tr><th>Rank</th><th>Needs</th><th></th></tr>")
		for (var/list/row in check[4])
			if (row[1] > max(rank, check[3]) + 1)
				continue
			table += "<tr><td>[province_rank_name(row[1])]</td><td>[html_encode(row[2])]</td><td>[row[3] ? "done" : "<b>missing</b>"]</td></tr>"
		table += "</table>"
		lines += jointext(table, "")
		lines += "<p>The settlement is everything within [RANK_SETTLEMENT] tiles of the seat. A rank rises as soon as its list and every lower one are met; one that falls short drops a rank after [RANK_DROP_HOURS] hours. Residents and the wall ring are counted at most once an hour.</p>"
	var/datum/browser/popup = new(user, "province_ledger", "Province ledger", 640, 560)
	popup.add_head_content("<style>table.regions{border-collapse:collapse;width:100%}table.regions th,table.regions td{padding:3px 6px;text-align:left;border-bottom:1px solid #444}</style>")
	popup.set_content(jointext(lines, ""))
	popup.open()
	return TRUE

#undef RANK_SETTLEMENT
#undef RANK_DROP_HOURS
#undef RANK_CHECK_INTERVAL
#undef RANK_MEMBERS_PER_RANK
#undef RANK_WATCHTOWER_RANGE
