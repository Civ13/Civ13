// Provinces (docs/provinces.md). A continent is cut into provinces that
// follow the land: coasts, big rivers, lakes and mountain ranges. Factions
// will hold provinces (recruitment stations, stake, ranks); this file only
// reads the map's province file and answers which province a tile is in.
//
// The file is made by scripts/provinces.py and lives beside the height file:
// maps/heights/<map>.txt -> maps/provinces/<map>.txt. Every level of the map
// shares the surface's province, so a cave or an upper floor belongs to the
// province under it. A map without a province file (expedition lands, older
// maps) has no provinces. Nothing here sleeps.

/obj/map_metadata
	var/tmp/datum/province_map/province_map_cache = null
	var/tmp/province_map_loaded = FALSE

/obj/map_metadata/persistence_runtime_var(var/key)
	if (key == "province_map_cache" || key == "province_map_loaded")
		return TRUE
	return ..(key)

/datum/province_map
	should_save = FALSE
	var/maxx = 0
	var/maxy = 0
	// Row strings, north row first; "." is open sea in no province.
	var/list/rows = list()
	// Province character -> name, in file order.
	var/list/names = list()
	var/error = null

// The province character at x, y, or null.
/datum/province_map/proc/char_at(x, y)
	if (x < 1 || x > maxx || y < 1 || y > maxy)
		return null
	var/c = copytext(rows[maxy - y + 1], x, x + 1)
	return c == "." ? null : c

/proc/province_file_for(height_file)
	if (!istext(height_file) || !findtext(height_file, "maps/heights/"))
		return null
	return replacetext(height_file, "maps/heights/", "maps/provinces/")

// Parses a province file. Sets error and leaves no provinces on any problem.
/proc/province_map_parse(text, world_maxx, world_maxy)
	var/datum/province_map/P = new
	if (!istext(text) || !length(text))
		P.error = "empty province file"
		return P
	var/list/lines = splittext(replacetext(text, ascii2text(13), ""), "\n")
	if (lines.len < 4 || lines[1] != "civ13-provinces 1")
		P.error = "missing 'civ13-provinces 1' header"
		return P
	var/list/size = splittext(lines[2], " ")
	if (size.len != 3 || size[1] != "size")
		P.error = "missing 'size X Y' line"
		return P
	P.maxx = text2num(size[2])
	P.maxy = text2num(size[3])
	if (P.maxx != world_maxx || P.maxy != world_maxy)
		P.error = "size [size[2]]x[size[3]] does not match the world ([world_maxx]x[world_maxy])"
		return P
	var/i = 4 // line 3 names the surface z, which every level shares
	while (i <= lines.len && findtext(lines[i], "province ") == 1)
		var/rest = copytext(lines[i], 10)
		var/space = findtext(rest, " ")
		var/c = space == 2 ? copytext(rest, 1, 2) : null
		var/name = space == 2 ? trim(copytext(rest, 3)) : null
		if (!c || !length(name) || c == "." || P.names[c])
			P.error = "bad province line '[lines[i]]'"
			return P
		P.names[c] = name
		i++
	if (!P.names.len)
		P.error = "no provinces"
		return P
	for (var/r in 1 to P.maxy)
		var/row = i <= lines.len ? lines[i++] : null
		if (!istext(row) || length(row) != P.maxx)
			P.error = "row [r] is missing or the wrong length"
			return P
		P.rows += row
	return P

/obj/map_metadata/proc/province_map()
	if (province_map_loaded)
		return province_map_cache
	province_map_loaded = TRUE
	var/path = province_file_for(terrain_height_file)
	if (!path || !fexists(path))
		return null
	var/datum/province_map/P = province_map_parse(file2text(path), world.maxx, world.maxy)
	if (P.error)
		log_debug("Provinces [path] ignored: [P.error]")
		return null
	province_map_cache = P
	return P

// The name of the province holding a turf, or null.
/proc/province_name_at(turf/T)
	if (!T || !map)
		return null
	var/datum/province_map/P = map.province_map()
	if (!P)
		return null
	var/c = P.char_at(T.x, T.y)
	return c ? P.names[c] : null

// Admin view: this land's provinces, for Land Status.
/proc/province_admin_html(mob/viewer)
	var/datum/province_map/P = map ? map.province_map() : null
	if (!P)
		return "<p class='note'>This land has no provinces.</p>"
	var/here = province_name_at(viewer ? get_turf(viewer) : null)
	var/list/names = list()
	for (var/c in P.names)
		names += html_encode(P.names[c])
	var/resources = continent_resources_text() // continent_resources.dm
	return "<p>Provinces of this land ([P.names.len]): [jointext(names, ", ")].[here ? " You are in the [html_encode(here)]." : ""]</p>[resources ? "<p>[resources]</p>" : ""]" + province_standings_html()
