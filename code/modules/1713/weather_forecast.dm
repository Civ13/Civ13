// ============================================================
// Reading the weather ahead (docs/weather-systems.md, "Forecasting")
// ------------------------------------------------------------
// The storms in the sky are a few numbers each, so where one will be in ten
// minutes is the same sum as where it is now. A forecast asks every storm
// for its strength over a tile at steps ahead and reports the first that
// arrives. It supposes the wind holds: a storm that comes round to a new
// wind makes the forecast wrong, as it should.
//
// Players read it from a weather vane (the wind, and the sky upwind), a
// barometer (how soon, and how bad) and the Farmer's Almanac.
// ============================================================

#define FORECAST_STEP 300 // look ahead in half minutes
#define FORECAST_HORIZON 9000 // a barometer feels fifteen minutes ahead

// The system's strength over a place, this many deciseconds from now, if it
// keeps its course.
/datum/weather_system/proc/strength_in(x, y, ahead)
	var/age = world.time + ahead - born
	if (age < 0 || age >= lifetime)
		return 0
	var/cx = centre_x() + vel_x * ahead
	var/cy = centre_y() + vel_y * ahead
	var/dx = (x - cx) / radius_x
	if (dx >= 1.1 || dx <= -1.1)
		return 0
	var/dy = (y - cy) / radius_y
	var/reach = dx * dx + dy * dy
	if (reach >= 1.21)
		return 0
	var/d = sqrt(reach) + 0.08 * sin((x - cx) * 9 + (y - cy) * 5 + wobble)
	if (d >= 1)
		return 0
	return peak * min(1, age / 600, (lifetime - age) / 1200) * min(1, (1 - d) * 2.5)

// What the sky holds for a tile. Returns a list:
//   "now"     strength of the storm overhead, 0 to 1
//   "eta"     deciseconds until a storm breaks here, or -1 for none in sight
//   "clears"  deciseconds until the storm overhead has gone, or -1
//   "peak"    the worst strength expected within the horizon
//   "severe"  TRUE if the storm coming, or overhead, is a severe one
//   "bearing" where the coming storm is now, as "north", "southwest"...
//   "heat"    TRUE under a heat system now
/proc/weather_forecast(atom/A, horizon = FORECAST_HORIZON)
	var/list/result = list("now" = 0, "eta" = -1, "clears" = -1, "peak" = 0, "severe" = FALSE, "bearing" = "", "heat" = FALSE)
	var/turf/T = get_turf(A)
	if (!T || !weather_systems.len)
		return result
	result["heat"] = weather_heat_at(T)
	for (var/datum/weather_system/S in weather_systems)
		if (S.kind != WEATHER_SYSTEM_STORM)
			continue
		var/now = S.strength_in(T.x, T.y, 0)
		if (now > result["now"])
			result["now"] = now
		var/arrives = -1
		var/leaves = -1
		var/worst = now
		for (var/ahead = FORECAST_STEP, ahead <= horizon, ahead += FORECAST_STEP)
			var/strength = S.strength_in(T.x, T.y, ahead)
			if (strength > worst)
				worst = strength
			if (strength >= WEATHER_BAND_LIGHT)
				if (arrives < 0)
					arrives = ahead
				leaves = -1
			else if (leaves < 0)
				leaves = ahead
		if (worst > result["peak"])
			result["peak"] = worst
			result["severe"] = S.severe
		if (now >= WEATHER_BAND_LIGHT)
			// Overhead: the forecast is when it lets up.
			if (leaves > result["clears"])
				result["clears"] = leaves
		else if (arrives >= 0 && (result["eta"] < 0 || arrives < result["eta"]))
			result["eta"] = arrives
			result["bearing"] = weather_bearing(S.centre_x() - T.x, S.centre_y() - T.y)
	return result

/proc/weather_minutes(time)
	var/minutes = max(1, round(time / 600, 1))
	return "[minutes] minute[minutes == 1 ? "" : "s"]"

/proc/weather_wind_word(strength)
	switch (strength)
		if (-INFINITY to 0)
			return "calm"
		if (1)
			return "a light breeze"
		if (2)
			return "a fresh wind"
		if (3)
			return "a strong wind"
	return "a gale"

// The state of open water at a tile, from the wind over it.
/proc/weather_sea_state(atom/A)
	switch (weather_wind_at(A))
		if (-INFINITY to 1)
			return "calm"
		if (2)
			return "choppy"
		if (3)
			return "rough"
	return "raging"

// One plain sentence of forecast, as the almanac prints it.
/proc/weather_forecast_line(atom/A)
	var/list/forecast = weather_forecast(A)
	if (forecast["now"] >= WEATHER_BAND_LIGHT)
		if (forecast["clears"] >= 0)
			return "The [forecast["severe"] ? "storm" : "weather"] overhead should pass in about [weather_minutes(forecast["clears"])]."
		return "The [forecast["severe"] ? "storm" : "weather"] overhead has settled in for a while yet."
	if (forecast["eta"] >= 0)
		return "[forecast["severe"] ? "A severe storm" : (forecast["peak"] >= WEATHER_BAND_HEAVY ? "A heavy storm" : "Wet weather")] is coming from the [forecast["bearing"]], about [weather_minutes(forecast["eta"])] away."
	if (forecast["heat"])
		return "A heat wave lies over this place, and no rain is in sight."
	return "No change is in sight."

// ---- the weather vane ---------------------------------------

var/global/list/weather_vanes = list()

/obj/structure/weather_vane
	name = "weather vane"
	desc = "An iron arrow on a wooden post, free to swing. Its head points into the wind."
	icon = 'icons/obj/weather_instruments.dmi'
	icon_state = "weather_vane_east"
	anchored = TRUE
	density = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/weather_vane/New()
	..()
	weather_vanes += src
	turn_to_wind()

/obj/structure/weather_vane/Destroy()
	weather_vanes -= src
	return ..()

/obj/structure/weather_vane/proc/sheltered()
	var/area/place = get_area(src)
	return !istype(place) || place.location != AREA_OUTSIDE

/obj/structure/weather_vane/proc/turn_to_wind()
	if (!map || sheltered())
		return
	var/look = "weather_vane_[lowertext(map.winddirection)]"
	if (icon_state != look)
		icon_state = look

/obj/structure/weather_vane/examine(mob/user)
	..()
	if (!map)
		return
	if (sheltered())
		to_chat(user, "It hangs still. A weather vane is no use under a roof.")
		return
	to_chat(user, "The wind is from the <b>[lowertext(map.winddirection)]</b>: [weather_wind_word(weather_wind_at(src))].")
	var/list/forecast = weather_forecast(src)
	if (forecast["now"] >= WEATHER_BAND_LIGHT)
		return
	// A vane is only eyes on the sky: it tells what is upwind, not when.
	if (forecast["eta"] >= 0)
		to_chat(user, SPAN_WARNING("The sky to the [forecast["bearing"]] is dark, and the wind is bringing it this way."))
	else
		to_chat(user, "The sky upwind is clear.")

// Called each weather tick: every vane out of doors swings to the wind.
/proc/weather_vanes_turn()
	for (var/obj/structure/weather_vane/V in weather_vanes)
		V.turn_to_wind()

// ---- the barometer ------------------------------------------

/obj/item/weapon/barometer
	name = "barometer"
	desc = "A brass dial that feels the weight of the air. A falling needle means a storm is on its way."
	icon = 'icons/obj/weather_instruments.dmi'
	icon_state = "barometer"
	slot_flags = SLOT_BELT | SLOT_POCKET | SLOT_ID
	w_class = ITEM_SIZE_TINY
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS

// What the needle says at a place, in one sentence.
/proc/barometer_reading(atom/A)
	var/list/forecast = weather_forecast(A)
	if (forecast["now"] >= WEATHER_BAND_LIGHT)
		if (forecast["clears"] >= 0)
			return "The needle is low but rising: this should pass in about [weather_minutes(forecast["clears"])]."
		return "The needle is low and steady: this weather is staying a while."
	if (forecast["eta"] >= 0)
		var/how = "falling"
		var/what = "Wet weather"
		if (forecast["severe"])
			how = "dropping fast"
			what = "A severe storm"
		else if (forecast["peak"] >= WEATHER_BAND_HEAVY)
			how = "falling steadily"
			what = "A heavy storm"
		return "The needle is [how]. [what] should break here in about [weather_minutes(forecast["eta"])]."
	if (forecast["heat"])
		return "The needle is high and still: hot, dry air, and no rain in sight."
	return "The needle is steady: no change in the next quarter of an hour."

/obj/item/weapon/barometer/attack_self(mob/user)
	to_chat(user, SPAN_NOTICE("You tap the glass of \the [src]. [barometer_reading(user)]"))

/obj/item/weapon/barometer/examine(mob/user)
	..()
	to_chat(user, "Use it in your hand to read it.")

#undef FORECAST_STEP
#undef FORECAST_HORIZON
