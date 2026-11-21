// Fog, mist, dew and frost (docs/weather-fog.md).
//
// Every air cell (weather_air.dm) carries a fog density from 0 to 1:
// - radiation fog: on a clear, calm night the ground cools the air to its dew
//   point; it settles thickest in valleys and lingers into the morning;
// - sea fog: moist air over the water and along the shore, by day or night,
//   while the wind stays light;
// - the sun burns it off by midday, a wind above WEATHER_FOG_WIND_CLEAR m/s
//   blows it away, and rain washes it out.
// Mist is fog of WEATHER_FOG_MIST or more; fog proper is WEATHER_FOG_THICK or
// more. Outdoors it hazes a player's view to about 10 tiles in mist and 5 in
// fog (weather_fog_view_step), takes from a lookout's range at sea
// (sea_weather.dm) and is something a naturalist can record.
//
// On a clear, calm night the ground also cools below the air: dew forms on it,
// or frost when it is near freezing (weather_dew_at, weather_frost_at).

#define WEATHER_FOG_MIST 0.3
#define WEATHER_FOG_THICK 0.65
#define WEATHER_FOG_WIND_CALM 1 // m/s: below this, fog is at its thickest
#define WEATHER_FOG_WIND_LIGHT 4 // m/s: radiation fog needs less wind than this
#define WEATHER_FOG_WIND_CLEAR 7 // m/s: any fog is blown away
#define WEATHER_FOG_GROW 0.1 // share of the gap closed each tick as fog thickens
#define WEATHER_FOG_LIFT 0.2 // and as it clears

/datum/weather_air_grid
	var/list/fog = list() // per cell, 0 to 1

// TRUE in the dark hours, when the ground cools under a clear sky.
/proc/weather_fog_night()
	return time_of_day == "Night" || time_of_day == "Dark Night" || time_of_day == "Early Morning"

// The fog a cell calls for now, 0 to 1.
/datum/weather_air_grid/proc/fog_target(i)
	var/spread = temp[i] - dew[i]
	var/wind = sqrt(wind_x[i] * wind_x[i] + wind_y[i] * wind_y[i])
	if (wind >= WEATHER_FOG_WIND_CLEAR || cloud[i] >= 0.8)
		return 0
	var/midday = time_of_day == "Midday" || time_of_day == "Afternoon"
	. = 0
	// Radiation fog: clear and calm, within two degrees of saturation.
	var/sun = weather_fog_night() ? 1 : (time_of_day == "Morning" ? 0.7 : 0)
	if (sun && cloud[i] < 0.4 && wind < WEATHER_FOG_WIND_LIGHT && spread <= 2)
		var/calm = clamp((WEATHER_FOG_WIND_LIGHT - wind) / (WEATHER_FOG_WIND_LIGHT - WEATHER_FOG_WIND_CALM), 0, 1)
		var/valley = has_heights && rise.len == temp.len && rise[i] <= -1 ? 0.25 : 0
		. = clamp((1 - spread / 2) * calm + valley, 0, 1) * sun
	// Sea fog: near-saturated air over the water or on the shore.
	if ((water[i] || shore_x[i] || shore_y[i]) && spread <= 1)
		var/sea = clamp(1 - spread, 0, 1) * clamp((WEATHER_FOG_WIND_CLEAR - wind) / 3, 0, 1)
		if (!water[i])
			sea *= 0.6
		if (midday)
			sea *= 0.5
		. = max(., sea)
	// Rain washes it out.
	. *= 1 - clamp(cloud[i] - 0.4, 0, 0.4) / 0.4

// Each weather tick, after the wind (weather_air.dm settle()).
/datum/weather_air_grid/proc/settle_fog(snap = FALSE)
	var/count = cols * rows
	if (fog.len != count)
		fog.len = count
		for (var/i = 1, i <= count, i++)
			fog[i] = 0
	if (wind_x.len != count)
		return
	for (var/i = 1, i <= count, i++)
		var/target = fog_target(i)
		if (snap)
			fog[i] = target
		else
			fog[i] += (target - fog[i]) * (target > fog[i] ? WEATHER_FOG_GROW : WEATHER_FOG_LIFT)
			if (fog[i] < 0.01)
				fog[i] = 0

// ---- per-tile readers ----------------------------------------

// Fog density 0 to 1 over A, outdoors; 0 under a roof or with no air grid.
/proc/weather_fog_at(atom/A)
	var/turf/T = get_turf(A)
	if (!T || !weather_air || weather_air.fog.len != weather_air.cols * weather_air.rows)
		return 0
	var/area/place = T.loc
	if (!istype(place) || place.location != AREA_OUTSIDE)
		return 0
	return clamp(weather_air.value_at(weather_air.fog, T.x, T.y), 0, 1)

// "fog", "mist" or "" over A.
/proc/weather_fog_level(atom/A)
	var/f = weather_fog_at(A)
	if (f >= WEATHER_FOG_THICK)
		return "fog"
	if (f >= WEATHER_FOG_MIST)
		return "mist"
	return ""

// TRUE when the open ground at A is cooling under a clear, calm night sky:
// the time dew or frost forms.
/proc/weather_ground_chill(turf/T)
	if (!T || !weather_air)
		return FALSE
	var/area/place = T.loc
	if (!istype(place) || place.location != AREA_OUTSIDE)
		return FALSE
	if (!weather_fog_night() && time_of_day != "Morning")
		return FALSE
	if (weather_storm_count && weather_storm_strength(T.x, T.y) >= WEATHER_BAND_LIGHT)
		return FALSE
	var/datum/weather_air_grid/G = weather_air
	if (G.value_at(G.cloud, T.x, T.y) >= 0.5)
		return FALSE
	var/list/v = weather_wind_vector_at(T)
	return v[1] * v[1] + v[2] * v[2] < WEATHER_FOG_WIND_LIGHT * WEATHER_FOG_WIND_LIGHT

// TRUE when dew lies on the open ground at A: a clear, calm night with the
// air within three degrees of its dew point, above freezing.
/proc/weather_dew_at(atom/A)
	var/turf/T = get_turf(A)
	if (!weather_ground_chill(T))
		return FALSE
	var/temp = weather_precip_temp(T)
	if (isnull(temp) || temp <= 1)
		return FALSE
	var/datum/weather_air_grid/G = weather_air
	return temp - G.value_at(G.dew, T.x, T.y) <= 3

// TRUE when frost whitens the open ground at A: a clear, calm night with the
// air at 2 C or below (the ground is colder than the air above it).
/proc/weather_frost_at(atom/A)
	var/turf/T = get_turf(A)
	if (!weather_ground_chill(T))
		return FALSE
	var/temp = weather_precip_temp(T)
	return !isnull(temp) && temp <= 1

// ---- the view in fog -----------------------------------------

/obj/screen/weather_fog
	name = "fog"
	icon = 'icons/effects/weather_fog.dmi'
	icon_state = "fog_view"
	// The 128 px picture centred on the player's tile, scale times as large:
	// fog covers 20 tiles each way. Under chat text and the HUD.
	screen_loc = "CENTER:-48,CENTER:-48"
	plane = CHAT_PLANE
	layer = -1
	mouse_opacity = 0
	alpha = 0
	should_save = FALSE
	var/scale = 10

/obj/screen/weather_fog/New()
	..()
	transform = matrix(scale, 0, 0, 0, scale, 0)

// Mist starts nearer, so it shows inside a small view: haze from about 5 tiles.
/obj/screen/weather_fog/mist
	name = "mist"
	icon_state = "mist_view"
	scale = 6

/client/var/tmp/obj/screen/weather_fog/weather_fog_view
/client/var/tmp/obj/screen/weather_fog/mist/weather_mist_view

// The haze tinted for the light: grey by day, dim at dusk, dark at night. It
// is drawn above the lighting, so it carries the darkness itself.
/proc/weather_fog_tint()
	switch (time_of_day)
		if ("Dark Night")
			return "#0c0e10"
		if ("Night")
			return "#1e2226"
		if ("Evening")
			return "#54585e"
		if ("Early Morning")
			return "#7c8086"
	return "#ffffff"

// Alphas for list(mist, fog) at a fog density.
/proc/weather_fog_view_alphas(f)
	return list(round(255 * clamp((f - 0.25) / 0.2, 0, 1)), round(255 * clamp((f - 0.55) / 0.25, 0, 1)))

// Each drawing step (2 s), haze the view of everyone living out in fog or mist.
/proc/weather_fog_view_step()
	var/tint = weather_fog_tint()
	for (var/client/C in clients)
		var/f = 0
		var/mob/M = C.mob
		if (isliving(M) && C.eye == M)
			f = weather_fog_at(M)
		if (!f && !C.weather_fog_view)
			continue
		if (!C.weather_fog_view)
			C.weather_fog_view = new
			C.weather_mist_view = new
		var/list/alphas = weather_fog_view_alphas(f)
		weather_fog_view_set(C, C.weather_mist_view, alphas[1], tint)
		weather_fog_view_set(C, C.weather_fog_view, alphas[2], tint)

/proc/weather_fog_view_set(client/C, obj/screen/weather_fog/V, alpha, tint)
	if (alpha <= 0)
		if (V.alpha)
			animate(V, alpha = 0, time = 15)
		else
			C.screen -= V
		return
	C.screen |= V
	// A change of thickness fades in 1.5 s; a change of light alone over 5 s.
	if (V.alpha != alpha)
		animate(V, alpha = alpha, color = tint, time = 15)
	else if (V.color != tint)
		animate(V, color = tint, time = 50)

#undef WEATHER_FOG_MIST
#undef WEATHER_FOG_THICK
#undef WEATHER_FOG_WIND_CALM
#undef WEATHER_FOG_WIND_LIGHT
#undef WEATHER_FOG_WIND_CLEAR
#undef WEATHER_FOG_GROW
#undef WEATHER_FOG_LIFT
