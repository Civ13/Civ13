// Terrain height (docs/terrain-height.md): optional per-tile hill levels for
// one native z-level. Walking uphill costs extra move delay, walking downhill
// saves a little. Off unless a map names a height file; every tile then reads 0.
// Heights are fixed map data loaded from a text file, so saves do not change.

// Delay added per level climbed, in deciseconds (walking a flat tile is ~2.9).
#define TERRAIN_UPHILL_DELAY 1
// Delay saved per level descended.
#define TERRAIN_DOWNHILL_BONUS 0.5
// Downhill never saves more than this share of the step's delay.
#define TERRAIN_DOWNHILL_MAX_SHARE 0.25
// A one-tile step never counts more than this many levels.
#define TERRAIN_MAX_LEVEL_STEP 4

/obj/map_metadata
	// Project-relative height file, for example "maps/heights/nomads_gaia.txt".
	var/terrain_height_file = null
	var/tmp/datum/terrain_heights/terrain_heights_cache = null

/obj/map_metadata/persistence_runtime_var(var/key)
	if (key == "terrain_height_file" || key == "terrain_heights_cache")
		return TRUE
	return ..(key)

/datum/terrain_heights
	should_save = FALSE
	var/maxx = 0
	var/maxy = 0
	// "z" -> list of row strings, north row first.
	var/list/rows_by_z = list()
	var/error = null

/datum/terrain_heights/proc/at(x, y, z)
	var/list/rows = rows_by_z["[z]"]
	if (!rows || x < 1 || x > maxx || y < 1 || y > maxy)
		return 0
	var/code = text2ascii(rows[maxy - y + 1], x)
	if (code >= 97)
		return code - 87
	return code - 48

// Parses the height text. Returns null and sets error on any problem, so a bad
// file leaves the map flat instead of half-loaded.
/proc/terrain_heights_parse(text, world_maxx, world_maxy, world_maxz)
	var/datum/terrain_heights/H = new
	if (!istext(text) || !length(text))
		H.error = "empty height file"
		return H
	var/list/lines = splittext(replacetext(text, ascii2text(13), ""), "\n")
	var/i = 1
	var/list/header = splittext(lines[i++], " ")
	if (header.len != 2 || header[1] != "civ13-terrain-heights" || header[2] != "1")
		H.error = "missing 'civ13-terrain-heights 1' header"
		return H
	var/list/size = i <= lines.len ? splittext(lines[i++], " ") : list()
	if (size.len != 3 || size[1] != "size")
		H.error = "missing 'size X Y' line"
		return H
	H.maxx = text2num(size[2])
	H.maxy = text2num(size[3])
	if (H.maxx != world_maxx || H.maxy != world_maxy)
		H.error = "size [size[2]]x[size[3]] does not match the world ([world_maxx]x[world_maxy])"
		return H
	while (i <= lines.len)
		var/line = lines[i++]
		if (!length(line))
			continue
		var/list/zline = splittext(line, " ")
		var/z = zline.len == 2 && zline[1] == "z" ? text2num(zline[2]) : null
		if (!isnum(z) || z != round(z) || z < 1 || z > world_maxz || H.rows_by_z["[z]"])
			H.error = "bad or repeated z line '[line]'"
			return H
		var/list/rows = list()
		for (var/r in 1 to H.maxy)
			if (i > lines.len)
				H.error = "z [z] has [rows.len] of [H.maxy] rows"
				return H
			var/row = lines[i++]
			if (length(row) != H.maxx || !terrain_height_row_valid(row))
				H.error = "z [z] row [r] must be [H.maxx] characters of 0-9 or a-f"
				return H
			rows += row
		H.rows_by_z["[z]"] = rows
	if (!H.rows_by_z.len)
		H.error = "no z levels"
	return H

/proc/terrain_height_row_valid(row)
	var/static/regex/bad = regex(@"[^0-9a-f]")
	return !bad.Find(row)

/obj/map_metadata/proc/terrain_heights()
	if (!terrain_height_file)
		return null
	if (!terrain_heights_cache)
		var/text = fexists(terrain_height_file) ? file2text(terrain_height_file) : null
		terrain_heights_cache = terrain_heights_parse(text, world.maxx, world.maxy, world.maxz)
		if (terrain_heights_cache.error)
			log_debug("Terrain heights [terrain_height_file] ignored: [terrain_heights_cache.error]")
	if (terrain_heights_cache.error)
		return null
	return terrain_heights_cache

/proc/terrain_height_at(turf/T)
	if (!T || !map || !map.terrain_height_file)
		return 0
	var/datum/terrain_heights/H = map.terrain_heights()
	return H ? H.at(T.x, T.y, T.z) : 0

// Extra move delay (negative when it saves time) for one step between two
// neighbouring turfs, given the step's delay before this term.
/proc/terrain_slope_delay(turf/origin, turf/destination, step_delay)
	if (!origin || !destination || origin.z != destination.z || !map || !map.terrain_height_file)
		return 0
	var/levels = clamp(terrain_height_at(destination) - terrain_height_at(origin), -TERRAIN_MAX_LEVEL_STEP, TERRAIN_MAX_LEVEL_STEP)
	if (levels > 0)
		return levels * TERRAIN_UPHILL_DELAY
	if (levels < 0)
		return -min(-levels * TERRAIN_DOWNHILL_BONUS, max(0, step_delay) * TERRAIN_DOWNHILL_MAX_SHARE)
	return 0

// Admin view: the height number on every tile in view, until toggled off.
/client/var/tmp/list/terrain_height_images

/client/proc/toggle_terrain_heights()
	set category = "Debug"
	set name = "Show Terrain Heights"
	if (!check_rights(R_DEBUG))
		return
	if (terrain_height_images)
		images -= terrain_height_images
		terrain_height_images = null
		to_chat(src, SPAN_NOTICE("Terrain heights hidden."))
		return
	if (!map || !map.terrain_height_file)
		to_chat(src, SPAN_NOTICE("This map has no terrain height file; every tile is height 0."))
		return
	if (!map.terrain_heights())
		to_chat(src, SPAN_WARNING("[map.terrain_height_file] could not be loaded: [map.terrain_heights_cache ? map.terrain_heights_cache.error : "unknown error"]."))
		return
	terrain_height_images = list()
	for (var/turf/T in view(world.view, mob))
		var/height = terrain_height_at(T)
		var/image/I = image(loc = T, layer = FLY_LAYER)
		I.plane = HUD_PLANE
		I.maptext = "<span style='font-family: Small Fonts; font-size: 7px; color: [height ? "#ffe680" : "#9ad0ff"]; -dm-text-outline: 1px black'>[height]</span>"
		I.maptext_x = 12
		I.maptext_y = 10
		I.mouse_opacity = 0
		terrain_height_images += I
	images += terrain_height_images
	to_chat(src, SPAN_NOTICE("Showing terrain heights around you; use the verb again to hide them."))

#undef TERRAIN_UPHILL_DELAY
#undef TERRAIN_DOWNHILL_BONUS
#undef TERRAIN_DOWNHILL_MAX_SHARE
#undef TERRAIN_MAX_LEVEL_STEP
