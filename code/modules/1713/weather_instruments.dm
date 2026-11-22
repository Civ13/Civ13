// Weather instruments by era (docs/weather-instruments.md).
//
// Each age reads more of the sky, and the better the instrument, the further
// and surer its forecast:
// - rain gauge (Bronze Working): the water fallen since it was last emptied;
// - weather vane (Primitive Construction, weather_forecast.dm): the wind, and
//   whether the sky upwind is dark;
// - thermometer and barometer (Optics & Instruments, mercury_crafts.dm): the
//   air's warmth and what it feels like; the pressure in hPa, which way it
//   is going and a storm up to a quarter of an hour off, to about five minutes;
// - hair hygrometer (Optics & Instruments): the humidity and dew point, and
//   whether dew, frost or fog will form tonight;
// - cup anemometer (Steam Power): the wind in m/s and on the Beaufort scale;
// - weather station (Electricity): all of these at once, a log of the day,
//   the storm up to half an hour off to the minute and what it will drop, and
//   the lows and highs coming in. Art by Fable 5.2
//   (tests/sprites/create_weather_station.py).

#define INSTRUMENT_RAIN_MM 0.5 // mm a weather tick (10 s) under a storm of strength 1
#define INSTRUMENT_GAUGE_MAX 200 // mm a gauge holds before it overflows
#define INSTRUMENT_TREND_STEPS 18 // the pressure tendency spans 18 weather ticks (3 minutes)
#define INSTRUMENT_BAROMETER_HORIZON 9000 // a barometer feels a quarter of an hour ahead
#define INSTRUMENT_STATION_HORIZON 18000 // a station half an hour
#define INSTRUMENT_STATION_LOG 12 // log entries a station keeps (about two days)

var/global/list/weather_instrument_list // lazy (GLOBALS RULE): every rain gauge, anemometer and station

/proc/weather_instruments()
	LAZYINITLIST(weather_instrument_list)
	return weather_instrument_list

// ---- the pressure tendency, on the air grid ------------------

/datum/weather_air_grid
	var/list/pressure_then = list() // per cell: the pressure at the last tendency mark
	var/list/pressure_tend = list() // per cell: hPa change over the last tendency span

// Each weather tick (settle in weather_air.dm): every three minutes, how far
// the pressure has moved since the last mark.
/datum/weather_air_grid/proc/settle_instruments()
	var/count = cols * rows
	if (pressure_then.len != count || pressure_tend.len != count)
		pressure_then = pressure.Copy()
		pressure_tend.len = count
		for (var/i = 1, i <= count, i++)
			pressure_tend[i] = 0
		return
	if (steps % INSTRUMENT_TREND_STEPS)
		return
	for (var/i = 1, i <= count, i++)
		pressure_tend[i] = pressure[i] - pressure_then[i]
		pressure_then[i] = pressure[i]

// hPa the pressure over A moved in the last few minutes: below 0 falling.
/proc/weather_pressure_tendency_at(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return 0
	var/datum/weather_air_grid/G = weather_air_grid()
	if (G.pressure_tend.len != G.cols * G.rows)
		return 0
	return G.value_at(G.pressure_tend, T.x, T.y)

/proc/weather_pressure_tendency_word(tend)
	var/size = abs(tend)
	if (size < 0.5)
		return "steady"
	var/way = tend < 0 ? "falling" : "rising"
	if (size < 2)
		return "[way] slowly"
	if (size < 5)
		return way
	return "[way] fast"

// ---- words for the readings ----------------------------------

/proc/weather_beaufort_name(force)
	switch (force)
		if (-INFINITY to 0)
			return "calm"
		if (1)
			return "light air"
		if (2)
			return "a light breeze"
		if (3)
			return "a gentle breeze"
		if (4)
			return "a moderate breeze"
		if (5)
			return "a fresh breeze"
		if (6)
			return "a strong breeze"
		if (7)
			return "a near gale"
		if (8)
			return "a gale"
		if (9)
			return "a strong gale"
		if (10)
			return "a storm"
		if (11)
			return "a violent storm"
	return "a hurricane-force wind"

// Minutes rounded to the nearest five, as a barometer can tell them.
/proc/weather_minutes_rough(time)
	var/minutes = round(time / 600)
	if (minutes < 5)
		return "within five minutes"
	return "in about [round(minutes, 5)] minutes"

// What a coming storm drops at A, as a station reads it from the air.
/proc/weather_precip_word(atom/A, severe)
	var/turf/T = get_turf(A)
	var/temp = T ? weather_precip_temp(T) : null
	if (isnull(temp))
		return "rain"
	if (temp < 1)
		return "snow"
	if (temp < 3)
		return "sleet"
	if (severe && temp >= 10 && weather_dew_point_at(T) >= 15)
		return "rain and hail"
	return "rain"

// TRUE when A stands out of doors under the open sky.
/proc/weather_instrument_open(atom/A)
	var/turf/T = get_turf(A)
	var/area/place = T ? T.loc : null
	return istype(place) && place.location == AREA_OUTSIDE && !(locate(/obj/roof) in T)

// ---- the barometer, in hPa ------------------------------------

// What the barometer at A says: the pressure, its tendency and a forecast a
// quarter of an hour ahead, to about five minutes.
/proc/barometer_hpa_reading(atom/A)
	var/hpa = weather_pressure_at(A)
	if (isnull(hpa))
		return barometer_reading(A)
	var/tend = weather_pressure_tendency_at(A)
	. = "The column stands at <b>[round(hpa)] hPa</b>, [weather_pressure_tendency_word(tend)]."
	var/list/forecast = weather_forecast(A, INSTRUMENT_BAROMETER_HORIZON)
	if (forecast["now"] >= WEATHER_BAND_LIGHT)
		if (forecast["clears"] >= 0)
			return "[.] This should pass [weather_minutes_rough(forecast["clears"])]."
		return "[.] This weather is staying a while."
	if (forecast["eta"] >= 0)
		var/what = forecast["severe"] ? "A severe storm" : (forecast["peak"] >= WEATHER_BAND_HEAVY ? "A heavy storm" : "Wet weather")
		return "[.] [what] should break here [weather_minutes_rough(forecast["eta"])]."
	if (forecast["heat"])
		return "[.] Hot, dry air, and no rain in sight."
	if (tend <= -2 || hpa < 1000)
		return "[.] Unsettled weather is likely later on."
	if (hpa >= 1020)
		return "[.] Settled weather: no change in the next quarter of an hour."
	return "[.] No change in the next quarter of an hour."

// ---- the thermometer, with what the air feels like --------------

// The thermometer's reading, and outdoors how the wind, damp or sun make it feel.
/proc/thermometer_feels_reading(atom/A)
	. = thermometer_reading(A)
	if (!weather_instrument_open(A))
		return
	var/temp = get_temp(A)
	var/feels = weather_feels_like_at(A)
	if (isnull(feels) || abs(feels - temp) < 2)
		return
	var/list/parts = feels_like_parts(get_turf(A), temp)
	var/why = "the sun"
	if (parts[1])
		why = "the wind"
	else if (parts[2] > parts[3])
		why = "the damp"
	return "[.] Out here [why] makes it feel like [round(feels)] degrees."

// ---- the hair hygrometer -------------------------------------

/obj/item/weapon/hygrometer
	name = "hygrometer"
	desc = "A human hair stretched over a little wheel in a wooden frame. Damp air lengthens the hair and turns the needle round the dial. Use it in your hand to read it."
	icon = 'icons/obj/weather_station.dmi'
	icon_state = "hygrometer"
	slot_flags = SLOT_BELT | SLOT_POCKET
	w_class = ITEM_SIZE_TINY
	force = WEAPON_FORCE_HARMLESS
	throwforce = WEAPON_FORCE_HARMLESS
	flammable = TRUE

// What a hygrometer at A says: humidity, dew point, and dew, frost or fog ahead.
/proc/hygrometer_reading(atom/A)
	var/turf/T = get_turf(A)
	var/rh = weather_humidity_at(T)
	var/dew = weather_dew_point_at(T)
	if (isnull(rh) || isnull(dew))
		return "The needle wavers and tells you nothing."
	. = "The needle stands at <b>[round(rh)]%</b>: the air would wet the ground below [round(dew)] degrees."
	var/level = weather_fog_level(T)
	if (level)
		return "[.] The air is full: [level] lies about."
	var/temp = weather_precip_temp(T)
	if (isnull(temp))
		return
	var/spread = temp - dew
	// From evening on, a clear, calm night cools the ground to the dew point.
	var/night_coming = time_of_day == "Evening" || time_of_day == "Night" || weather_fog_night()
	if (night_coming && spread <= 4)
		var/cloud = weather_cloud_at(T)
		if (isnull(cloud) || cloud < 0.5)
			if (dew <= 1)
				return "[.] If the sky stays clear and still, frost will whiten the ground tonight."
			if (spread <= 1.5)
				return "[.] If the sky stays clear and still, fog will gather before morning."
			return "[.] If the sky stays clear and still, dew will settle tonight."
	if (rh >= 60 && temp >= 27)
		return "[.] Air this damp and hot: sweat will not cool you."
	if (rh < 30)
		return "[.] The air is dry."

/obj/item/weapon/hygrometer/attack_self(mob/user)
	to_chat(user, SPAN_NOTICE("You hold up \the [src]. [hygrometer_reading(user)]"))

// ---- the standing instruments --------------------------------

/obj/structure/weather_instrument
	icon = 'icons/obj/weather_station.dmi'
	anchored = TRUE
	density = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/tmp/rain_mm = 0 // water caught since it was last emptied
	var/tmp/snow_mm = 0 // of that, melted from snow, sleet or hail

/obj/structure/weather_instrument/New()
	..()
	var/list/all = weather_instruments()
	all += src
	update_look()

/obj/structure/weather_instrument/Destroy()
	var/list/all = weather_instruments()
	all -= src
	return ..()

/obj/structure/weather_instrument/proc/update_look()
	return

/obj/structure/weather_instrument/proc/catches_rain()
	return FALSE

// Each weather tick: catch what falls on it.
/obj/structure/weather_instrument/proc/weather_tick()
	if (catches_rain() && weather_storm_count && rain_mm < INSTRUMENT_GAUGE_MAX && weather_instrument_open(src))
		var/turf/T = get_turf(src)
		var/strength = weather_storm_strength(T.x, T.y)
		if (strength >= WEATHER_BAND_LIGHT)
			var/kind = weather_precip_at(T)
			if (kind)
				var/mm = min(INSTRUMENT_RAIN_MM * strength, INSTRUMENT_GAUGE_MAX - rain_mm)
				rain_mm += mm
				if (kind != "rain" && kind != "drizzle" && kind != "freezing_rain")
					snow_mm += mm
	update_look()

// How much water it holds, in words.
/obj/structure/weather_instrument/proc/rain_words()
	var/mm = round(rain_mm)
	if (mm < 1)
		return rain_mm > 0 ? "a few drops" : "nothing"
	. = "[mm] mm of water"
	if (snow_mm >= rain_mm / 2)
		. += ", most of it melted snow or ice"
	if (rain_mm >= INSTRUMENT_GAUGE_MAX)
		. += ", to the brim"

/obj/structure/weather_instrument/proc/empty_rain(mob/user)
	if (rain_mm <= 0)
		return FALSE
	rain_mm = 0
	snow_mm = 0
	update_look()
	if (user)
		to_chat(user, SPAN_NOTICE("You tip the water out of \the [src]."))
	return TRUE

/proc/weather_instruments_step()
	for (var/obj/structure/weather_instrument/I in weather_instruments())
		I.weather_tick()

// ---- the rain gauge ------------------------------------------

/obj/structure/weather_instrument/rain_gauge
	name = "rain gauge"
	desc = "A bronze jar with a wide mouth, set out under the sky to catch the rain. The depth of water in it is the rain that has fallen. An empty hand tips it out."
	icon_state = "rain_gauge"
	flammable = FALSE

/obj/structure/weather_instrument/rain_gauge/catches_rain()
	return TRUE

/obj/structure/weather_instrument/rain_gauge/update_look()
	var/look = rain_mm >= 5 ? "rain_gauge_full" : "rain_gauge"
	if (icon_state != look)
		icon_state = look

/obj/structure/weather_instrument/rain_gauge/examine(mob/user)
	..()
	to_chat(user, "It holds [rain_words()] since it was last emptied.")
	if (!weather_instrument_open(src))
		to_chat(user, "Under a roof it catches nothing.")

/obj/structure/weather_instrument/rain_gauge/attack_hand(mob/user)
	if (user && !user.get_active_hand() && empty_rain(user))
		return
	return ..()

// ---- the cup anemometer --------------------------------------

/obj/structure/weather_instrument/anemometer
	name = "anemometer"
	desc = "Four cups on crossed arms, spinning on an iron pole. The faster they turn, the stronger the wind."
	icon_state = "anemometer_still"
	flammable = FALSE

/obj/structure/weather_instrument/anemometer/update_look()
	var/look = weather_instrument_open(src) && weather_wind_ms_at(src) >= 1 ? "anemometer" : "anemometer_still"
	if (icon_state != look)
		icon_state = look

// What an anemometer at A says: the speed, its Beaufort force, and the chill.
/proc/anemometer_reading(atom/A)
	if (!weather_instrument_open(A))
		return "The cups hang still. An anemometer is no use under a roof."
	var/ms = weather_wind_ms_at(A)
	var/force = weather_beaufort(ms)
	. = "The cups count <b>[round(ms, 0.1)] m/s</b> ([round(ms * 3.6)] km/h): force [force], [weather_beaufort_name(force)]."
	var/temp = get_temp(A)
	var/chill = feels_like_wind_chill(temp, ms)
	if (chill >= 1)
		return "[.] At [round(temp)] degrees this wind makes it feel like [round(temp - chill)]."

/obj/structure/weather_instrument/anemometer/examine(mob/user)
	..()
	to_chat(user, anemometer_reading(src))

// ---- the weather station -------------------------------------

/obj/structure/weather_instrument/station
	name = "weather station"
	desc = "A white louvred screen on legs that keeps the sun off a thermometer and hygrometer, with a barometer, a rain gauge and cups to count the wind. It writes the weather down as each part of the day begins. Use it with an empty hand to read its log."
	icon_state = "weather_station"
	density = TRUE
	var/tmp/list/log_lines = list()
	var/tmp/logged_at = "" // the time of day of the last log entry

/obj/structure/weather_instrument/station/catches_rain()
	return TRUE

/obj/structure/weather_instrument/station/weather_tick()
	..()
	if (!map || logged_at == time_of_day)
		return
	logged_at = time_of_day
	write_log()

// One line in the log for the part of the day just begun.
/obj/structure/weather_instrument/station/proc/write_log()
	var/turf/T = get_turf(src)
	if (!T)
		return
	var/hpa = weather_pressure_at(T)
	var/rh = weather_humidity_at(T)
	// Its gauge is read and emptied at each entry.
	var/rain = rain_mm
	rain_mm = 0
	snow_mm = 0
	var/line = "[time_of_day] ([lowertext(season)]): [round(get_temp(T))] C, [isnull(rh) ? "?" : round(rh)]% humid, [isnull(hpa) ? "?" : round(hpa)] hPa [weather_pressure_tendency_word(weather_pressure_tendency_at(T))], wind [round(weather_wind_ms_at(T))] m/s from the [weather_wind_heading(weather_wind_dir_at(T))], [round(rain, 0.1)] mm rain"
	log_lines += line
	if (log_lines.len > INSTRUMENT_STATION_LOG)
		log_lines.Cut(1, log_lines.len - INSTRUMENT_STATION_LOG + 1)

// The lows and highs about: a station hears of them a long way off.
/proc/weather_station_outlook(atom/A)
	var/turf/T = get_turf(A)
	if (!T || !weather_centres.len)
		return ""
	var/datum/weather_centre/best = null
	var/best_share = 0
	for (var/datum/weather_centre/C in weather_centres)
		var/share = C.reach_at(T.x, T.y) * C.depth
		if (share > best_share)
			best = C
			best_share = share
	if (!best || best_share < 2)
		return ""
	var/dx = best.centre_x() - T.x
	var/dy = best.centre_y() - T.y
	var/coming = (best.vel_x * -dx + best.vel_y * -dy) > 0
	var/from = weather_bearing(dx, dy)
	if (best.kind == WEATHER_CENTRE_LOW)
		if (coming)
			return "A low lies to the [from] and is coming this way: unsettled weather within the hour."
		return "A low lies to the [from], moving away."
	if (coming)
		return "High pressure is building from the [from]: settled weather ahead."
	return "High pressure lies to the [from]."

// Everything a station reads now, and the forecast half an hour ahead.
/proc/weather_station_reading(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return list()
	. = list()
	. += thermometer_feels_reading(T)
	. += hygrometer_reading(T)
	. += barometer_hpa_reading_short(T)
	. += anemometer_reading(T) + " From the [weather_wind_heading(weather_wind_dir_at(T))]."
	var/list/forecast = weather_forecast(T, INSTRUMENT_STATION_HORIZON)
	if (forecast["now"] >= WEATHER_BAND_LIGHT)
		if (forecast["clears"] >= 0)
			. += "Forecast: the [weather_precip_word(T, forecast["severe"])] overhead stops in [weather_minutes(forecast["clears"])]."
		else
			. += "Forecast: the [weather_precip_word(T, forecast["severe"])] overhead goes on for over half an hour."
	else if (forecast["eta"] >= 0)
		var/how = forecast["severe"] ? "A severe storm" : (forecast["peak"] >= WEATHER_BAND_HEAVY ? "Heavy" : (forecast["peak"] >= WEATHER_BAND_STEADY ? "Steady" : "Light"))
		. += SPAN_WARNING("Forecast: [how] [weather_precip_word(T, forecast["severe"])] from the [forecast["bearing"]] in [weather_minutes(forecast["eta"])].")
	else if (forecast["heat"])
		. += "Forecast: hot and dry, no rain in the next half hour."
	else
		. += "Forecast: no rain in the next half hour."
	var/outlook = weather_station_outlook(T)
	if (outlook)
		. += outlook

/proc/barometer_hpa_reading_short(atom/A)
	var/hpa = weather_pressure_at(A)
	if (isnull(hpa))
		return "The barometer reads nothing."
	return "The barometer stands at <b>[round(hpa, 0.1)] hPa</b>, [weather_pressure_tendency_word(weather_pressure_tendency_at(A))]."

/obj/structure/weather_instrument/station/examine(mob/user)
	..()
	if (!weather_instrument_open(src))
		to_chat(user, "Under a roof its instruments read the room, not the sky.")
		return
	for (var/line in weather_station_reading(src))
		to_chat(user, line)
	to_chat(user, "Its gauge holds [rain_words()] since [logged_at ? "the [lowertext(logged_at)] began" : "it was set up"].")

/obj/structure/weather_instrument/station/attack_hand(mob/user)
	if (!user || user.get_active_hand())
		return ..()
	if (!log_lines.len)
		to_chat(user, "The log is empty so far. It writes a line as each part of the day begins.")
		return
	to_chat(user, SPAN_NOTICE("<b>The station's log:</b>"))
	for (var/line in log_lines)
		to_chat(user, line)

#undef INSTRUMENT_RAIN_MM
#undef INSTRUMENT_GAUGE_MAX
#undef INSTRUMENT_TREND_STEPS
#undef INSTRUMENT_BAROMETER_HORIZON
#undef INSTRUMENT_STATION_HORIZON
#undef INSTRUMENT_STATION_LOG
