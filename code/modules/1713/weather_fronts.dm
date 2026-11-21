// Lows, highs and fronts (docs/weather-fronts.md).
//
// Pressure centres drift across the map with the wind. A low draws the
// pressure down round it, brings warm air ahead of it and cold air behind
// its cold front, and is where rolled storms now form: a wet or extreme roll
// puts its storm on the low's front instead of on a random spot. A high
// raises the pressure, and in summer a deep high can stall into a heat wave.
// On hot, humid afternoons the air grid can also throw up a thunderstorm in
// place. Centres live only in memory, like the weather systems.

#define WEATHER_CENTRE_MAX 3
// Chance per weather tick (10 s) of a new centre while fewer than the most.
#define WEATHER_CENTRE_SPAWN_PROB 2
// Air that can raise a thunderstorm in the afternoon.
#define WEATHER_CONVECTION_TEMP 24
#define WEATHER_CONVECTION_RH 65
#define WEATHER_CONVECTION_PROB 3

var/global/list/weather_centres = list()
var/global/weather_centre_serial = 0

/datum/weather_centre
	var/id = 0
	var/kind = WEATHER_CENTRE_LOW
	var/origin_x = 0
	var/origin_y = 0
	var/origin_time = 0
	var/vel_x = 0 // tiles a decisecond
	var/vel_y = 0
	var/depth = 15 // hPa below (low) or above (high) the normal at its heart
	var/radius = 100
	var/born = 0
	var/lifetime = 27000

/datum/weather_centre/proc/centre_x()
	return origin_x + vel_x * (world.time - origin_time)

/datum/weather_centre/proc/centre_y()
	return origin_y + vel_y * (world.time - origin_time)

// 0 to 1: deepens over its first five minutes, fills over its last five.
/datum/weather_centre/proc/power()
	var/age = world.time - born
	if (age < 0)
		return 0
	return clamp(min(age / 3000, (lifetime - age) / 3000), 0, 1)

// Its share at a point, 0 to 1, falling off with distance from its heart.
/datum/weather_centre/proc/reach_at(x, y)
	var/dx = (x - centre_x()) / radius
	var/dy = (y - centre_y()) / radius
	var/d2 = dx * dx + dy * dy
	if (d2 > 4)
		return 0
	return power() * (2.718281828 ** (-d2))

// hPa it adds at a point: negative for a low.
/datum/weather_centre/proc/pressure_at(x, y)
	var/share = reach_at(x, y) * depth
	return kind == WEATHER_CENTRE_LOW ? -share : share

// C it adds at a point. Round a low the air ahead (downwind) is warm and the
// air behind its cold front (upwind) is cold.
/datum/weather_centre/proc/temperature_at(x, y)
	if (kind != WEATHER_CENTRE_LOW)
		return 0
	var/share = reach_at(x, y)
	if (!share)
		return 0
	var/speed = sqrt(vel_x * vel_x + vel_y * vel_y)
	if (!speed)
		return 0
	// Along the course: + ahead of the centre, - behind it, in radii.
	var/along = ((x - centre_x()) * vel_x + (y - centre_y()) * vel_y) / (speed * radius)
	if (along >= 0)
		return 2 * share * min(1, along * 2)
	return -4 * share * min(1, -along * 2)

// Where its front rain falls: a little ahead of the heart, across the course.
/datum/weather_centre/proc/front_point()
	var/speed = sqrt(vel_x * vel_x + vel_y * vel_y)
	var/ux = speed ? vel_x / speed : 1
	var/uy = speed ? vel_y / speed : 0
	var/ahead = radius * 0.4
	var/across = radius * (rand(-50, 50) / 100)
	return list(clamp(round(centre_x() + ux * ahead - uy * across), 1, world.maxx), clamp(round(centre_y() + uy * ahead + ux * across), 1, world.maxy))

/datum/weather_centre/proc/spent()
	if (world.time - born >= lifetime)
		return TRUE
	var/x = centre_x()
	var/y = centre_y()
	var/r = radius * 2
	return x < -r || y < -r || x > world.maxx + r || y > world.maxy + r

// A new centre that forms upwind and crosses the map, or at a set spot.
/proc/weather_centre_spawn(kind, at_x, at_y)
	if (weather_centres.len >= WEATHER_CENTRE_MAX)
		return null
	var/datum/weather_centre/C = new
	C.id = ++weather_centre_serial
	C.kind = kind
	C.depth = kind == WEATHER_CENTRE_LOW ? rand(10, 30) : rand(8, 20)
	C.radius = rand(round(max(world.maxx, world.maxy) * 0.25), round(max(world.maxx, world.maxy) * 0.5)) + 40
	C.born = world.time
	C.lifetime = rand(18000, 36000) // 30 to 60 minutes
	var/list/wind = weather_wind_unit()
	// Centres drift slower than the storms they carry.
	var/speed = weather_wind_speed() * 0.6
	C.vel_x = wind[1] * speed
	C.vel_y = wind[2] * speed
	if (isnull(at_x) || isnull(at_y))
		// Somewhere along the upwind edge, its heart just inside the map.
		var/cross = rand(10, 90) / 100
		at_x = wind[1] ? (wind[1] > 0 ? 1 : world.maxx) : round(world.maxx * cross)
		at_y = wind[2] ? (wind[2] > 0 ? 1 : world.maxy) : round(world.maxy * cross)
	C.origin_x = at_x
	C.origin_y = at_y
	C.origin_time = world.time
	weather_centres += C
	return C

/proc/weather_centre_end(datum/weather_centre/C)
	weather_centres -= C

/proc/weather_centres_clear()
	weather_centres.Cut()

// The deepest low over the map, or null.
/proc/weather_deepest_low()
	var/datum/weather_centre/best = null
	for (var/datum/weather_centre/C in weather_centres)
		if (C.kind == WEATHER_CENTRE_LOW && (!best || C.depth * C.power() > best.depth * best.power()))
			best = C
	return best

// Lows come more often in the wet half of the year, highs in the dry half.
/proc/weather_centre_low_chance()
	if (season == SEASON_SUMMER || season == SEASON_DRY)
		return 35
	if (season == SEASON_WINTER || season_is_wet())
		return 65
	return 50

// A rolled storm forms on a low's front. With no low about, one forms and
// brings it. Falls back to a storm over a random spot.
/proc/weather_front_storm(severe)
	var/datum/weather_centre/low = weather_deepest_low()
	if (!low)
		low = weather_centre_spawn(WEATHER_CENTRE_LOW)
	if (!low)
		return weather_system_spawn(WEATHER_SYSTEM_STORM, severe)
	// A deep low over cold air can make any storm on it severe.
	if (!severe && low.depth >= 25 && prob(30))
		severe = TRUE
	var/list/at = low.front_point()
	return weather_system_spawn(WEATHER_SYSTEM_STORM, severe, at[1], at[2])

// Map policy still decides whether random storms may form at all.
/proc/weather_fronts_allowed(result)
	if (!map)
		return TRUE
	if (!map.weather_policy_valid())
		return FALSE
	return (result in map.valid_weather_types)

// One weather tick, before the air grid settles (weather_air.dm).
/proc/weather_centres_step()
	for (var/datum/weather_centre/C in weather_centres.Copy())
		if (C.spent())
			weather_centre_end(C)
	if (!map || !map.valid_weather_types || !(WEATHER_WET in map.valid_weather_types))
		return
	if (weather_centres.len < WEATHER_CENTRE_MAX && (!weather_centres.len || prob(WEATHER_CENTRE_SPAWN_PROB)))
		weather_centre_spawn(prob(weather_centre_low_chance()) ? WEATHER_CENTRE_LOW : WEATHER_CENTRE_HIGH)
	weather_heat_from_highs()
	weather_convection_step()

// A deep summer high stalls into a heat wave now and then.
/proc/weather_heat_from_highs()
	if (season != SEASON_SUMMER && season != SEASON_DRY)
		return
	if (weather_systems.len != weather_storm_count) // a heat wave already
		return
	for (var/datum/weather_centre/C in weather_centres)
		if (C.kind == WEATHER_CENTRE_HIGH && C.depth >= 15 && C.power() >= 1 && prob(1))
			weather_system_spawn(WEATHER_SYSTEM_HEAT, FALSE, clamp(round(C.centre_x()), 1, world.maxx), clamp(round(C.centre_y()), 1, world.maxy), 600)
			return

// On a hot, humid afternoon the warmest such cell can throw up a thunderstorm
// where it stands: small, short and heavy, with lightning at its core.
/proc/weather_convection_step()
	if (time_of_day != "Midday" && time_of_day != "Afternoon")
		return
	if (!weather_air || !weather_fronts_allowed(WEATHER_WET))
		return
	if (weather_storm_count >= weather_system_capacity() || !prob(WEATHER_CONVECTION_PROB))
		return
	var/datum/weather_air_grid/G = weather_air
	var/best = 0
	var/best_heat = 0
	for (var/i = 1, i <= G.temp.len, i++)
		if (G.water[i] || G.temp[i] < WEATHER_CONVECTION_TEMP || G.cloud[i] >= 0.5)
			continue
		if (weather_relative_humidity(G.temp[i], G.dew[i]) < WEATHER_CONVECTION_RH)
			continue
		var/heat = G.temp[i] + G.dew[i]
		if (heat > best_heat)
			best_heat = heat
			best = i
	if (!best)
		return
	var/col = (best - 1) % G.cols
	var/row = round((best - 1) / G.cols)
	var/x = clamp(col * 16 + 8, 1, world.maxx)
	var/y = clamp(row * 16 + 8, 1, world.maxy)
	weather_convective_storm(x, y, G.temp[best] >= 30 && G.dew[best] >= 20)

// A storm that forms in place rather than arriving from upwind.
/proc/weather_convective_storm(x, y, severe = FALSE)
	var/datum/weather_system/S = weather_system_spawn(WEATHER_SYSTEM_STORM, severe, x, y, 0)
	if (!S)
		return null
	S.radius_x = rand(18, 32)
	S.radius_y = rand(18, 32)
	S.peak = 1
	S.origin_x = x
	S.origin_y = y
	S.origin_time = world.time
	S.lifetime = rand(6000, 12000) // 10 to 20 minutes
	weather_sample_time = -1
	return S

// Pressure and temperature the centres add over a point (weather_air.dm).
/proc/weather_centres_pressure_at(x, y)
	. = 0
	for (var/datum/weather_centre/C in weather_centres)
		. += C.pressure_at(x, y)

/proc/weather_centres_temperature_at(x, y)
	. = 0
	for (var/datum/weather_centre/C in weather_centres)
		. += C.temperature_at(x, y)

// For the Admin Map (admin_map.dm): list(id, kind, x, y, radius, depth hPa now).
/proc/weather_centres_map_data()
	. = list()
	for (var/datum/weather_centre/C in weather_centres)
		. += list(list(C.id, C.kind, round(C.centre_x()), round(C.centre_y()), round(C.radius), round(C.depth * C.power(), 0.1)))

#undef WEATHER_CENTRE_MAX
#undef WEATHER_CENTRE_SPAWN_PROB
#undef WEATHER_CONVECTION_TEMP
#undef WEATHER_CONVECTION_RH
#undef WEATHER_CONVECTION_PROB
