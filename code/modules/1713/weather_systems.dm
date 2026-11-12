// ============================================================
// Moving weather systems (docs/weather-systems.md)
// ------------------------------------------------------------
// Random weather is no longer one value for the whole map. A weather system
// is an oval of cloud that forms upwind, crosses the map with the wind and
// dies out. The weather on a tile is what the systems over it make of the
// local climate and season (climate_weather_state), laid over whatever zone
// weather a map script or an admin has pinned with change_weather().
//
// A system is a few numbers. Its place is worked out from the time when it is
// asked for, so nothing loops over tiles and nothing moves on the map. The
// rain itself is drawn by weather_chunks.dm for the players near it.
// Systems are never saved: a restart begins with a clear sky.
// ============================================================

var/global/list/weather_systems = list()
var/global/weather_system_serial = 0
// Storms only, so the per-tile question skips heat when the sky is clear.
var/global/weather_storm_count = 0

/datum/weather_system
	should_save = FALSE
	var/id = 0
	var/kind = WEATHER_SYSTEM_STORM
	var/severe = FALSE // its core is extreme weather: blizzard, monsoon, sandstorm
	var/origin_x = 0
	var/origin_y = 0
	var/origin_time = 0
	var/vel_x = 0 // tiles a decisecond
	var/vel_y = 0
	var/radius_x = 40
	var/radius_y = 40
	var/peak = 1
	var/born = 0
	var/lifetime = 18000
	var/wobble = 0
	var/list/warned = list() // ckeys told it is coming
	var/list/inside = list() // ckeys under a heat system

/datum/weather_system/proc/centre_x()
	return origin_x + vel_x * (world.time - origin_time)

/datum/weather_system/proc/centre_y()
	return origin_y + vel_y * (world.time - origin_time)

// Grows for its first minute and fades over its last two.
/datum/weather_system/proc/power()
	var/age = world.time - born
	if (age < 0 || age >= lifetime)
		return 0
	return peak * min(1, age / 600, (lifetime - age) / 1200)

// 0 outside the oval, rising to the system's power over its outer 40%.
/datum/weather_system/proc/strength_at(x, y)
	var/dx = (x - centre_x()) / radius_x
	if (dx >= 1.1 || dx <= -1.1)
		return 0
	var/dy = (y - centre_y()) / radius_y
	var/reach = dx * dx + dy * dy
	if (reach >= 1.21)
		return 0
	// A ragged edge, fixed to the system so it travels with it.
	var/d = sqrt(reach) + 0.08 * sin((x - centre_x()) * 9 + (y - centre_y()) * 5 + wobble)
	if (d >= 1)
		return 0
	return power() * min(1, (1 - d) * 2.5)

// Point the system along a new course without moving it.
/datum/weather_system/proc/set_course(new_vel_x, new_vel_y)
	origin_x = centre_x()
	origin_y = centre_y()
	origin_time = world.time
	vel_x = new_vel_x
	vel_y = new_vel_y
	weather_sample_time = -1

// TRUE once it has faded or left the map for good.
/datum/weather_system/proc/spent()
	if (world.time - born >= lifetime)
		return TRUE
	var/x = centre_x()
	var/y = centre_y()
	if ((x < -radius_x && vel_x <= 0) || (x > world.maxx + radius_x && vel_x >= 0))
		return TRUE
	if ((y < -radius_y && vel_y <= 0) || (y > world.maxy + radius_y && vel_y >= 0))
		return TRUE
	return FALSE

/proc/weather_system_end(datum/weather_system/S)
	if (!S || !(S in weather_systems))
		return
	weather_systems -= S
	weather_sample_time = -1
	if (S.kind == WEATHER_SYSTEM_STORM)
		weather_storm_count = max(0, weather_storm_count - 1)
	qdel(S)

// Break up the weather over a place: storms there fade within two minutes,
// and pinned zone weather lifts.
/proc/weather_disperse(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return
	for (var/datum/weather_system/S in weather_systems)
		if (S.kind == WEATHER_SYSTEM_STORM && S.strength_at(T.x, T.y) > 0)
			S.lifetime = min(S.lifetime, (world.time - S.born) + 1200)
	weather_sample_time = -1
	if (weather == WEATHER_WET || weather == WEATHER_EXTREME)
		change_weather(WEATHER_NONE)

/proc/weather_systems_clear()
	for (var/datum/weather_system/S in weather_systems.Copy())
		weather_system_end(S)

// ---- wind ---------------------------------------------------

// The way the wind carries things, as a unit step. winddirection names where
// the wind blows from (a ship sailing north into a "North" wind is slowest).
/proc/weather_wind_vector()
	switch (map ? map.winddirection : "West")
		if ("North")
			return list(0, -1)
		if ("South")
			return list(0, 1)
		if ("East")
			return list(-1, 0)
	return list(1, 0)

// Tiles a decisecond: a tile every 8 seconds in a calm, every 2.5 in a gale.
/proc/weather_wind_speed()
	return 0.0125 + 0.007 * (map ? map.windspeedvar : 1)

// The next wind direction: it holds or veers a quarter turn, never reverses.
/proc/weather_veer(direction)
	var/static/list/compass = list("North", "East", "South", "West")
	var/at = compass.Find(direction)
	if (!at)
		return pick(compass)
	var/turn = pick(0, 0, 1, -1)
	at += turn
	if (at < 1)
		at = compass.len
	else if (at > compass.len)
		at = 1
	return compass[at]

// Wind strength 0 to 4 at a tile: the map's wind, and a gale under a storm.
/proc/weather_wind_at(atom/A)
	. = map ? map.windspeedvar : 1
	var/turf/T = get_turf(A)
	if (!T || !weather_storm_count)
		return
	var/strength = weather_storm_strength(T.x, T.y)
	if (strength >= WEATHER_BAND_HEAVY)
		. = max(., weather_storm_severe ? 4 : 3)
	else if (strength >= WEATHER_BAND_STEADY)
		. = max(., 2)

// ---- making systems ----------------------------------------

// A new system upwind of the map, set to pass over (aim_x, aim_y), or over a
// random spot when none is given. arrive_in (deciseconds) puts its edge that
// far from the aim, for a storm that is called down rather than rolled.
/proc/weather_system_spawn(kind = WEATHER_SYSTEM_STORM, severe = FALSE, aim_x, aim_y, arrive_in)
	if (weather_systems.len >= WEATHER_SYSTEM_MAX)
		return null
	var/datum/weather_system/S = new
	S.id = ++weather_system_serial
	S.kind = kind
	S.severe = severe
	var/size = rand(35, 90)
	if (kind == WEATHER_SYSTEM_HEAT)
		size = rand(70, 120)
	S.radius_x = size * (rand(70, 100) / 100)
	S.radius_y = size * (rand(70, 100) / 100)
	S.peak = severe ? 1 : rand(55, 100) / 100
	S.wobble = rand(0, 359)
	S.born = world.time
	S.lifetime = rand(9000, 24000) // 15 to 40 minutes
	if (isnull(aim_x))
		aim_x = rand(round(world.maxx * 0.1), max(1, round(world.maxx * 0.9)))
	if (isnull(aim_y))
		aim_y = rand(round(world.maxy * 0.1), max(1, round(world.maxy * 0.9)))
	var/list/wind = weather_wind_vector()
	var/speed = weather_wind_speed()
	S.vel_x = wind[1] * speed
	S.vel_y = wind[2] * speed
	// Back along the wind from the aim until the whole oval is off the map.
	var/back = 0
	if (!isnull(arrive_in))
		back = max(S.radius_x, S.radius_y) + arrive_in * speed
	else if (wind[1] > 0)
		back = aim_x + S.radius_x
	else if (wind[1] < 0)
		back = world.maxx - aim_x + S.radius_x
	else if (wind[2] > 0)
		back = aim_y + S.radius_y
	else
		back = world.maxy - aim_y + S.radius_y
	S.origin_x = aim_x - wind[1] * back
	S.origin_y = aim_y - wind[2] * back
	S.origin_time = world.time
	// Long enough to reach the aim and pass over it.
	S.lifetime = max(S.lifetime, round((back + max(S.radius_x, S.radius_y)) / speed) + 1200)
	weather_systems += S
	weather_sample_time = -1
	if (kind == WEATHER_SYSTEM_STORM)
		weather_storm_count++
	return S

// How many systems the map holds at once, and how much more often the sky is
// rolled than on a small map: one storm covers a battle map, not a region.
/proc/weather_system_capacity()
	return clamp(round((world.maxx * world.maxy) / 40000), 1, WEATHER_SYSTEM_MAX)

// One roll of the season's weather pool. A wet or extreme result sends a
// storm across the map; a clear result lifts any zone weather still pinned.
/proc/weather_roll(result)
	if (isnull(result))
		return
	if (result == WEATHER_NONE || result == WEATHER_SMOG)
		if (weather != WEATHER_NONE && result == WEATHER_NONE)
			change_weather(WEATHER_NONE)
		return
	if (map && !(result in map.valid_weather_types))
		return
	var/storms = 0
	for (var/datum/weather_system/S in weather_systems)
		if (S.kind == WEATHER_SYSTEM_STORM)
			storms++
	if (storms >= weather_system_capacity())
		return
	weather_system_spawn(WEATHER_SYSTEM_STORM, result == WEATHER_EXTREME)

// ---- the weather on a tile ---------------------------------

var/global/weather_storm_severe = FALSE

// The strongest storm over a place, 0 to 1. Sets weather_storm_severe.
/proc/weather_storm_strength(x, y)
	. = 0
	weather_storm_severe = FALSE
	for (var/datum/weather_system/S in weather_systems)
		if (S.kind != WEATHER_SYSTEM_STORM)
			continue
		var/strength = S.strength_at(x, y)
		if (strength > .)
			. = strength
			weather_storm_severe = S.severe
		else if (strength && strength == . && S.severe)
			weather_storm_severe = TRUE

// TRUE under a mass of hot dry air: more thirst, thirstier crops, no dew.
/proc/weather_heat_at(atom/A)
	if (weather_systems.len == weather_storm_count)
		return FALSE
	var/turf/T = get_turf(A)
	if (!T)
		return FALSE
	for (var/datum/weather_system/S in weather_systems)
		if (S.kind == WEATHER_SYSTEM_HEAT && S.strength_at(T.x, T.y) >= WEATHER_BAND_LIGHT)
			return TRUE
	return FALSE

var/global/list/weather_state_cache = list()

/proc/weather_state_cached(climate, class, strength)
	var/key = "[season]|[climate]|[class]|[strength]"
	var/list/state = weather_state_cache[key]
	if (!state)
		state = climate_weather_state(climate, class, strength)
		weather_state_cache[key] = state
	return state

// What a storm of this strength is over this climate: list(look, class,
// intensity), or null where it is only cloud.
/proc/weather_storm_state(climate, strength, severe)
	if (strength < WEATHER_BAND_LIGHT)
		return null
	var/list/state
	if (strength >= WEATHER_BAND_HEAVY)
		state = weather_state_cached(climate, severe ? WEATHER_EXTREME : WEATHER_WET, 3)
	else if (strength >= WEATHER_BAND_STEADY)
		state = weather_state_cached(climate, WEATHER_WET, 2)
	else
		state = weather_state_cached(climate, WEATHER_WET, 1)
	if (state[2] == WEATHER_NONE || state[2] == WEATHER_SMOG)
		return null
	return state

// The last tile asked about. Most callers ask for class, look and intensity
// in a row, and a mob asks about its own tile several times a tick.
var/global/turf/weather_sample_turf = null
var/global/weather_sample_time = -1
var/global/weather_sample_class = WEATHER_NONE
var/global/weather_sample_look = ""
var/global/weather_sample_intensity = 0
var/global/weather_sample_zone_class = null
var/global/weather_sample_zone_look = null

/proc/weather_sample(atom/A)
	var/turf/T = get_turf(A)
	var/area/place = T ? T.loc : null
	// The zone's own weather is part of the key: a script may repaint it mid-tick.
	if (T && T == weather_sample_turf && world.time == weather_sample_time && istype(place) && place.weather == weather_sample_zone_class && place.icon_state == weather_sample_zone_look)
		return
	weather_sample_turf = T
	weather_sample_time = world.time
	weather_sample_class = WEATHER_NONE
	weather_sample_look = ""
	weather_sample_intensity = 0
	if (!istype(place))
		return
	weather_sample_zone_class = place.weather
	weather_sample_zone_look = place.icon_state
	// Zone weather pinned by a map script or an admin.
	weather_sample_class = place.weather
	weather_sample_look = place.icon_state
	if (copytext(weather_sample_look, 1, 5) == "rad_")
		weather_sample_look = copytext(weather_sample_look, 5)
	if (weather_sample_look == "roof")
		weather_sample_look = ""
	weather_sample_intensity = (place.weather == WEATHER_WET || place.weather == WEATHER_EXTREME) ? place.weather_intensity : 0
	if (!weather_storm_count || place.location != AREA_OUTSIDE || !istype(place, /area/caribbean))
		return
	var/strength = weather_storm_strength(T.x, T.y)
	var/list/state = weather_storm_state(place.climate, strength, weather_storm_severe)
	if (!state)
		return
	// The worse of the two wins.
	if (weather_sample_class == WEATHER_EXTREME && state[2] != WEATHER_EXTREME)
		return
	if (weather_sample_class == state[2] && weather_sample_intensity >= state[3])
		return
	weather_sample_look = state[1]
	weather_sample_class = state[2]
	weather_sample_intensity = state[3]

// WEATHER_NONE, WEATHER_WET, WEATHER_EXTREME or WEATHER_SMOG on this tile.
// Roofed areas are always WEATHER_NONE, as they were as zones.
/proc/weather_at(atom/A)
	weather_sample(A)
	return weather_sample_class

// What is falling: "", "rain1" to "rain3", "monsoon", "snow1", "snow2",
// "snow_storm" or "sandstorm".
/proc/weather_look_at(atom/A)
	weather_sample(A)
	return weather_sample_look

// 0 in clear weather, 1 to 3 in wet or extreme weather.
/proc/weather_intensity_at(atom/A)
	weather_sample(A)
	return weather_sample_intensity

// TRUE while any precipitation, storm or zone weather is about. A cheap gate
// for callers that would otherwise look up an area every tick.
/proc/weather_anywhere()
	return weather_storm_count || weather == WEATHER_WET || weather == WEATHER_EXTREME

// ---- the sky, each weather tick -----------------------------

/proc/weather_systems_step()
	var/list/wind = weather_wind_vector()
	var/speed = weather_wind_speed()
	for (var/datum/weather_system/S in weather_systems.Copy())
		if (S.spent())
			weather_system_end(S)
			continue
		// Come round to the wind a little at a time.
		var/new_x = S.vel_x * 0.85 + wind[1] * speed * 0.15
		var/new_y = S.vel_y * 0.85 + wind[2] * speed * 0.15
		if (abs(new_x - S.vel_x) > 0.0002 || abs(new_y - S.vel_y) > 0.0002)
			S.set_course(new_x, new_y)
	weather_systems_tell()

/proc/weather_bearing(dx, dy)
	if (abs(dx) > abs(dy) * 2)
		return dx > 0 ? "east" : "west"
	if (abs(dy) > abs(dx) * 2)
		return dy > 0 ? "north" : "south"
	return "[dy > 0 ? "north" : "south"][dx > 0 ? "east" : "west"]"

// Tell the players in a storm's path that it is coming, and those under a
// heat system when it arrives and when it has gone. Nobody else hears of it.
/proc/weather_systems_tell()
	if (!weather_systems.len)
		return
	for (var/client/C in clients)
		var/mob/M = C.mob
		var/turf/T = M ? get_turf(M) : null
		if (!T || !isliving(M) || M.stat)
			continue
		var/area/place = T.loc
		if (!istype(place) || place.location != AREA_OUTSIDE)
			continue
		for (var/datum/weather_system/S in weather_systems)
			var/strength = S.strength_at(T.x, T.y)
			if (S.kind == WEATHER_SYSTEM_HEAT)
				if (strength >= WEATHER_BAND_LIGHT)
					if (!(C.ckey in S.inside))
						S.inside += C.ckey
						to_chat(M, "<big>The air turns hot and dry. A heat wave has settled over this place.</big>")
				else if (C.ckey in S.inside)
					S.inside -= C.ckey
					to_chat(M, "<big>The heat wave has passed.</big>")
				continue
			if (strength > 0 || (C.ckey in S.warned) || S.power() <= 0)
				continue
			var/dx = S.centre_x() - T.x
			var/dy = S.centre_y() - T.y
			var/reach = max(S.radius_x, S.radius_y) + WEATHER_WARNING_RANGE
			if (dx * dx + dy * dy > reach * reach)
				continue
			// Only those it is heading for: the gap must be closing.
			if (dx * S.vel_x + dy * S.vel_y >= 0)
				continue
			S.warned += C.ckey
			var/list/state = weather_storm_state(place.climate, S.peak, S.severe)
			if (!state)
				continue
			var/sight = "Dark clouds are gathering"
			switch (state[1])
				if ("snow_storm")
					sight = "A wall of white is bearing down"
				if ("sandstorm")
					sight = "A wall of dust is rising"
				if ("monsoon")
					sight = "Towering black clouds are building"
				if ("snow1", "snow2")
					sight = "Heavy grey clouds are gathering"
			to_chat(M, "<big>[sight] to the [weather_bearing(dx, dy)].</big>")

// ---- what the sky holds, for admins and instruments ---------

/proc/weather_system_report()
	var/list/lines = list()
	for (var/datum/weather_system/S in weather_systems)
		var/x = round(S.centre_x())
		var/y = round(S.centre_y())
		var/what = S.kind == WEATHER_SYSTEM_HEAT ? "heat wave" : (S.severe ? "severe storm" : "storm")
		var/heading = (S.vel_x || S.vel_y) ? weather_bearing(S.vel_x, S.vel_y) : "nowhere"
		lines += "#[S.id] [what] at [x],[y], about [round(S.radius_x)] by [round(S.radius_y)] tiles, strength [round(S.power() * 100)]%, heading [heading], [max(0, round((S.lifetime - (world.time - S.born)) / 600))] min left"
	return lines
