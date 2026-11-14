// Admin tools for river stages (code/modules/1713/river_flood.dm, docs/river-flood.md).

/client/var/tmp/list/river_flood_images

/client/proc/river_flood_map()
	set category = "Debug"
	set name = "Flood Map"
	if (!check_rights(R_DEBUG))
		return
	var/datum/river_flood/F = map ? map.river_flood() : null
	if (!F)
		to_chat(src, SPAN_NOTICE("This map has no river flood file."))
		return
	var/list/order = list()
	for (var/i in 1 to F.count)
		order["[i]"] = F.stage[i]
	order = sortTim(order, /proc/cmp_numeric_dsc, TRUE)
	var/list/rows = list("<table><tr><th>Reach</th><th>Stage</th><th>Flow</th><th>Snow</th><th>Catchment</th><th>Drains to</th><th>Centre</th></tr>")
	var/shown = 0
	for (var/key in order)
		var/i = text2num(key)
		rows += "<tr><td>[i]</td><td>[round(F.stage[i], 0.01)]</td><td>[round(F.flow[i], 0.1)]</td><td>[round(F.snow[i], 0.1)]</td><td>[F.upstream[i]]</td><td>[F.down[i] || "-"]</td><td><a href='?_src_=holder;adminplayerobservecoodjump=1;X=[F.cx[i]];Y=[F.cy[i]];Z=[F.z_level]'>[F.cx[i]],[F.cy[i]]</a></td></tr>"
		if (++shown >= 60)
			break
	rows += "</table>"
	usr << browse("<html><head><title>Flood Map</title></head><body><p>[F.count] reaches on level [F.z_level], season [season]. Highest 60 shown.</p>[jointext(rows, "")]</body></html>", "window=flood_map;size=640x700")

/client/proc/river_flood_set_stage()
	set category = "Debug"
	set name = "Set River Stage"
	if (!check_rights(R_DEBUG))
		return
	var/datum/river_flood/F = map ? map.river_flood() : null
	if (!F)
		to_chat(src, SPAN_NOTICE("This map has no river flood file."))
		return
	var/target = input(src, "Stage in levels above normal ([RIVER_FLOOD_STAGE_MIN] to [RIVER_FLOOD_STAGE_CAP]):", "Set River Stage", 1) as num|null
	if (isnull(target))
		return
	target = clamp(target, RIVER_FLOOD_STAGE_MIN, RIVER_FLOOD_STAGE_CAP)
	var/turf/T = get_turf(mob)
	var/only = (T && T.z == F.z_level) ? F.reach_at(T.x, T.y) : 0
	if (only && alert(src, "Set only the reach you are standing in ([only]), or every reach?", "Set River Stage", "This reach", "Every reach") == "Every reach")
		only = 0
	for (var/i in 1 to F.count)
		if (only && i != only)
			continue
		F.flow[i] = F.upstream[i] * RIVER_FLOOD_MEAN_FLOW * (2 ** (target / (RIVER_FLOOD_STAGE_PER_DOUBLING * F.amplitude(i))))
		F.storage[i] = F.flow[i] / RIVER_FLOOD_RELEASE
		F.stage[i] = F.stage_for(i, F.flow[i])
		F.peak[i] = max(F.peak[i], F.stage[i])
	F.stages_changed()
	F.publish()
	log_admin("[key_name(src)] set river stage [target] on [only ? "reach [only]" : "every reach"].")
	message_admins("[key_name_admin(src)] set river stage [target] on [only ? "reach [only]" : "every reach"].")

/client/proc/river_flood_spring()
	set category = "Debug"
	set name = "Start Spring Flood"
	if (!check_rights(R_DEBUG))
		return
	var/datum/river_flood/F = map ? map.river_flood() : null
	if (!F)
		to_chat(src, SPAN_NOTICE("This map has no river flood file."))
		return
	// A winter's snow on every catchment, which melts from now on.
	for (var/i in 1 to F.count)
		F.snow[i] += F.area[i] * RIVER_FLOOD_SNOW_YIELD * 2 * 30
	F.publish()
	log_admin("[key_name(src)] laid a winter's snowpack on every river catchment.")
	message_admins("[key_name_admin(src)] laid a winter's snowpack on every river catchment; it melts outside winter.")

/client/proc/toggle_flood_thresholds()
	set category = "Debug"
	set name = "Show Flood Thresholds"
	if (!check_rights(R_DEBUG))
		return
	if (river_flood_images)
		images -= river_flood_images
		river_flood_images = null
		to_chat(src, SPAN_NOTICE("Flood thresholds hidden."))
		return
	var/datum/river_flood/F = map ? map.river_flood() : null
	if (!F)
		to_chat(src, SPAN_NOTICE("This map has no river flood file."))
		return
	river_flood_images = list()
	for (var/turf/T in view(world.view, mob))
		if (T.z != F.z_level)
			continue
		var/threshold = F.threshold_at(T.x, T.y)
		var/r = F.reach_at(T.x, T.y)
		if (isnull(threshold) || !r)
			continue
		var/depth = flood_depth_at(T)
		var/image/I = image(loc = T, layer = FLY_LAYER)
		I.plane = HUD_PLANE
		I.maptext = "<span style='font-family: Small Fonts; font-size: 7px; color: [depth > 0 ? "#7fd4ff" : "#ffe680"]; -dm-text-outline: 1px black'>[threshold]<br>[r]</span>"
		I.maptext_x = 8
		I.maptext_y = 6
		I.mouse_opacity = 0
		river_flood_images += I
	images += river_flood_images
	to_chat(src, SPAN_NOTICE("Showing flood thresholds (stage needed) and reach ids around you; blue tiles are under water now. Use the verb again to hide them."))

#undef RIVER_FLOOD_RELEASE
#undef RIVER_FLOOD_BASEFLOW
#undef RIVER_FLOOD_RAIN_YIELD
#undef RIVER_FLOOD_MEAN_FLOW
#undef RIVER_FLOOD_SNOW_YIELD
#undef RIVER_FLOOD_MELT_SPRING
#undef RIVER_FLOOD_MELT_SUMMER
#undef RIVER_FLOOD_STAGE_PER_DOUBLING
#undef RIVER_FLOOD_STAGE_MIN
#undef RIVER_FLOOD_STAGE_CAP
#undef RIVER_FLOOD_TICK
#undef RIVER_FLOOD_ID_DIGITS
