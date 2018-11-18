/var/global/weather = WEATHER_NONE
/var/global/weather_intensity = 1.0

/proc/change_weather(_weather = WEATHER_NONE, var/bypass_same_weather_check = FALSE)

	if (_weather == null)
		return

	if (weather == _weather && !bypass_same_weather_check)
		return

	if (map && !(_weather in map.valid_weather_types) && _weather != WEATHER_NONE)
		return

	var/old_weather = weather
	if (season == "WINTER")
		if (weather == WEATHER_NONE)
			weather = WEATHER_SNOW
		else
			weather = WEATHER_NONE

	else if (season == "SPRING")
		if (weather == WEATHER_NONE)
			weather = WEATHER_RAIN
		else
			weather = WEATHER_NONE

	else if (season == "FALL")
		if (weather == WEATHER_NONE)
			weather = WEATHER_RAIN
		else
			weather = WEATHER_NONE
	var/area_icon = 'icons/effects/weather.dmi'
	var/area_icon_state = ""
	var/area_alpha = 255

	switch (weather)
		if (WEATHER_SNOW)
			switch (weather_intensity)
				if (1.0)
					area_icon_state = "snow1"
					area_alpha = 255
				if (2.0)
					area_icon_state = "snow2"
					area_alpha = 255
				if (3.0)
					area_icon_state = "snow3"
					area_alpha = 255
		if (WEATHER_RAIN)
			switch (weather_intensity)
				if (1.0)
					area_icon_state = "rain1"
					area_alpha = 255
				if (2.0)
					area_icon_state = "rain2"
					area_alpha = 255
				if (3.0)
					area_icon_state = "rain3"
					area_alpha = 255

	for (var/area/caribbean/A in area_list)
		if (istype(A) && A.location == AREA_OUTSIDE)
			A.icon = area_icon
			A.icon_state = area_icon_state
			A.alpha = area_alpha
			A.weather = weather
			A.weather_intensity = weather_intensity

	if (old_weather != weather)
		announce_weather_change(old_weather, weather)

/proc/modify_weather_somehow()
	if (weather == WEATHER_NONE)
		return

	var/old_intensity = weather_intensity

	if (prob(66) && weather_intensity < 3.0)
		++weather_intensity
	else if (weather_intensity > 1.0)
		--weather_intensity
	change_weather(weather, TRUE)

	if (old_intensity != weather_intensity)
		announce_weather_mod(old_intensity, weather_intensity)

/proc/change_weather_somehow()

	var/list/possibilities = list(WEATHER_NONE)
	var/list/non_possibilities = list(weather)

	switch (season)
		if ("WINTER")
			possibilities += WEATHER_SNOW
		if ("SPRING")
			possibilities += WEATHER_RAIN
		if ("FALL")
			possibilities += WEATHER_RAIN
	possibilities -= non_possibilities

	if (possibilities.len)
		change_weather(pick(possibilities))

/proc/get_weather_default(var/_weather)
	switch (_weather ? _weather : weather)
		if (WEATHER_NONE)
			return "none"
		if (WEATHER_SNOW)
			return "snow"
		if (WEATHER_RAIN)
			return "rain"
	return "none"

// global weather variable changed
/proc/announce_weather_change(var/old, var/_new)
	switch (_new)
		if (WEATHER_NONE)
			switch (old)
				if (WEATHER_NONE)
					. = ""
				if (WEATHER_SNOW, WEATHER_RAIN)
					. = "It's no longer <b>[get_weather_default(old)]ing</b>."
		if (WEATHER_SNOW, WEATHER_RAIN)
			switch (old)
				if (WEATHER_NONE)
					. = "It's now <b>[get_weather_default(_new)]ing</b>."
				if (WEATHER_SNOW,  WEATHER_RAIN)
					. = ""
	if (.)
		world << "<font size=3><span class = 'notice'>[.]</span></font>"

// global weather_intensity variable changed
/proc/announce_weather_mod(var/old, var/_new)
	. = ""
	switch (_new)
		if (1.0)
			. = "slowly"
		if (2.0)
			. = "quickly"
		if (3.0)
			. = "rapidly"

	var/weathertype = ""
	switch (weather)
		if (WEATHER_SNOW)
			weathertype = "snow"
		if (WEATHER_RAIN)
			weathertype = "rain"

	if (weather == WEATHER_NONE)
		. = ""

	if (.)
		world << "<font size=3><span class = 'notice'>[capitalize(weathertype)] is now coming down [.].</span></font>"