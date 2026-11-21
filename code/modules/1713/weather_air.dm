// The air grid (docs/weather-air.md): a coarse field of air over the map that
// holds temperature, dew point, pressure and cloud cover. It is the ground the
// later meteorology steps build on (fronts, wind from pressure, fog, frost).
//
// Cells are WEATHER_AIR_CELL tiles on a side, one grid for the whole sky like
// the weather systems (weather_systems.dm). Each cell remembers the climate and
// whether it is mostly water from the highest open-sky ground under its centre.
// Every weather tick the cells relax toward what their climate, the season,
// the time of day and the weather systems over them call for. Nothing is
// saved: after a restart the grid is built straight at those values.
//
// The per-tile readers blend the four nearest cells, so values change
// smoothly across the map. Each cell also carries a wind (weather_wind.dm). get_temp() does not read the grid yet; the player
// temperature still comes from climate_normals.dm.

#define WEATHER_AIR_CELL 16
#define WEATHER_AIR_SEA_LEVEL_HPA 1013
#define WEATHER_AIR_E 2.718281828
// Share of the gap to the target closed each weather tick (10 seconds).
#define WEATHER_AIR_TEMP_RATE 0.1
#define WEATHER_AIR_DEW_RATE 0.08
#define WEATHER_AIR_PRESSURE_RATE 0.15
#define WEATHER_AIR_CLOUD_RATE 0.2

// Typical relative humidity of each climate's air, in %. Savanna is dry in the
// dry season and humid in the wet one.
var/global/list/climate_humidity = list(
	"temperate" = 75,
	"sea" = 85,
	"taiga" = 70,
	"tundra" = 75,
	"semiarid" = 45,
	"desert" = 25,
	"savanna" = 60,
	"jungle" = 85)

var/global/datum/weather_air_grid/weather_air = null

/datum/weather_air_grid
	var/cols = 0
	var/rows = 0
	var/list/climates = list() // per cell, by index
	var/list/water = list() // per cell: TRUE when most of it is open water
	var/list/temp = list() // degrees C
	var/list/dew = list() // dew point, degrees C
	var/list/pressure = list() // hPa
	var/list/cloud = list() // 0 to 1
	var/list/heights = list() // per cell: mean terrain height level, 0 on maps without heights
	var/steps = 0

/datum/weather_air_grid/New()
	..()
	cols = max(1, ceil(world.maxx / WEATHER_AIR_CELL))
	rows = max(1, ceil(world.maxy / WEATHER_AIR_CELL))
	var/count = cols * rows
	climates.len = count
	water.len = count
	temp.len = count
	dew.len = count
	pressure.len = count
	cloud.len = count
	heights.len = count
	for (var/row = 0, row < rows, row++)
		for (var/col = 0, col < cols, col++)
			survey(col, row)
	survey_wind() // weather_wind.dm
	settle(TRUE)

/datum/weather_air_grid/proc/index(col, row)
	return row * cols + col + 1

// The climate and the water share of a cell, read from the highest open-sky
// ground at nine points across it (centre, corners and edge middles).
/datum/weather_air_grid/proc/survey(col, row)
	var/i = index(col, row)
	var/list/votes = list()
	var/wet = 0
	var/seen = 0
	var/height = 0
	var/use_heights = map && map.terrain_height_file
	for (var/fx in list(0.15, 0.5, 0.85))
		for (var/fy in list(0.15, 0.5, 0.85))
			var/x = clamp(round(col * WEATHER_AIR_CELL + fx * WEATHER_AIR_CELL) + 1, 1, world.maxx)
			var/y = clamp(round(row * WEATHER_AIR_CELL + fy * WEATHER_AIR_CELL) + 1, 1, world.maxy)
			var/turf/T = weather_air_sky_turf(x, y)
			if (!T)
				continue
			seen++
			var/area/A = T.loc
			if (A && A.climate)
				votes[A.climate] = (votes[A.climate] || 0) + 1
			if (istype(T, /turf/floor/beach/water))
				wet++
			if (use_heights)
				height += terrain_height_at(T)
	var/best = null
	for (var/name in votes)
		if (!best || votes[name] > votes[best])
			best = name
	climates[i] = best
	water[i] = seen && wet * 2 > seen
	heights[i] = seen ? height / seen : 0

// The open-sky ground at x, y: the highest level whose area is outdoors, or
// the first level when none is.
/proc/weather_air_sky_turf(x, y)
	for (var/z = world.maxz, z >= 1, z--)
		var/turf/T = locate(x, y, z)
		var/area/A = T ? T.loc : null
		if (A && A.location == AREA_OUTSIDE)
			return T
	return locate(x, y, 1)

/proc/weather_air_humidity_normal(climate)
	var/rh = climate_humidity[climate]
	if (!isnum(rh))
		rh = 70
	if (climate == "savanna")
		if (season == SEASON_WET)
			rh = 80
		else if (season == SEASON_DRY)
			rh = 35
	return rh

// Dew point (C) of air at temp_c with relative humidity rh % (Magnus formula).
/proc/weather_dew_point(temp_c, rh)
	rh = clamp(rh, 1, 100)
	var/g = log(rh / 100) + 17.62 * temp_c / (243.12 + temp_c)
	return 243.12 * g / (17.62 - g)

// Relative humidity (%) of air at temp_c whose dew point is dew_c.
/proc/weather_relative_humidity(temp_c, dew_c)
	dew_c = min(dew_c, temp_c)
	return clamp(100 * (WEATHER_AIR_E ** (17.62 * dew_c / (243.12 + dew_c) - 17.62 * temp_c / (243.12 + temp_c))), 0, 100)

// Strongest storm and heat system over a point, as list(storm, heat, severe).
/proc/weather_air_systems_at(x, y)
	var/storm = 0
	var/heat = 0
	var/severe = FALSE
	for (var/datum/weather_system/S in weather_systems)
		var/strength = S.strength_at(x, y)
		if (S.kind == WEATHER_SYSTEM_HEAT)
			heat = max(heat, strength)
		else if (strength > storm)
			storm = strength
			severe = S.severe
	return list(storm, heat, severe)

// Move every cell toward what it should be now; at once when snap is TRUE.
/datum/weather_air_grid/proc/settle(snap = FALSE)
	var/fraction = climate_season_fraction()
	for (var/row = 0, row < rows, row++)
		var/y = row * WEATHER_AIR_CELL + WEATHER_AIR_CELL / 2
		for (var/col = 0, col < cols, col++)
			var/x = col * WEATHER_AIR_CELL + WEATHER_AIR_CELL / 2
			var/i = index(col, row)
			var/climate = climates[i]
			var/list/sky = weather_air_systems_at(x, y)
			var/storm = sky[1]
			var/heat = sky[2]
			// Cloud: a storm's own cover, or a grey sky in near-saturated air.
			var/rh_now = snap ? weather_air_humidity_normal(climate) : weather_relative_humidity(temp[i], dew[i])
			var/cloud_target = max(storm, rh_now >= 90 ? (rh_now - 90) / 20 : 0)
			// Water warms and cools slowly, so its daily swing is halved.
			var/daily = climate_daily_offset(climate, time_of_day, (snap ? cloud_target : cloud[i]) >= 0.4)
			if (water[i])
				daily /= 2
			var/temp_target = climate_mean_at(climate, season, fraction) + daily - 2 * storm + 6 * heat + weather_centres_temperature_at(x, y)
			// Air over water and under rain is moister; heat dries it.
			var/rh_target = weather_air_humidity_normal(climate)
			if (water[i])
				rh_target += 10
			rh_target = rh_target + (97 - rh_target) * storm - 20 * heat
			var/pressure_target = WEATHER_AIR_SEA_LEVEL_HPA - (sky[3] ? 30 : 18) * storm + 10 * heat + weather_centres_pressure_at(x, y)
			if (snap)
				temp[i] = temp_target
				dew[i] = weather_dew_point(temp_target, rh_target)
				pressure[i] = pressure_target
				cloud[i] = cloud_target
				continue
			temp[i] += (temp_target - temp[i]) * WEATHER_AIR_TEMP_RATE
			var/dew_target = weather_dew_point(temp[i], rh_target)
			dew[i] = min(temp[i], dew[i] + (dew_target - dew[i]) * WEATHER_AIR_DEW_RATE)
			pressure[i] += (pressure_target - pressure[i]) * WEATHER_AIR_PRESSURE_RATE
			cloud[i] += (cloud_target - cloud[i]) * WEATHER_AIR_CLOUD_RATE
	settle_wind(snap) // weather_wind.dm
	settle_precip() // weather_precip.dm
	steps++

// One weather tick (processes/weather.dm, through weather_systems_step()).
/proc/weather_air_step()
	weather_centres_step()
	if (!weather_air)
		weather_air = new
		return
	weather_air.settle()
	weather_hail_step() // weather_precip.dm

/proc/weather_air_grid()
	if (!weather_air)
		weather_air = new
	return weather_air

// The four cells round a tile and their weights, as list(i1, w1, ... i4, w4).
/datum/weather_air_grid/proc/blend_at(x, y)
	var/fx = clamp((x - 0.5) / WEATHER_AIR_CELL - 0.5, 0, cols - 1)
	var/fy = clamp((y - 0.5) / WEATHER_AIR_CELL - 0.5, 0, rows - 1)
	var/c0 = floor(fx)
	var/r0 = floor(fy)
	var/c1 = min(c0 + 1, cols - 1)
	var/r1 = min(r0 + 1, rows - 1)
	var/ax = fx - c0
	var/ay = fy - r0
	return list(index(c0, r0), (1 - ax) * (1 - ay), index(c1, r0), ax * (1 - ay), index(c0, r1), (1 - ax) * ay, index(c1, r1), ax * ay)

/datum/weather_air_grid/proc/value_at(list/field, x, y)
	var/list/b = blend_at(x, y)
	return field[b[1]] * b[2] + field[b[3]] * b[4] + field[b[5]] * b[6] + field[b[7]] * b[8]

// ---- per-tile readers ----------------------------------------

// Air temperature of the open sky over A, in C (not shelter or fires).
/proc/weather_air_temp_at(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return null
	var/datum/weather_air_grid/G = weather_air_grid()
	return G.value_at(G.temp, T.x, T.y)

/proc/weather_dew_point_at(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return null
	var/datum/weather_air_grid/G = weather_air_grid()
	return G.value_at(G.dew, T.x, T.y)

// Relative humidity over A, in %.
/proc/weather_humidity_at(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return null
	var/datum/weather_air_grid/G = weather_air_grid()
	return weather_relative_humidity(G.value_at(G.temp, T.x, T.y), G.value_at(G.dew, T.x, T.y))

// Air pressure over A at sea level, in hPa.
/proc/weather_pressure_at(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return null
	var/datum/weather_air_grid/G = weather_air_grid()
	return G.value_at(G.pressure, T.x, T.y)

// Cloud cover over A, 0 (clear) to 1 (overcast).
/proc/weather_cloud_at(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return null
	var/datum/weather_air_grid/G = weather_air_grid()
	return clamp(G.value_at(G.cloud, T.x, T.y), 0, 1)

// The grid for the Admin Map (admin_map.dm): list(cols, rows, cell size, temperatures,
// humidities, pressures, clouds, wind east and wind north in m/s), each rounded,
// one entry per cell by index.
/proc/weather_air_map_data()
	var/datum/weather_air_grid/G = weather_air_grid()
	var/list/t = list()
	var/list/h = list()
	var/list/p = list()
	var/list/c = list()
	var/list/we = list()
	var/list/wn = list()
	for (var/i = 1, i <= G.temp.len, i++)
		t += round(G.temp[i], 0.1)
		h += round(weather_relative_humidity(G.temp[i], G.dew[i]))
		p += round(G.pressure[i], 0.1)
		c += round(G.cloud[i] * 100)
		we += round(G.wind_x[i], 0.1)
		wn += round(G.wind_y[i], 0.1)
	return list(G.cols, G.rows, WEATHER_AIR_CELL, t, h, p, c, we, wn)

#undef WEATHER_AIR_CELL
#undef WEATHER_AIR_SEA_LEVEL_HPA
#undef WEATHER_AIR_E
#undef WEATHER_AIR_TEMP_RATE
#undef WEATHER_AIR_DEW_RATE
#undef WEATHER_AIR_PRESSURE_RATE
#undef WEATHER_AIR_CLOUD_RATE
