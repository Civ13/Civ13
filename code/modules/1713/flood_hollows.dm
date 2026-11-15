// Rain pooling in hollows (docs/river-flood.md, "Hollows"). A hollow is a
// closed basin on land, listed in the flood file with its spill level, its
// tiles' heights and its catchment. Once a minute rain over the catchment
// fills it and the ground soaks the water away; the water stands level across
// the hollow and never rises past the spill. Depth on a tile is worked out
// when asked, like river floodwater.

// Water (tile-levels) per catchment tile per point of rain intensity each minute.
#define HOLLOW_RAIN_YIELD 0.003
// Only this many tiles of catchment per tile of hollow count: most rain on a
// wide upland soaks in before it reaches the bottom.
#define HOLLOW_CATCHMENT_CAP 8
// Share of a hollow's water that soaks in or dries each minute; dry seasons
// and heat dry it twice as fast.
#define HOLLOW_SOAK 0.005

/datum/river_flood
	var/hollow_count = 0
	var/list/hollow_spill = list()
	var/list/hollow_bottom = list()
	var/list/hollow_cx = list()
	var/list/hollow_cy = list()
	var/list/hollow_area = list()
	var/list/hollow_catchment = list()
	// Per hollow, tile counts per half level from the bottom up.
	var/list/hollow_hist = list()
	// North-first rows of hollow ids, null for rows without any.
	var/list/hollow_rows = null
	// Saved: water held, in tile-levels. Derived: the water's level.
	var/list/hollow_volume = list()
	var/list/hollow_level = list()

/datum/river_flood/proc/hollow_at(x, y)
	if (!hollow_rows)
		return 0
	var/row = hollow_rows[maxy - y + 1]
	if (!row)
		return 0
	var/p = x * 2 - 1
	return river_flood_id_values[text2ascii(row, p)] * 64 + river_flood_id_values[text2ascii(row, p + 1)]

/datum/river_flood/proc/hollow_depth_at(turf/T)
	var/h = hollow_at(T.x, T.y)
	if (!h)
		return 0
	var/level = hollow_level[h]
	if (level <= hollow_bottom[h])
		return 0
	return max(0, level - terrain_height_at(T))

// Water a hollow holds when full to its spill.
/datum/river_flood/proc/hollow_capacity(h)
	. = 0
	var/list/hist = hollow_hist[h]
	var/spill = hollow_spill[h]
	var/bottom = hollow_bottom[h]
	for (var/k in 1 to hist.len)
		. += hist[k] * (spill - (bottom + (k - 1) / 2))

// The level water stands at in hollow h holding volume.
/datum/river_flood/proc/hollow_level_for(h, volume)
	var/list/hist = hollow_hist[h]
	var/level = hollow_bottom[h]
	var/wet = 0
	for (var/k in 1 to hist.len)
		wet += hist[k]
		var/step = wet * 0.5
		if (volume <= step)
			return wet ? level + volume / wet : level
		volume -= step
		level += 0.5
	return hollow_spill[h]

/datum/river_flood/proc/hollows_hold_water()
	for (var/i in 1 to hollow_count)
		if (hollow_volume[i] > 0.01)
			return TRUE
	return FALSE

/datum/river_flood/proc/restore_hollows(list/state)
	for (var/i in 1 to hollow_count)
		hollow_volume[i] = 0
		hollow_level[i] = hollow_bottom[i]
	if (!islist(state) || state.len != hollow_count + 1 || state[1] != hollow_count)
		return FALSE
	for (var/i in 1 to hollow_count)
		var/v = state[i + 1]
		if (!isnum(v) || v < 0)
			continue
		hollow_volume[i] = min(v, hollow_capacity(i))
		hollow_level[i] = hollow_level_for(i, hollow_volume[i])
	return TRUE

// One minute of rain and soaking for every hollow.
/datum/river_flood/proc/step_hollows()
	if (!hollow_count)
		// Pumping stations still burn fuel (sewers.dm).
		drain_hollows()
		return
	var/dry = river_flood_season_factor() < 1
	var/raining = weather_anywhere()
	for (var/i in 1 to hollow_count)
		var/volume = hollow_volume[i]
		var/turf/centre = locate(hollow_cx[i], hollow_cy[i], z_level)
		var/soak = HOLLOW_SOAK
		if (dry || (centre && weather_heat_at(centre)))
			soak *= 2
		volume -= volume * soak
		if (raining && centre)
			var/intensity = weather_intensity_at(centre)
			if (intensity)
				var/look = weather_look_at(centre)
				if (findtext(look, "rain") || look == "monsoon")
					volume += min(hollow_catchment[i], hollow_area[i] * HOLLOW_CATCHMENT_CAP) * HOLLOW_RAIN_YIELD * intensity
		volume = clamp(volume, 0, hollow_capacity(i))
		if (volume < 0.01)
			volume = 0
		hollow_volume[i] = volume
		hollow_level[i] = hollow_level_for(i, volume)
	// Drains in hollows and pumping stations (sewers.dm).
	drain_hollows()

#undef HOLLOW_RAIN_YIELD
#undef HOLLOW_CATCHMENT_CAP
#undef HOLLOW_SOAK
