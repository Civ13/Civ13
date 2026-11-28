// Rich provinces (docs/provinces.md, "Rich provinces"), from the Fable-reviewed plan.
//
// Two provinces of each continent (three on one with more than 8) hold its
// rich deposits. Each is rich in one of the continent's own resources
// (continent_resources.dm), which is mined there at three times the normal
// rate instead of twice. Each also has one rich seam: a marked tile near the
// province's middle that a pickaxe works without end, a load at a time, up to a
// daily cap that grows with the holder's settlement rank. Anyone can work it;
// holding the province is what makes the cap worth having. A side's third and
// later rich provinces on a land give half. Taking a province takes its future
// yield, not anything mined before.
//
// The rich provinces and their seams follow from the map and its province
// file, so they never change unless the file does. State: map.faction_recruitment
// ["province_rich"]: char -> list(day, loads taken that day). The marker is a
// runtime overlay, put back by the activity count. Nothing here sleeps.

#define RICH_LOADS_UNRANKED 4
#define RICH_SEAM_WORK 480 // a rock wall takes 240
#define RICH_SPOT_RANGE 60
#define RICH_SAMPLE 4

var/global/list/province_rich_cache = null // char -> resource
var/global/list/province_rich_spots = null // char -> turf, or FALSE when none fits
var/global/list/province_rich_busy = list()

// Resource -> the ore a rich seam gives and its per-load amount range.
/proc/province_rich_ores()
	var/static/list/ores = list(
		"copper" = list(/obj/item/stack/ore/copper, 6, 10),
		"tin" = list(/obj/item/stack/ore/tin, 6, 10),
		"iron" = list(/obj/item/stack/ore/iron, 6, 10),
		"zinc" = list(/obj/item/stack/ore/zinc, 6, 10),
		"coal" = list(/obj/item/stack/ore/coal, 8, 14),
		"lead" = list(/obj/item/stack/ore/lead, 3, 5),
		"saltpeter" = list(/obj/item/stack/ore/saltpeter, 3, 5),
		"sulphur" = list(/obj/item/stack/ore/sulphur, 3, 5),
		"silver" = list(/obj/item/stack/ore/silver, 2, 3),
		"gold" = list(/obj/item/stack/ore/gold, 1, 2),
		"bauxite" = list(/obj/item/stack/ore/bauxite, 3, 5),
		"uranium" = list(/obj/item/stack/ore/uranium, 1, 2),
	)
	return ores

// The age each resource opens at, as the rock walls give it (floor_attackby.dm).
/proc/province_rich_age(resource)
	switch (resource)
		if ("iron", "zinc")
			return 1
		if ("coal", "lead", "saltpeter", "sulphur")
			return 2
		if ("bauxite")
			return 4
		if ("uranium")
			return 8
	return 0

// Province char -> the resource it is rich in, for this land; empty off the continents.
/proc/province_rich_list()
	if (islist(province_rich_cache))
		return province_rich_cache
	var/list/out = list()
	var/datum/province_map/P = map ? map.province_map() : null
	var/list/home = continent_home()
	if (!P || !islist(home))
		return out
	province_rich_cache = out
	var/list/candidates = list()
	for (var/resource in home)
		if (province_rich_ores()[resource])
			candidates += resource
	if (!candidates.len)
		return out
	var/want = P.names.len > 8 ? 3 : 2
	var/list/order = list()
	for (var/c in P.names)
		order[c] = mountain_seam_hash("[map.ID]|[c]|rich") // mountain_seams.dm
	while (out.len < want && order.len)
		var/best = null
		for (var/c in order)
			if (!best || order[c] < order[best] || (order[c] == order[best] && c < best))
				best = c
		out[best] = candidates[(out.len % candidates.len) + 1] // each of its resources in turn
		order -= best
	return out

/proc/province_rich_resource(c)
	return c ? province_rich_list()[c] : null

// The resource the province holding turf T is rich in, or null.
/proc/province_rich_at(turf/T)
	if (!T || !map)
		return null
	var/datum/province_map/P = map.province_map()
	return P ? province_rich_resource(P.char_at(T.x, T.y)) : null

// The rich seam's tile in province c, or null when no open ground fits.
/proc/province_rich_spot(c)
	if (!islist(province_rich_spots))
		province_rich_spots = list()
	if (!isnull(province_rich_spots[c]))
		return province_rich_spots[c] || null
	province_rich_spots[c] = FALSE
	var/datum/province_map/P = map ? map.province_map() : null
	if (!P || !P.surface_z || !province_rich_resource(c))
		return null
	// The middle of the province, from a sample of its tiles.
	var/sx = 0
	var/sy = 0
	var/n = 0
	for (var/y in 1 to P.maxy step RICH_SAMPLE)
		var/row = P.rows[P.maxy - y + 1]
		var/at = findtext(row, c)
		while (at)
			if ((at - 1) % RICH_SAMPLE == 0)
				sx += at
				sy += y
				n++
			at = findtext(row, c, at + 1)
	if (!n)
		return null
	var/cx = round(sx / n)
	var/cy = round(sy / n)
	// The nearest open ground of the province to it.
	for (var/r in 0 to RICH_SPOT_RANGE)
		for (var/dx in -r to r)
			for (var/dy in list(-r, r))
				var/turf/T = province_rich_spot_try(P, c, cx + dx, cy + dy)
				if (T)
					province_rich_spots[c] = T
					return T
			if (abs(dx) == r)
				for (var/dy in -r + 1 to r - 1)
					var/turf/T = province_rich_spot_try(P, c, cx + dx, cy + dy)
					if (T)
						province_rich_spots[c] = T
						return T
	return null

/proc/province_rich_spot_try(datum/province_map/P, c, x, y)
	if (P.char_at(x, y) != c)
		return null
	var/turf/T = locate(x, y, P.surface_z)
	if (!istype(T, /turf/floor) || istype(T, /turf/floor/beach/water) || T.density)
		return null
	return T

// TRUE when T is the rich seam of its province.
/proc/province_rich_seam_at(turf/T)
	if (!T || !map || !province_rich_list().len)
		return FALSE
	var/datum/province_map/P = map.province_map()
	var/c = P ? P.char_at(T.x, T.y) : null
	if (!c || !province_rich_resource(c))
		return FALSE
	return province_rich_spot(c) == T

// Loads a day: by the holder's effective rank, halved for a side's third and
// later rich provinces here.
/proc/province_rich_cap(c)
	var/holder = province_holder_of(c)
	if (!holder)
		return RICH_LOADS_UNRANKED
	var/loads = RICH_LOADS_UNRANKED
	switch (province_rank_effective(c)) // province_siege.dm
		if (1) loads = 6
		if (2) loads = 10
		if (3) loads = 16
		if (4) loads = 24
	var/before = 0
	for (var/other in province_rich_list())
		if (other != c && "[other]" < "[c]" && province_holder_of(other) == holder)
			before++
	return before >= 2 ? max(1, round(loads / 2)) : loads

/proc/province_rich_row(c)
	var/list/S = map.recruitment_state()
	if (!islist(S["province_rich"]))
		S["province_rich"] = list()
	var/list/all = S["province_rich"]
	var/list/row = all[c]
	var/today = province_day() // province_stake.dm
	if (!islist(row) || row.len != 2 || row[1] != today)
		row = list(today, 0)
		all[c] = row
	return row

/proc/province_rich_left(c)
	var/list/row = province_rich_row(c)
	return max(0, province_rich_cap(c) - row[2])

// --- The seam -------------------------------------------------------------------

/proc/province_rich_marker(resource)
	var/static/list/markers = list()
	var/image/I = markers[resource]
	if (!I)
		var/obj/item/stack/ore/O = province_rich_ores()[resource][1]
		I = image(initial(O.icon), icon_state = initial(O.icon_state), layer = TURF_LAYER + 0.01)
		I.appearance_flags = RESET_COLOR
		markers[resource] = I
	return I

// Puts each rich seam's marker back; called with each activity count.
/proc/province_rich_mark_all()
	if (!map || !map.province_map() || !building_standing_ready())
		return
	for (var/c in province_rich_list())
		var/turf/T = province_rich_spot(c)
		if (!T)
			continue
		var/image/I = province_rich_marker(province_rich_resource(c))
		T.overlays -= I
		T.overlays += I

// Pickaxe on a floor tile (floor_attackby.dm). TRUE when it was the rich seam.
/proc/province_rich_attackby(turf/T, obj/item/C, mob/living/human/H)
	if (!is_tool(C, TOOL_PICKAXE) || !ishuman(H) || !province_rich_seam_at(T))
		return FALSE
	province_rich_work(H, C, T)
	return TRUE

/proc/province_rich_text_at(turf/T)
	var/datum/province_map/P = map.province_map()
	var/c = P.char_at(T.x, T.y)
	var/resource = province_rich_resource(c)
	return "A rich seam of [resource] in the [P.names[c]]: [province_rich_left(c)] of [province_rich_cap(c)] loads left today."

/proc/province_rich_work(mob/living/human/H, obj/item/P, turf/T)
	var/tile_key = "[T.x],[T.y],[T.z]"
	var/worker_key = "\ref[H]"
	if (province_rich_busy[tile_key] || province_rich_busy[worker_key] || H.pickaxe_mining_action || !H.may_do_after || get_dist(H, T) > 1)
		return FALSE
	var/datum/province_map/PM = map.province_map()
	var/c = PM.char_at(T.x, T.y)
	var/resource = province_rich_resource(c)
	if (map.ordinal_age < province_rich_age(resource))
		to_chat(H, SPAN_NOTICE("A rich seam of [resource] runs down here, an ore you cannot work yet."))
		return FALSE
	if (!province_rich_left(c))
		to_chat(H, SPAN_NOTICE("[province_rich_text_at(T)] The seam is worked out for today."))
		return FALSE
	province_rich_busy[tile_key] = TRUE
	province_rich_busy[worker_key] = TRUE
	. = FALSE
	var/time = H.hair_dusty_work_delay(work_delay_per_speed(H, RICH_SEAM_WORK, WORK_MINE, P))
	H.visible_message(SPAN_NOTICE("[H] starts to work the rich seam with \the [P]."), SPAN_NOTICE("You start to work the rich seam with \the [P]. [province_rich_text_at(T)]"))
	playsound(T, 'sound/effects/pickaxe.ogg', 100, TRUE)
	var/datum/resource_work_animation/work_animation = H.prepare_resource_work_animation(P, T, time)
	var/done = do_after(H, time, T)
	if (work_animation)
		work_animation.stop()
	if (done && P.loc == H && get_dist(H, T) <= 1 && province_rich_left(c))
		var/list/row = province_rich_row(c)
		row[2]++
		H.adaptStat("strength", 1)
		var/list/ore = province_rich_ores()[resource]
		var/ore_type = ore[1]
		var/obj/item/stack/ore/O = new ore_type(T)
		O.amount = min(rand(ore[2], ore[3]), O.max_amount)
		O.update_icon()
		to_chat(H, SPAN_GREEN_BOLD("You work some [initial(O.name)] loose from the rich seam."))
		. = TRUE
	province_rich_busy -= tile_key
	province_rich_busy -= worker_key

// One line for Province Holdings and Land Status.
/proc/province_rich_text()
	var/list/rich = province_rich_list()
	if (!rich.len)
		return ""
	var/datum/province_map/P = map.province_map()
	var/list/parts = list()
	for (var/c in rich)
		var/turf/T = province_rich_spot(c)
		parts += "the [P.names[c]] ([rich[c]][T ? ", seam at [T.x],[T.y]" : ""])"
	return "Rich provinces: [jointext(parts, "; ")]. Their resource comes three times as often there, and their seam gives a few loads a day without end, more the higher the holder's settlement ranks."

#undef RICH_LOADS_UNRANKED
#undef RICH_SEAM_WORK
#undef RICH_SPOT_RANGE
#undef RICH_SAMPLE
