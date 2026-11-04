// Export a rectangle of the running world as a .dmm map, for turning a built
// area of a saved world into an authored map. Run it on a test server loaded
// from a copy of the save, never to edit the live world.
//
// Written per tile: objects (not mobs), the turf and the area, each with only
// dir, pixel offsets, icon_state and a stack's amount when they differ from the
// type's default. Everything else is left out and counted in the report: mobs,
// whatever is inside objects, renamed objects (player text), and runtime
// helpers such as lighting overlays. dmm_suite/read_map reads the result back.

#define MAP_EXPORT_MAX_SIDE 100
#define MAP_EXPORT_KEY_CHARS "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

/proc/map_export_key(index, key_length)
	var/chars = MAP_EXPORT_KEY_CHARS
	var/key = ""
	var/n = index - 1
	for(var/i in 1 to key_length)
		key = ascii2text(text2ascii(chars, (n % 52) + 1)) + key
		n = round(n / 52)
	return key

/proc/map_export_text(value)
	// dmm_suite and Dream Maker both read "..." with \" and \\ escapes; brackets
	// would be read as embedded expressions.
	value = replacetext(value, "\\", "\\\\")
	value = replacetext(value, "\"", "\\\"")
	value = replacetext(value, "\[", "\\\[")
	return "\"[value]\""

// Only fields a mapper sets, and only when they differ from the type default.
/proc/map_export_fields(atom/A)
	var/list/fields = list()
	if(A.dir != initial(A.dir)) fields += "dir = [A.dir]"
	if(A.pixel_x != initial(A.pixel_x)) fields += "pixel_x = [A.pixel_x]"
	if(A.pixel_y != initial(A.pixel_y)) fields += "pixel_y = [A.pixel_y]"
	if(istext(A.icon_state) && A.icon_state != initial(A.icon_state) && length(A.icon_state) <= 64 && !findtext(A.icon_state, "\n"))
		fields += "icon_state = [map_export_text(A.icon_state)]"
	if(istype(A, /obj/item/stack))
		var/obj/item/stack/S = A
		if(isnum(S.amount) && S.amount != initial(S.amount)) fields += "amount = [round(S.amount)]"
	return fields

/proc/map_export_model(atom/A)
	var/list/fields = map_export_fields(A)
	return fields.len ? "[A.type]{[jointext(fields, "; ")]}" : "[A.type]"

/proc/map_export_count(list/report, key, amount = 1)
	report[key] = (report[key] || 0) + amount

// Counts everything below A, at any depth.
/proc/map_export_nested(atom/A)
	var/count = 0
	for(var/atom/movable/inner in A)
		count += 1 + map_export_nested(inner)
	return count

// Returns the .dmm text for the rectangle between two turfs on one level, or
// null if the corners are invalid. report gets the counts of what was written
// and left out.
/proc/map_export_dmm(turf/corner_a, turf/corner_b, list/report)
	if(!isturf(corner_a) || !isturf(corner_b) || corner_a.z != corner_b.z) return null
	var/x1 = min(corner_a.x, corner_b.x)
	var/x2 = max(corner_a.x, corner_b.x)
	var/y1 = min(corner_a.y, corner_b.y)
	var/y2 = max(corner_a.y, corner_b.y)
	if(x2 - x1 + 1 > MAP_EXPORT_MAX_SIDE || y2 - y1 + 1 > MAP_EXPORT_MAX_SIDE) return null
	var/z = corner_a.z
	var/list/models = list()   // model text = index
	var/list/order = list()    // model texts in index order
	var/list/cells = list()    // per tile, top row first: model index
	for(var/y = y2 to y1 step -1)
		for(var/x = x1 to x2)
			var/turf/T = locate(x, y, z)
			var/list/parts = list()
			for(var/atom/movable/AM in T)
				if(ismob(AM))
					map_export_count(report, "mobs_left_out", 1 + map_export_nested(AM))
					continue
				// isobj() is also true for bare /atom/movable helpers like lighting overlays.
				if(!istype(AM, /obj))
					map_export_count(report, "runtime_objects_left_out")
					continue
				var/obj/O = AM
				var/nested = map_export_nested(O)
				if(nested) map_export_count(report, "contents_left_out", nested)
				if(O.name != initial(O.name) || O.desc != initial(O.desc))
					map_export_count(report, "renamed_objects_reset")
				parts += map_export_model(O)
				map_export_count(report, "objects")
			parts += map_export_model(T)
			parts += "[T.loc.type]"
			var/model = jointext(parts, ",")
			if(!models[model])
				order += model
				models[model] = order.len
			cells += models[model]
			map_export_count(report, "tiles")
	var/key_length = 1
	while(52 ** key_length < order.len) key_length++
	var/list/lines = list()
	for(var/i in 1 to order.len)
		lines += "\"[map_export_key(i, key_length)]\" = ([order[i]])"
	var/width = x2 - x1 + 1
	var/list/rows = list()
	var/row = ""
	for(var/i in 1 to cells.len)
		row += map_export_key(cells[i], key_length)
		if(i % width == 0)
			rows += row
			row = ""
	report["models"] = order.len
	report["width"] = width
	report["height"] = y2 - y1 + 1
	return jointext(lines, "\n") + "\n\n(1,1,1) = {\"\n" + jointext(rows, "\n") + "\n\"}\n"

/client/var/turf/map_export_corner = null

/client/proc/mark_map_export_corner()
	set name = "Mark Map Export Corner"
	set category = "Debug"
	set desc = "Mark your tile as one corner of an area to export as a map."
	if(!check_rights(R_DEBUG)) return
	map_export_corner = get_turf(mob)
	to_chat(src, "<span class='notice'>Export corner marked at ([map_export_corner.x],[map_export_corner.y],[map_export_corner.z]). Stand on the opposite corner and use Export Map Area.</span>")

/client/proc/export_map_area()
	set name = "Export Map Area"
	set category = "Debug"
	set desc = "Write the area between the marked corner and your tile to data/map_exports as a .dmm map."
	if(!check_rights(R_DEBUG)) return
	var/turf/here = get_turf(mob)
	if(!map_export_corner || !here || map_export_corner.z != here.z)
		to_chat(src, "<span class='warning'>Mark a corner on this level first.</span>")
		return
	var/list/report = list()
	var/dmm = map_export_dmm(map_export_corner, here, report)
	if(!dmm)
		to_chat(src, "<span class='warning'>The area can be at most [MAP_EXPORT_MAX_SIDE] tiles on each side.</span>")
		return
	var/base = "data/map_exports/area-[time2text(world.realtime, "YYYYMMDD-hhmmss")]-[here.z]"
	if(fexists("[base].dmm")) fdel("[base].dmm")
	if(fexists("[base].json")) fdel("[base].json")
	text2file(dmm, "[base].dmm")
	text2file(json_encode(report), "[base].json")
	to_chat(src, "<span class='notice'>Exported [report["width"]]x[report["height"]] tiles to [base].dmm ([report["objects"] || 0] objects; left out: [report["mobs_left_out"] || 0] mobs, [report["contents_left_out"] || 0] items inside objects).</span>")
	log_admin("[key_name(usr)] exported the map area ([map_export_corner.x],[map_export_corner.y])-([here.x],[here.y]) on level [here.z] to [base].dmm.")

/client/add_admin_verbs()
	..()
	if(holder && (holder.rights & R_DEBUG))
		verbs += /client/proc/mark_map_export_corner
		verbs += /client/proc/export_map_area

/client/remove_admin_verbs()
	..()
	verbs -= /client/proc/mark_map_export_corner
	verbs -= /client/proc/export_map_area

#undef MAP_EXPORT_MAX_SIDE
#undef MAP_EXPORT_KEY_CHARS
