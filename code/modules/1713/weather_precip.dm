// Precipitation types (docs/weather-precip.md).
//
// The climate table (climate_weather_state in weather.dm) still says how much
// a storm drops over a climate in a season. What falls is now settled by the
// air on the tile (weather_air.dm, plus hill cooling):
// - rain at 3 C and above, drizzle when it is light in near-saturated air;
// - sleet from 1 to 3 C;
// - snow below 1 C;
// - freezing rain at 0 C or below under the warm air ahead of a low (warm air
//   aloft melts the snow, which refreezes on the cold ground) - it glazes the
//   ground with ice for a while;
// - hail in the heavy core of a severe thunderstorm in warm air.
// Hills lift the air: storms drop more on slopes facing the wind and less in
// the rain shadow behind them.
//
// The look readers (weather_look_at) keep their old words, so floods, rain
// barrels, rain gear and snow on the ground need no change: sleet, freezing
// rain, drizzle and hail look like rain; snow looks like snow.
// weather_precip_at() names the type for anything that cares.

#define WEATHER_SNOW_BELOW 1
#define WEATHER_RAIN_FROM 3
#define WEATHER_HAIL_FROM 10
#define WEATHER_GLAZE_TIME 6000 // ten minutes of ice after freezing rain
#define WEATHER_HAIL_HURT_PROB 50

var/global/weather_storm_convective = FALSE // set with weather_storm_severe

/datum/weather_system
	var/convective = FALSE // built in place on a hot afternoon (weather_fronts.dm)

/datum/weather_air_grid
	var/list/lift = list() // per cell: share of a storm's rain that falls here, from hills
	var/list/glaze_until = list() // per cell: world.time the ground stays iced to

// The air temperature on a tile, with hill cooling; null with no air grid.
/proc/weather_precip_temp(turf/T)
	if (!T || !weather_air)
		return null
	var/datum/weather_air_grid/G = weather_air
	return G.value_at(G.temp, T.x, T.y) - terrain_temperature_drop(T)

// What falls at this temperature: "rain", "drizzle", "sleet", "freezing_rain",
// "snow" or "hail".
/proc/weather_precip_kind(temp, intensity, warm_aloft, convective, severe, strength, humidity)
	if (convective && severe && strength >= WEATHER_BAND_HEAVY && temp >= WEATHER_HAIL_FROM)
		return "hail"
	if (temp <= 0 && warm_aloft)
		return "freezing_rain"
	if (temp < WEATHER_SNOW_BELOW)
		return "snow"
	if (temp < WEATHER_RAIN_FROM)
		return "sleet"
	if (intensity <= 1 && !convective && humidity >= 90)
		return "drizzle"
	return "rain"

// A storm state, list(look, class, intensity), turned into what actually
// falls on the tile: list(look, class, intensity, kind). Sandstorms and
// cloud stay as they are, and so does everything before the air grid exists.
/proc/weather_precip_adjust(list/state, turf/T, strength)
	if (!state || !T)
		return state
	var/look = state[1]
	if (!look || look == "sandstorm" || !weather_air)
		return state
	var/temp = weather_precip_temp(T)
	if (isnull(temp))
		return state
	var/intensity = state[3]
	var/class = state[2]
	var/warm_aloft = weather_centres_temperature_at(T.x, T.y) >= 1
	var/humidity = weather_relative_humidity(weather_air.value_at(weather_air.temp, T.x, T.y), weather_air.value_at(weather_air.dew, T.x, T.y))
	var/kind = weather_precip_kind(temp, intensity, warm_aloft, weather_storm_convective, weather_storm_severe, strength, humidity)
	var/heavy = intensity >= 3 || class == WEATHER_EXTREME
	switch (kind)
		if ("snow")
			if (findtext(look, "snow"))
				return list(look, class, intensity, kind)
			if (heavy && weather_storm_severe)
				return list("snow_storm", WEATHER_EXTREME, 3, kind)
			return list(intensity >= 2 ? "snow2" : "snow1", WEATHER_WET, intensity, kind)
		if ("sleet")
			return list(intensity >= 2 ? "rain2" : "rain1", WEATHER_WET, min(intensity, 2), kind)
		if ("hail")
			return list("rain3", WEATHER_WET, 3, kind)
	// Rain of some kind: keep a rain look, melt a snow one.
	if (findtext(look, "snow"))
		if (look == "snow_storm")
			return list("rain3", WEATHER_WET, 3, kind)
		return list(look == "snow2" ? "rain2" : "rain1", WEATHER_WET, intensity, kind)
	return list(look, class, intensity, kind)

// The kind of precipitation on A: "" when nothing falls, else "rain",
// "drizzle", "sleet", "freezing_rain", "snow" or "hail".
/proc/weather_precip_at(atom/A)
	weather_sample(A)
	if (weather_sample_kind)
		return weather_sample_kind
	var/look = weather_sample_look
	if (!look || look == "sandstorm" || weather_sample_class == WEATHER_SMOG)
		return ""
	return findtext(look, "snow") ? "snow" : "rain"

// ---- hills and glaze, each weather tick ---------------------

/datum/weather_air_grid/proc/settle_precip()
	var/count = cols * rows
	if (lift.len != count)
		lift.len = count
		glaze_until.len = count
		for (var/i = 1, i <= count, i++)
			lift[i] = 1
			glaze_until[i] = 0
	for (var/row = 0, row < rows, row++)
		var/y = row * 16 + 8
		for (var/col = 0, col < cols, col++)
			var/i = index(col, row)
			// Air pushed up a slope drops more; air coming down the far side dries out.
			if (has_heights && slope_x.len == count)
				var/up = wind_x[i] * slope_x[i] + wind_y[i] * slope_y[i]
				lift[i] = clamp(1 + 0.04 * up, 0.6, 1.5)
			else
				lift[i] = 1
			if (temp[i] > WEATHER_SNOW_BELOW)
				glaze_until[i] = 0
				continue
			if (!weather_storm_count)
				continue
			var/x = col * 16 + 8
			if (weather_storm_strength(x, y) >= WEATHER_BAND_LIGHT && temp[i] <= 0 && weather_centres_temperature_at(x, y) >= 1)
				glaze_until[i] = world.time + WEATHER_GLAZE_TIME

// Share of a storm's rain that reaches x, y: more on windward slopes, less
// in a rain shadow. 1 on flat maps.
/proc/weather_orographic_at(x, y)
	if (!weather_air || !weather_air.has_heights || weather_air.lift.len != weather_air.cols * weather_air.rows)
		return 1
	return weather_air.value_at(weather_air.lift, x, y)

// TRUE where freezing rain has left the open ground iced over.
/proc/weather_glazed_at(turf/T)
	if (!T || !weather_air || weather_air.glaze_until.len != weather_air.cols * weather_air.rows)
		return FALSE
	var/area/A = T.loc
	if (!istype(A) || A.location != AREA_OUTSIDE)
		return FALSE
	if (istype(T, /turf/floor/beach/water) || istype(T, /turf/wall))
		return FALSE
	var/datum/weather_air_grid/G = weather_air
	var/list/b = G.blend_at(T.x, T.y)
	// The nearest cell decides.
	var/best = 2
	for (var/k = 4, k <= 8, k += 2)
		if (b[k] > b[best])
			best = k
	return G.glaze_until[b[best - 1]] > world.time && G.temp[b[best - 1]] <= WEATHER_SNOW_BELOW

// ---- hail ---------------------------------------------------

// TRUE when what is on H's head stops hailstones.
/proc/weather_hail_proof(mob/living/human/H)
	var/obj/item/clothing/head/hat = H.head
	if (!istype(hat))
		return FALSE
	if (istype(hat, /obj/item/clothing/head/helmet))
		return TRUE
	return hat.armor && hat.armor["melee"] >= 20

// Each weather tick, hail stings everyone out under it without a helmet.
/proc/weather_hail_step()
	if (!weather_storm_count || !weather_air)
		return
	for (var/client/C in clients)
		var/mob/living/human/H = C.mob
		if (istype(H))
			weather_hail_strike(H)

// One tick of hail on H: "blocked" by a helmet, "hit", or null when no hail
// reaches them or it missed.
/proc/weather_hail_strike(mob/living/human/H, chance = WEATHER_HAIL_HURT_PROB)
	if (!istype(H) || H.stat == DEAD)
		return null
	var/turf/T = get_turf(H)
	var/area/A = T ? T.loc : null
	if (!istype(A) || A.location != AREA_OUTSIDE)
		return null
	if (weather_precip_at(T) != "hail")
		return null
	if (weather_hail_proof(H))
		if (prob(30))
			to_chat(H, SPAN_NOTICE("Hailstones rattle off your [H.head.name]."))
		return "blocked"
	if (!prob(chance))
		return null
	H.apply_damage(rand(1, 3), BRUTE, "head", 0, used_weapon = "hailstones")
	to_chat(H, SPAN_WARNING("Hailstones pelt your head! Get under a roof or put on a helmet."))
	return "hit"

#undef WEATHER_SNOW_BELOW
#undef WEATHER_RAIN_FROM
#undef WEATHER_HAIL_FROM
#undef WEATHER_GLAZE_TIME
#undef WEATHER_HAIL_HURT_PROB
