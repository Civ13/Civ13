// River stages and flood depth (docs/river-flood.md). A map with heights may
// have a flood sidecar (maps/heights/<map>.flood.txt, made by
// scripts/river_flood.py): fresh water cut into reaches, which reach every land
// tile floods from, and the stage that reaches it. Once a minute each reach
// gathers the rain and snowmelt over its catchment and passes water on to the
// reach it drains to; its stage, in levels above normal, follows the flow.
// Nothing here loops over tiles: a tile's depth is worked out when asked.

// Share of a reach's stored water that leaves for the next reach each minute.
#define RIVER_FLOOD_RELEASE 0.35
// Water per catchment tile each minute: springs and groundwater, and per point
// of rain intensity.
#define RIVER_FLOOD_BASEFLOW 0.02
#define RIVER_FLOOD_RAIN_YIELD 0.05
// Flow per catchment tile in an ordinary year; a reach at this flow is at stage 0.
#define RIVER_FLOOD_MEAN_FLOW 0.04
// Snow held per catchment tile per point of snowfall intensity each minute, and
// the share of the snowpack that melts each minute out of winter.
#define RIVER_FLOOD_SNOW_YIELD 0.05
#define RIVER_FLOOD_MELT_SPRING 0.06
#define RIVER_FLOOD_MELT_SUMMER 0.12
// Levels of stage per doubling of the flow, for the largest rivers; small
// catchments rise less (river_flood_amplitude).
#define RIVER_FLOOD_STAGE_PER_DOUBLING 1.2
#define RIVER_FLOOD_STAGE_MIN -1.5
// Above this the plains drown; no river rises past it.
#define RIVER_FLOOD_STAGE_CAP 3
// Levels a reach's high-water mark fades each minute, so flood marks show the
// last few years' floods rather than the highest ever.
#define RIVER_FLOOD_MARK_FADE 0.005
// Deciseconds between river ticks.
#define RIVER_FLOOD_TICK 600

#define RIVER_FLOOD_ID_DIGITS "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ-_"

/obj/map_metadata
	var/tmp/datum/river_flood/river_flood_cache = null
	var/tmp/river_flood_loaded = FALSE
	// Saved water in each reach: list(reach count, storage..., snowpack..., high-water mark...).
	var/list/river_flood_state = list()

var/global/list/river_flood_id_values = river_flood_id_table()
var/global/next_river_flood_tick = 0

/proc/river_flood_id_table()
	var/list/table = new /list(127)
	for (var/i in 1 to 64)
		table[text2ascii(RIVER_FLOOD_ID_DIGITS, i)] = i - 1
	return table

/datum/river_flood
	should_save = FALSE
	var/z_level = 0
	var/maxx = 0
	var/maxy = 0
	var/count = 0
	// Per reach, by id: the reach it drains to (0 none), catchment centre,
	// catchment tiles, tiles upstream including its own, water tiles.
	var/list/down = list()
	var/list/cx = list()
	var/list/cy = list()
	var/list/area = list()
	var/list/upstream = list()
	var/list/water = list()
	// North-first rows: two characters of reach id per tile, then one
	// threshold character (height alphabet, "." none).
	var/list/label_rows = list()
	var/list/threshold_rows = list()
	// Runtime water, by id.
	var/list/storage = list()
	var/list/snow = list()
	var/list/flow = list()
	var/list/stage = list()
	// Highest recent stage, fading slowly: the flood marks on the banks.
	var/list/peak = list()
	// The state list last written to the map; anything else there was loaded from a save.
	var/list/published = null
	// TRUE while some reach is above stage 0, so some bank may be under water.
	var/flooding = FALSE
	var/error = null

/proc/river_flood_parse(text, world_maxx, world_maxy, world_maxz)
	var/datum/river_flood/F = new
	if (!istext(text) || !length(text))
		F.error = "empty flood file"
		return F
	var/list/lines = splittext(replacetext(text, ascii2text(13), ""), "\n")
	if (lines.len < 4 || lines[1] != "civ13-river-flood 1")
		F.error = "missing 'civ13-river-flood 1' header"
		return F
	if (lines[2] != "size [world_maxx] [world_maxy]")
		F.error = "size line '[lines[2]]' does not match the world"
		return F
	F.maxx = world_maxx
	F.maxy = world_maxy
	var/list/zline = splittext(lines[3], " ")
	var/list/rline = splittext(lines[4], " ")
	F.z_level = zline.len == 2 && zline[1] == "z" ? text2num(zline[2]) : null
	F.count = rline.len == 2 && rline[1] == "reaches" ? text2num(rline[2]) : null
	if (!isnum(F.z_level) || F.z_level < 1 || F.z_level > world_maxz || !isnum(F.count) || F.count < 0 || F.count > 4095)
		F.error = "bad z or reaches line"
		return F
	if (lines.len < 4 + F.count + world_maxy * 2)
		F.error = "file is cut short"
		return F
	for (var/i in 1 to F.count)
		var/list/parts = splittext(lines[4 + i], " ")
		if (parts.len != 8 || parts[1] != "r" || text2num(parts[2]) != i)
			F.error = "bad reach line [i]"
			return F
		var/d = text2num(parts[3])
		if (!isnum(d) || d < 0 || d > F.count || (d && d <= i))
			F.error = "reach [i] drains to [parts[3]]"
			return F
		F.down += d
		F.cx += text2num(parts[4])
		F.cy += text2num(parts[5])
		F.area += max(1, text2num(parts[6]))
		F.upstream += max(1, text2num(parts[7]))
		F.water += text2num(parts[8])
	var/static/regex/bad_label = regex(@"[^0-9a-zA-Z_\-]")
	var/static/regex/bad_threshold = regex(@"[^0-9a-vA-Z!#$%&+.]")
	var/start = 5 + F.count
	for (var/r in 0 to world_maxy - 1)
		var/row = lines[start + r]
		if (length(row) != world_maxx * 2 || bad_label.Find(row))
			F.error = "label row [r + 1] is malformed"
			return F
		F.label_rows += row
	start += world_maxy
	for (var/r in 0 to world_maxy - 1)
		var/row = lines[start + r]
		if (length(row) != world_maxx || bad_threshold.Find(row))
			F.error = "threshold row [r + 1] is malformed"
			return F
		F.threshold_rows += row
	F.storage = new /list(F.count)
	F.snow = new /list(F.count)
	F.flow = new /list(F.count)
	F.stage = new /list(F.count)
	F.peak = new /list(F.count)
	for (var/i in 1 to F.count)
		F.settle(i)
	return F

/obj/map_metadata/persistence_runtime_var(var/key)
	if (key == "river_flood_cache" || key == "river_flood_loaded")
		return TRUE
	return ..(key)

/obj/map_metadata/proc/river_flood()
	if (river_flood_loaded)
		return river_flood_cache
	river_flood_loaded = TRUE
	if (!terrain_height_file)
		return null
	var/path = replacetext(terrain_height_file, ".txt", ".flood.txt")
	if (!fexists(path))
		return null
	var/datum/river_flood/F = river_flood_parse(file2text(path), world.maxx, world.maxy, world.maxz)
	if (F.error)
		log_debug("River flood [path] ignored: [F.error]")
		return null
	F.restore(river_flood_state)
	F.published = river_flood_state
	river_flood_cache = F
	return F

// A reach at the steady flow of an ordinary dry spell.
/datum/river_flood/proc/settle(i)
	flow[i] = upstream[i] * RIVER_FLOOD_BASEFLOW
	storage[i] = flow[i] / RIVER_FLOOD_RELEASE
	snow[i] = 0
	stage[i] = stage_for(i, flow[i])
	peak[i] = stage[i]

// Older saves hold no high-water marks; the marks then start at the water.
/datum/river_flood/proc/restore(list/state)
	if (!islist(state) || (state.len != count * 2 + 1 && state.len != count * 3 + 1) || state[1] != count)
		return FALSE
	var/marks = state.len == count * 3 + 1
	for (var/i in 1 to count)
		var/s = state[i + 1]
		var/w = state[count + i + 1]
		if (!isnum(s) || !isnum(w) || s < 0 || w < 0)
			return FALSE
		if (marks && !isnum(state[count * 2 + i + 1]))
			return FALSE
	for (var/i in 1 to count)
		storage[i] = state[i + 1]
		snow[i] = state[count + i + 1]
		flow[i] = storage[i] * RIVER_FLOOD_RELEASE
		stage[i] = stage_for(i, flow[i])
		peak[i] = marks ? clamp(state[count * 2 + i + 1], RIVER_FLOOD_STAGE_MIN, RIVER_FLOOD_STAGE_CAP) : stage[i]
	stages_changed()
	return TRUE

// After any change to the stages: whether anything floods, and a redraw.
/datum/river_flood/proc/stages_changed()
	flooding = FALSE
	for (var/i in 1 to count)
		if (stage[i] > 0)
			flooding = TRUE
			break
	flood_draw_revision++

// Saves the water on the map, where the durable world save picks it up.
/datum/river_flood/proc/publish()
	published = snapshot()
	map.river_flood_state = published

/datum/river_flood/proc/snapshot()
	. = list(count)
	for (var/i in 1 to count)
		. += round(storage[i], 0.001)
	for (var/i in 1 to count)
		. += round(snow[i], 0.001)
	for (var/i in 1 to count)
		. += round(peak[i], 0.001)

// Big rivers rise furthest: a stream draining a few hundred tiles moves about
// half as much for the same rain.
/datum/river_flood/proc/amplitude(i)
	return clamp(log(10, upstream[i]) / 4, 0.25, 1)

/datum/river_flood/proc/stage_for(i, current)
	var/ratio = max(current, 0.000001) / (upstream[i] * RIVER_FLOOD_MEAN_FLOW)
	return clamp(RIVER_FLOOD_STAGE_PER_DOUBLING * amplitude(i) * log(2, ratio), RIVER_FLOOD_STAGE_MIN, RIVER_FLOOD_STAGE_CAP)

// Springs run high after the thaw and low at the end of summer; a heat system
// overhead dries a catchment further.
/proc/river_flood_season_factor()
	if (findtext(season, "Wet"))
		return 1.3
	if (findtext(season, "Dry"))
		return 0.6
	switch (season)
		if ("SPRING")
			return 1.2
		if ("SUMMER")
			return 0.6
		if ("WINTER")
			return 0.8
	return 1

/proc/river_flood_melt_rate()
	if (season_is_wet())
		return RIVER_FLOOD_MELT_SPRING
	if (season == SEASON_WINTER)
		return 0
	return RIVER_FLOOD_MELT_SUMMER

// One minute of water. Reaches come upstream first, so what a reach releases
// reaches the next one in the same pass.
/datum/river_flood/proc/step_minute()
	var/base_factor = river_flood_season_factor()
	var/melt_rate = river_flood_melt_rate()
	var/list/incoming = new /list(count)
	for (var/i in 1 to count)
		var/local = area[i]
		var/gain = local * RIVER_FLOOD_BASEFLOW * base_factor
		var/turf/centre = locate(cx[i], cy[i], z_level)
		if (centre && weather_anywhere())
			var/look = weather_look_at(centre)
			var/intensity = weather_intensity_at(centre)
			if (intensity && findtext(look, "snow"))
				snow[i] += local * RIVER_FLOOD_SNOW_YIELD * intensity
			else if (intensity && (findtext(look, "rain") || look == "monsoon"))
				gain += local * RIVER_FLOOD_RAIN_YIELD * intensity
		if (centre && weather_heat_at(centre))
			gain *= 0.5
		if (melt_rate && snow[i] > 0)
			var/melt = snow[i] * melt_rate
			snow[i] -= melt
			gain += melt
		storage[i] += gain + (incoming[i] || 0)
		var/released = storage[i] * RIVER_FLOOD_RELEASE
		storage[i] -= released
		flow[i] = released
		stage[i] = stage_for(i, released)
		peak[i] = max(stage[i], peak[i] - RIVER_FLOOD_MARK_FADE)
		if (down[i])
			incoming[down[i]] = (incoming[down[i]] || 0) + released
	stages_changed()

// Reach id of a tile (0 none) and the stage that floods it (null for none).
/datum/river_flood/proc/reach_at(x, y)
	var/row = label_rows[maxy - y + 1]
	var/p = x * 2 - 1
	return river_flood_id_values[text2ascii(row, p)] * 64 + river_flood_id_values[text2ascii(row, p + 1)]

/datum/river_flood/proc/threshold_at(x, y)
	return terrain_height_levels[text2ascii(threshold_rows[maxy - y + 1], x)]

/proc/river_flood_step()
	if (!map || world.time < next_river_flood_tick)
		return
	next_river_flood_tick = world.time + RIVER_FLOOD_TICK
	var/datum/river_flood/F = map.river_flood()
	if (!F)
		return
	// A save loaded since the last tick brings its own water.
	if (map.river_flood_state != F.published)
		F.restore(map.river_flood_state)
	// Grading and walls built since the last tick (flood_ground.dm).
	F.process_windows()
	F.step_minute()
	F.publish()

// Stage of the reach a tile belongs to, in levels above normal (0 without a sidecar).
/proc/river_stage_at(turf/T)
	if (!T || !map)
		return 0
	var/datum/river_flood/F = map.river_flood()
	if (!F || T.z != F.z_level || T.x < 1 || T.x > F.maxx || T.y < 1 || T.y > F.maxy)
		return 0
	var/r = F.reach_at(T.x, T.y)
	return r ? F.stage[r] : 0

// Depth of river floodwater on a land tile, in levels (0 when dry).
/proc/flood_depth_at(turf/T)
	if (!T || !map)
		return 0
	var/datum/river_flood/F = map.river_flood()
	if (!F || T.z != F.z_level || T.x < 1 || T.x > F.maxx || T.y < 1 || T.y > F.maxy)
		return 0
	var/r = F.reach_at(T.x, T.y)
	if (!r || F.stage[r] <= 0)
		return 0
	var/threshold = F.effective_threshold(T)
	if (isnull(threshold))
		return 0
	return max(0, F.stage[r] - flood_ground_level(T, threshold))

// The stage at which floodwater stands on a tile: its threshold, or higher
// where a player has raised the ground.
/proc/flood_ground_level(turf/T, threshold)
	var/own = terrain_height_at(T)
	return own > threshold ? own : threshold

// How high the last floods stood on a land tile, in levels (0 for none).
/proc/flood_mark_at(turf/T)
	if (!T || !map)
		return 0
	var/datum/river_flood/F = map.river_flood()
	if (!F || T.z != F.z_level || T.x < 1 || T.x > F.maxx || T.y < 1 || T.y > F.maxy)
		return 0
	var/r = F.reach_at(T.x, T.y)
	if (!r || F.peak[r] <= 0)
		return 0
	var/threshold = F.effective_threshold(T)
	if (isnull(threshold))
		return 0
	return max(0, F.peak[r] - flood_ground_level(T, threshold))
