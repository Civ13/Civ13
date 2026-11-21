// The wind field (docs/weather-wind.md): every air cell (weather_air.dm)
// carries its own wind, in metres a second, east and north.
//
// A cell's wind is the sum of:
// - the map's wind (map.winddirection and windspeedvar), the large-scale flow
//   that also carries the storms and pressure centres across the map;
// - the pressure field: air flows from high to low pressure, turned by the
//   Earth's spin so it circles a low (anticlockwise in the north, clockwise in
//   the south) and spills a little inward over rough ground;
// - sea and land breezes: on a sunny afternoon air blows in off the water, on
//   a clear night it drains back out to it;
// - terrain on maps with heights: hilltops are windier, valleys sheltered and
//   steer the wind along them, and on clear nights cold air slides downhill.
// A storm overhead still brings its gale on top (weather_wind_at).
//
// Old readers keep their 0 (calm) to 4 (gale) scale. On a map with no air
// grid yet, or a flat, dry map under even pressure, the answer is the map's
// wind, as before.

// m/s for each map wind strength 0 to 4, and the gaps between them.
var/global/list/weather_wind_strength_ms = list(0, 3, 6, 11, 18)
var/global/list/weather_wind_strength_steps = list(1.75, 4.5, 8.5, 14.5)
// Lower edges of Beaufort forces 1 to 12, in m/s.
var/global/list/weather_beaufort_ms = list(0.5, 1.6, 3.4, 5.5, 8, 10.8, 13.9, 17.2, 20.8, 24.5, 28.5, 32.7)

// m/s of wind for each hPa of pressure difference across one cell.
#define WEATHER_WIND_GRADIENT_MS 2
#define WEATHER_WIND_GRADIENT_MAX 25
// Degrees the surface wind is turned from straight down the pressure slope:
// 90 would circle the low exactly; friction leaves 30 degrees of inflow.
#define WEATHER_WIND_TURN 60
#define WEATHER_WIND_SEA_BREEZE 4
#define WEATHER_WIND_LAND_BREEZE 2
#define WEATHER_WIND_DRAINAGE 1.5
#define WEATHER_WIND_RATE 0.25

/datum/weather_air_grid
	var/list/wind_x = list() // m/s toward the east
	var/list/wind_y = list() // m/s toward the north
	var/list/shore_x = list() // per cell: unit-ish vector pointing to the land side of a shore
	var/list/shore_y = list()
	var/list/slope_x = list() // per cell: height levels gained per cell eastward
	var/list/slope_y = list()
	var/list/rise = list() // per cell: height levels above the cells round it
	var/has_heights = FALSE

// Shores and slopes, once, after the cells are surveyed.
/datum/weather_air_grid/proc/survey_wind()
	var/count = cols * rows
	wind_x.len = count
	wind_y.len = count
	shore_x.len = count
	shore_y.len = count
	slope_x.len = count
	slope_y.len = count
	rise.len = count
	has_heights = FALSE
	for (var/i = 1, i <= count, i++)
		wind_x[i] = 0
		wind_y[i] = 0
		if (heights[i])
			has_heights = TRUE
	for (var/row = 0, row < rows, row++)
		for (var/col = 0, col < cols, col++)
			var/i = index(col, row)
			var/sx = 0
			var/sy = 0
			var/around = 0
			var/seen = 0
			for (var/dy = -1, dy <= 1, dy++)
				for (var/dx = -1, dx <= 1, dx++)
					if (!dx && !dy)
						continue
					var/c = col + dx
					var/r = row + dy
					if (c < 0 || r < 0 || c >= cols || r >= rows)
						continue
					var/j = index(c, r)
					seen++
					around += heights[j]
					if (water[j] == water[i])
						continue
					var/n = sqrt(dx * dx + dy * dy)
					// Toward the land: away from a wet neighbour, toward a dry one.
					sx += (water[i] ? dx : -dx) / n
					sy += (water[i] ? dy : -dy) / n
			var/len = sqrt(sx * sx + sy * sy)
			if (len > 1)
				sx /= len
				sy /= len
			shore_x[i] = sx
			shore_y[i] = sy
			rise[i] = seen ? heights[i] - around / seen : 0
			var/c0 = max(col - 1, 0)
			var/c1 = min(col + 1, cols - 1)
			var/r0 = max(row - 1, 0)
			var/r1 = min(row + 1, rows - 1)
			slope_x[i] = c1 > c0 ? (heights[index(c1, row)] - heights[index(c0, row)]) / (c1 - c0) : 0
			slope_y[i] = r1 > r0 ? (heights[index(col, r1)] - heights[index(col, r0)]) / (r1 - r0) : 0

// 1 in the northern hemisphere, -1 in the southern (a map with a sun south
// of the equator).
/proc/weather_hemisphere()
	if (map && isnum(map.sun_latitude) && map.sun_latitude < 0)
		return -1
	return 1

// list(x, y) turned clockwise by angle degrees.
/proc/weather_turn_vector(x, y, angle)
	var/c = cos(angle)
	var/s = sin(angle)
	return list(x * c + y * s, y * c - x * s)

// m/s for a map wind strength.
/proc/weather_wind_ms(strength)
	return weather_wind_strength_ms[clamp(round(strength), 0, 4) + 1]

// The map's wind as list(east, north) in m/s.
/proc/weather_background_wind()
	var/list/v = weather_wind_vector()
	var/n = sqrt(v[1] * v[1] + v[2] * v[2])
	if (!n)
		return list(0, 0)
	var/speed = weather_wind_ms(map ? map.windspeedvar : 1)
	return list(v[1] / n * speed, v[2] / n * speed)

// Move every cell's wind toward what the air calls for; at once when snap.
/datum/weather_air_grid/proc/settle_wind(snap = FALSE)
	if (wind_x.len != cols * rows)
		survey_wind()
	var/list/base = weather_background_wind()
	var/turn_by = WEATHER_WIND_TURN * weather_hemisphere()
	var/sunny = time_of_day == "Midday" || time_of_day == "Afternoon"
	var/dark = time_of_day == "Night" || time_of_day == "Dark Night" || time_of_day == "Early Morning"
	for (var/row = 0, row < rows, row++)
		var/r0 = max(row - 1, 0)
		var/r1 = min(row + 1, rows - 1)
		for (var/col = 0, col < cols, col++)
			var/i = index(col, row)
			var/c0 = max(col - 1, 0)
			var/c1 = min(col + 1, cols - 1)
			var/tx = base[1]
			var/ty = base[2]
			// Down the pressure slope, turned round the lows.
			var/gx = c1 > c0 ? (pressure[index(c1, row)] - pressure[index(c0, row)]) / (c1 - c0) : 0
			var/gy = r1 > r0 ? (pressure[index(col, r1)] - pressure[index(col, r0)]) / (r1 - r0) : 0
			if (gx || gy)
				var/list/flow = weather_turn_vector(-gx * WEATHER_WIND_GRADIENT_MS, -gy * WEATHER_WIND_GRADIENT_MS, turn_by)
				var/speed = sqrt(flow[1] * flow[1] + flow[2] * flow[2])
				if (speed > WEATHER_WIND_GRADIENT_MAX)
					flow[1] *= WEATHER_WIND_GRADIENT_MAX / speed
					flow[2] *= WEATHER_WIND_GRADIENT_MAX / speed
				tx += flow[1]
				ty += flow[2]
			// Sea breeze by day, land breeze by night, both strongest under a clear sky.
			if ((sunny || dark) && (shore_x[i] || shore_y[i]))
				var/clear = 1 - clamp(cloud[i], 0, 1)
				var/breeze = sunny ? WEATHER_WIND_SEA_BREEZE : -WEATHER_WIND_LAND_BREEZE
				tx += shore_x[i] * breeze * clear
				ty += shore_y[i] * breeze * clear
			if (has_heights)
				var/up = rise[i]
				// A valley turns the wind along its floor.
				if (up <= -1 && (slope_x[i] || slope_y[i]))
					var/sl = sqrt(slope_x[i] * slope_x[i] + slope_y[i] * slope_y[i])
					var/ax = -slope_y[i] / sl
					var/ay = slope_x[i] / sl
					var/along = tx * ax + ty * ay
					tx = tx * 0.5 + along * ax * 0.5
					ty = ty * 0.5 + along * ay * 0.5
				var/exposure = clamp(1 + 0.15 * up, 0.5, 1.6)
				tx *= exposure
				ty *= exposure
				// Cold air drains downhill on a clear night.
				if (dark)
					var/clear_night = 1 - clamp(cloud[i], 0, 1)
					tx += clamp(-slope_x[i] * WEATHER_WIND_DRAINAGE, -4, 4) * clear_night
					ty += clamp(-slope_y[i] * WEATHER_WIND_DRAINAGE, -4, 4) * clear_night
			if (snap)
				wind_x[i] = tx
				wind_y[i] = ty
			else
				wind_x[i] += (tx - wind_x[i]) * WEATHER_WIND_RATE
				wind_y[i] += (ty - wind_y[i]) * WEATHER_WIND_RATE

// ---- per-tile readers ----------------------------------------

// The open-sky wind over A as list(east, north) in m/s, before any storm gust.
/proc/weather_wind_vector_at(atom/A)
	var/turf/T = get_turf(A)
	if (!T || !weather_air || weather_air.wind_x.len != weather_air.cols * weather_air.rows)
		return weather_background_wind()
	var/datum/weather_air_grid/G = weather_air
	return list(G.value_at(G.wind_x, T.x, T.y), G.value_at(G.wind_y, T.x, T.y))

// Wind speed over A in m/s, with the gale under a storm.
/proc/weather_wind_ms_at(atom/A)
	var/list/v = weather_wind_vector_at(A)
	. = sqrt(v[1] * v[1] + v[2] * v[2])
	var/turf/T = get_turf(A)
	if (!T || !weather_storm_count)
		return
	var/strength = weather_storm_strength(T.x, T.y)
	if (strength >= WEATHER_BAND_HEAVY)
		. = max(., weather_storm_severe ? 20 : 14)
	else if (strength >= WEATHER_BAND_STEADY)
		. = max(., 7)

// Beaufort force 0 to 12 for a speed in m/s.
/proc/weather_beaufort(ms)
	. = 0
	for (var/edge in weather_beaufort_ms)
		if (ms < edge)
			return
		.++

/proc/weather_wind_beaufort_at(atom/A)
	return weather_beaufort(weather_wind_ms_at(A))

// The old 0 (calm) to 4 (gale) scale for a speed in m/s.
/proc/weather_wind_strength(ms)
	. = 0
	for (var/edge in weather_wind_strength_steps)
		if (ms < edge)
			return
		.++

// The compass direction (a BYOND dir) the wind over A blows from. A calm
// keeps the map's heading.
/proc/weather_wind_dir_at(atom/A)
	var/list/v = weather_wind_vector_at(A)
	return weather_wind_dir_from_vector(v[1], v[2])

/proc/weather_wind_dir_from_vector(east, north)
	if (east * east + north * north < 0.25)
		return weather_wind_from_dir(map?.winddirection)
	// It blows from the opposite way it moves.
	var/angle = arctan(-east, -north) // degrees anticlockwise from east
	var/bearing = 90 - angle
	while (bearing < 0)
		bearing += 360
	var/compass = round(bearing / 45, 1) % 8
	var/static/list/dirs = list(NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST)
	return dirs[compass + 1]

// "north-east" and so on, for players.
/proc/weather_wind_heading(dir)
	switch (dir)
		if (NORTH)
			return "north"
		if (NORTHEAST)
			return "north-east"
		if (EAST)
			return "east"
		if (SOUTHEAST)
			return "south-east"
		if (SOUTH)
			return "south"
		if (SOUTHWEST)
			return "south-west"
		if (WEST)
			return "west"
		if (NORTHWEST)
			return "north-west"
	return "west"

#undef WEATHER_WIND_GRADIENT_MS
#undef WEATHER_WIND_GRADIENT_MAX
#undef WEATHER_WIND_TURN
#undef WEATHER_WIND_SEA_BREEZE
#undef WEATHER_WIND_LAND_BREEZE
#undef WEATHER_WIND_DRAINAGE
#undef WEATHER_WIND_RATE
