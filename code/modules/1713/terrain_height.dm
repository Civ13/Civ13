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
// Share of the uphill delay paid when stepping onto packed ground (tamped earth).
#define TERRAIN_PACKED_UPHILL_SHARE 0.5
// A step of this many levels or more is steep: it tires the climber and is
// described in chat.
#define TERRAIN_STEEP_LEVELS 3
// Stamina spent per level climbed on a steep step.
#define TERRAIN_CLIMB_STAMINA 0.5
// Deciseconds between two steep-slope messages to the same mob.
#define TERRAIN_SLOPE_MESSAGE_DELAY 100

/mob/var/next_slope_message = -1

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
	// "z" -> list of row strings, north row first, with player grading applied.
	var/list/rows_by_z = list()
	// "z" -> the same rows as loaded from the file, before any grading.
	var/list/base_rows_by_z = list()
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
		H.base_rows_by_z["[z]"] = rows.Copy()
	if (!H.rows_by_z.len)
		H.error = "no z levels"
	return H

// The file's level for a tile, ignoring grading.
/datum/terrain_heights/proc/base_at(x, y, z)
	var/list/rows = base_rows_by_z["[z]"]
	if (!rows || x < 1 || x > maxx || y < 1 || y > maxy)
		return 0
	var/code = text2ascii(rows[maxy - y + 1], x)
	return code >= 97 ? code - 87 : code - 48

// Sets a graded tile's level and updates the corner lights around it.
/datum/terrain_heights/proc/set_level(x, y, z, level)
	var/list/rows = rows_by_z["[z]"]
	if (!rows || x < 1 || x > maxx || y < 1 || y > maxy)
		return FALSE
	level = clamp(round(level), 0, 15)
	var/r = maxy - y + 1
	var/row = rows[r]
	rows[r] = copytext(row, 1, x) + ascii2text(level < 10 ? 48 + level : 87 + level) + copytext(row, x + 1)
	var/list/lights = light_rows_by_z["[z]"]
	if (lights)
		// A tile moves the 4 corners around it; each light reads corners one step away.
		for (var/cy in max(0, r - 3) to min(maxy, r + 2))
			var/list/chars = list()
			for (var/cx in max(0, x - 3) to min(maxx, x + 2))
				chars += light_char(rows, cy, cx)
			var/first = max(0, x - 3) + 1
			var/old = lights[cy + 1]
			lights[cy + 1] = copytext(old, 1, first) + jointext(chars, "") + copytext(old, first + chars.len)
	// Line of sight caches terrain answers per eye position (los_terrain.dm).
	los_terrain_heights_changed(locate(x, y, z))
	return TRUE

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

// Built ground (wood, stone, tiles, roads, decks, built walls, tamped earth)
// is laid level: it has no slope cost and no shading. Natural ground keeps the
// hill unless a player-built floor or road cover lies on it.
/turf/proc/terrain_smoothed()
	return terrain_floor_covered()

// Packed paths (tamped earth) keep the hill but are easier to climb.
/turf/proc/terrain_packed()
	return FALSE

// Floor and road covers (not cover walls) are built level over the slope.
/turf/proc/terrain_floor_covered()
	for (var/obj/covers/CV in src)
		if (!CV.wall && !QDELETED(CV))
			return TRUE
	return FALSE

/turf/floor/terrain_smoothed()
	return TRUE

/turf/floor/grass/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/dirt/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/winter/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/beach/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/rocky/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/gravel/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/mining/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/trench/terrain_smoothed()
	return terrain_floor_covered()

/turf/floor/lava/terrain_smoothed()
	return terrain_floor_covered()

/turf/wall/terrain_smoothed()
	return TRUE

/turf/wall/rockwall/terrain_smoothed()
	return terrain_floor_covered()

// Signed level change of one step between two neighbouring turfs, capped at
// TERRAIN_MAX_LEVEL_STEP either way; 0 across built ground or without heights.
/proc/terrain_step_levels(turf/origin, turf/destination)
	if (!origin || !destination || origin.z != destination.z || !map || !map.terrain_height_file)
		return 0
	if (origin.terrain_smoothed() || destination.terrain_smoothed())
		return 0
	return clamp(terrain_height_at(destination) - terrain_height_at(origin), -TERRAIN_MAX_LEVEL_STEP, TERRAIN_MAX_LEVEL_STEP)

// Humans feel a steep step: scrambling up spends stamina (half of it on packed
// ground) and either direction is described in chat, at most once per
// TERRAIN_SLOPE_MESSAGE_DELAY. distance_fraction is the share of a tile moved.
/proc/terrain_climb_effects(mob/living/human/H, turf/origin, turf/destination, distance_fraction = 1)
	var/levels = terrain_step_levels(origin, destination)
	if (abs(levels) < TERRAIN_STEEP_LEVELS)
		return 0
	if (levels > 0 && H.stats["stamina"][1] > 0)
		var/cost = levels * TERRAIN_CLIMB_STAMINA * distance_fraction
		if (destination.terrain_packed())
			cost *= TERRAIN_PACKED_UPHILL_SHARE
		H.stats["stamina"][1] = max(0, H.stats["stamina"][1] - cost)
	if (world.time >= H.next_slope_message)
		H.next_slope_message = world.time + TERRAIN_SLOPE_MESSAGE_DELAY
		if (levels > 0)
			to_chat(H, SPAN_NOTICE("You scramble up the steep slope."))
		else
			to_chat(H, SPAN_NOTICE("You pick your way down the steep slope."))
	return levels

// Extra move delay (negative when it saves time) for one step between two
// neighbouring turfs, given the step's delay before this term.
/proc/terrain_slope_delay(turf/origin, turf/destination, step_delay)
	var/levels = terrain_step_levels(origin, destination)
	if (levels > 0)
		return levels * TERRAIN_UPHILL_DELAY * (destination.terrain_packed() ? TERRAIN_PACKED_UPHILL_SHARE : 1)
	if (levels < 0)
		return -min(-levels * TERRAIN_DOWNHILL_BONUS, max(0, step_delay) * TERRAIN_DOWNHILL_MAX_SHARE)
	return 0

// Slope shading (scripts/terrain_heights.py bake-shading makes the sprites).
// Each tile corner gets a light level from -2 (shadow) to 2 (lit), from the
// heights around it, lit from the north-west. A tile shows the sprite for its
// four corner levels, blended across the tile, so neighbours join smoothly.
// Sprites are shared objects in turf vis_contents: drawn just above the ground
// and below decals and objects, never clickable, never saved.
#define TERRAIN_LIGHT_STEP 0.22
#define TERRAIN_RELIEF 1.6
#define TERRAIN_SHADE_LAYER 2.005

var/global/list/terrain_shade_objects = list()
// TRUE once the map's shading has been placed this round.
var/global/terrain_shading_applied = FALSE

/obj/effect/terrain_shade
	icon = 'icons/turf/terrain_shade.dmi'
	layer = TERRAIN_SHADE_LAYER
	mouse_opacity = 0
	anchored = TRUE
	vis_flags = VIS_INHERIT_PLANE
	should_save = FALSE

/proc/terrain_shade_object(key)
	var/obj/effect/terrain_shade/S = terrain_shade_objects[key]
	if (!S)
		S = new
		S.icon_state = key
		terrain_shade_objects[key] = S
	return S

// "z" -> list of (maxy + 1) strings of (maxx + 1) light chars a-e, north first.
/datum/terrain_heights/var/list/light_rows_by_z = list()

// Level at a north-first row and column, clamped to the edge like the tool.
/datum/terrain_heights/proc/level_rc(list/rows, row, col)
	var/code = text2ascii(rows[clamp(row, 1, maxy)], clamp(col, 1, maxx))
	return code >= 97 ? code - 87 : code - 48

/datum/terrain_heights/proc/light_rows(z)
	var/key = "[z]"
	if (light_rows_by_z[key])
		return light_rows_by_z[key]
	var/list/rows = rows_by_z[key]
	if (!rows)
		return null
	var/width = maxx + 1
	// Corner heights: corner (cx, cy), 0-based, north first, between rows cy/cy+1 and columns cx/cx+1.
	var/list/corner = new /list(width * (maxy + 1))
	for (var/cy in 0 to maxy)
		for (var/cx in 0 to maxx)
			corner[cy * width + cx + 1] = (level_rc(rows, cy, cx) + level_rc(rows, cy + 1, cx) + level_rc(rows, cy, cx + 1) + level_rc(rows, cy + 1, cx + 1)) / 4
	var/static/light_x = -1 / sqrt(3.44)
	var/static/light_y = -1 / sqrt(3.44)
	var/static/light_z = 1.2 / sqrt(3.44)
	var/list/out = list()
	for (var/cy in 0 to maxy)
		var/list/chars = list()
		for (var/cx in 0 to maxx)
			var/gx = (corner[cy * width + min(cx + 1, maxx) + 1] - corner[cy * width + max(cx - 1, 0) + 1]) / 2
			var/gy = (corner[min(cy + 1, maxy) * width + cx + 1] - corner[max(cy - 1, 0) * width + cx + 1]) / 2
			var/nx = -gx * TERRAIN_RELIEF
			var/ny = -gy * TERRAIN_RELIEF
			var/intensity = (nx * light_x + ny * light_y + light_z) / sqrt(nx * nx + ny * ny + 1) - light_z
			chars += ascii2text(99 + clamp(floor(intensity / TERRAIN_LIGHT_STEP + 0.5), -2, 2))
		out += jointext(chars, "")
		CHECK_TICK
	light_rows_by_z[key] = out
	return out

// One corner light, computed alone; matches light_rows() exactly.
/datum/terrain_heights/proc/corner_level(list/rows, cy, cx)
	cy = clamp(cy, 0, maxy)
	cx = clamp(cx, 0, maxx)
	return (level_rc(rows, cy, cx) + level_rc(rows, cy + 1, cx) + level_rc(rows, cy, cx + 1) + level_rc(rows, cy + 1, cx + 1)) / 4

/datum/terrain_heights/proc/light_char(list/rows, cy, cx)
	var/static/light_x = -1 / sqrt(3.44)
	var/static/light_y = -1 / sqrt(3.44)
	var/static/light_z = 1.2 / sqrt(3.44)
	var/gx = (corner_level(rows, cy, min(cx + 1, maxx)) - corner_level(rows, cy, max(cx - 1, 0))) / 2
	var/gy = (corner_level(rows, min(cy + 1, maxy), cx) - corner_level(rows, max(cy - 1, 0), cx)) / 2
	var/nx = -gx * TERRAIN_RELIEF
	var/ny = -gy * TERRAIN_RELIEF
	var/intensity = (nx * light_x + ny * light_y + light_z) / sqrt(nx * nx + ny * ny + 1) - light_z
	return ascii2text(99 + clamp(floor(intensity / TERRAIN_LIGHT_STEP + 0.5), -2, 2))

// Sprite key for a tile: corner lights nw, ne, sw, se; "cccc" means flat.
/datum/terrain_heights/proc/shade_key(x, y, z)
	var/list/lights = light_rows(z)
	if (!lights || x < 1 || x > maxx || y < 1 || y > maxy)
		return null
	var/row = maxy - y + 1
	return copytext(lights[row], x, x + 2) + copytext(lights[row + 1], x, x + 2)

/turf/proc/terrain_shade_refresh()
	for (var/obj/effect/terrain_shade/old in vis_contents)
		vis_contents -= old
	if (!map || !map.terrain_height_file || istype(src, /turf/floor/beach/water) || terrain_smoothed())
		return
	var/datum/terrain_heights/H = map.terrain_heights()
	var/key = H ? H.shade_key(x, y, z) : null
	if (key && key != "cccc")
		vis_contents += terrain_shade_object(key)

// A floor cover laid or removed after the shading was placed changes whether
// its tile is shaded. Covers call updateturf() shortly after they are placed.
/obj/covers/updateturf()
	. = ..()
	var/turf/T = get_turf(src)
	if (T && !wall && terrain_shading_applied)
		T.terrain_shade_refresh()

/obj/covers/Destroy()
	var/turf/T = get_turf(src)
	var/floor_cover = !wall
	. = ..()
	if (T && floor_cover && terrain_shading_applied)
		T.terrain_shade_refresh()

/proc/terrain_shading_apply()
	var/datum/terrain_heights/H = map ? map.terrain_heights() : null
	if (!H)
		return 0
	var/count = 0
	for (var/zkey in H.rows_by_z)
		var/z = text2num(zkey)
		H.light_rows(z)
		for (var/y in 1 to H.maxy)
			for (var/x in 1 to H.maxx)
				var/turf/T = locate(x, y, z)
				if (!T || istype(T, /turf/floor/beach/water) || T.terrain_smoothed())
					continue
				var/key = H.shade_key(x, y, z)
				if (key != "cccc")
					T.vis_contents += terrain_shade_object(key)
					count++
			CHECK_TICK
	return count

// Called by the ticker every 2 seconds; places the shading once per round.
/proc/terrain_shading_check()
	if (terrain_shading_applied || !map || !map.terrain_height_file)
		return
	terrain_shading_applied = TRUE
	terrain_shading_place()

// Runs on its own so the ticker is not held while tiles are shaded.
/proc/terrain_shading_place()
	set waitfor = FALSE
	var/started = REALTIMEOFDAY
	var/count = terrain_shading_apply()
	log_game("Terrain shading placed on [count] tiles of [map ? map.title : "no map"] in [(REALTIMEOFDAY - started) / 10] s.")

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
#undef TERRAIN_PACKED_UPHILL_SHARE
#undef TERRAIN_LIGHT_STEP
#undef TERRAIN_RELIEF
#undef TERRAIN_SHADE_LAYER
