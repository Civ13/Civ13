/var/global/weather = WEATHER_NONE
/var/global/weather_intensity = 1.0
/var/global/world_pollution = 0.0
/var/global/world_radiation = 0.0

/proc/change_global_radiation(amount)
	world_radiation += amount

/proc/set_global_radiation(amount)
	world_radiation = amount

/proc/get_global_radiation()
	return world_radiation

/proc/change_global_pollution(amount)
	world_pollution += amount

/proc/set_global_pollution(amount)
	world_pollution = amount

/proc/get_global_pollution()
	return world_pollution

/proc/change_weather(_weather = WEATHER_NONE, var/bypass_same_weather_check = FALSE)

	if (_weather == null)
		return

	if (weather == _weather && !bypass_same_weather_check)
		return

	if (map && !(_weather in map.valid_weather_types) && _weather != WEATHER_NONE)
		return

//	var/old_weather = weather
	if (_weather == WEATHER_NONE)
		weather = WEATHER_NONE
	else if (_weather == WEATHER_EXTREME)
		weather = WEATHER_EXTREME
	else if (_weather == WEATHER_WET)
		weather = WEATHER_WET
	else if (_weather == WEATHER_SMOG)
		weather = WEATHER_SMOG
	else
		weather = WEATHER_NONE

	for (var/area/caribbean/A in area_list)
		if (istype(A) && A.location == AREA_OUTSIDE)
			if (A.climate == "tundra")
				if (season == "Wet Season" || season == "WINTER" ||  season == "FALL" || season == "SPRING")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "snow_storm"
						A.weather = WEATHER_EXTREME
						A.weather_intensity = weather_intensity
					else if (weather == WEATHER_WET)
						A.icon_state = "snow2"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity
				else if (season == "Dry Season" || season == "SUMMER")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "snow1"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity

					else if (weather == WEATHER_WET)
						A.icon_state = "snow2"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity

			else if (A.climate == "taiga")
				if (season == "Wet Season" || season == "WINTER" ||  season == "FALL")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "snow_storm"
						A.weather = WEATHER_EXTREME
						A.weather_intensity = weather_intensity
					else if (weather == WEATHER_WET)
						A.icon_state = "snow2"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity

				else if (season == "Dry Season" || season == "SUMMER" || season == "SPRING")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "snow1"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity

					else if (weather == WEATHER_WET)
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity

			else if (A.climate == "jungle")
				if (season == "Wet Season" || season == "WINTER" || season == "SPRING")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "monsoon"
						A.weather = WEATHER_EXTREME
						A.weather_intensity = weather_intensity
					else if (weather == WEATHER_WET)
						A.icon_state = "rain3"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = weather
						A.weather_intensity = weather_intensity
				else if (season == "Dry Season" || season == "SUMMER" ||  season == "FALL")
					if (weather == WEATHER_EXTREME)
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = weather
						A.weather_intensity = weather_intensity

			else if (A.climate == "savanna")
				if (season == "Wet Season" || season == "WINTER" || season == "SPRING")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "rain3"
						A.weather = WEATHER_EXTREME
						A.weather_intensity = 3
					else if (weather == WEATHER_WET)
						A.icon_state = "rain2"
						A.weather = WEATHER_WET
						A.weather_intensity = 2
					else
						A.icon_state = ""
						A.weather = weather
						A.weather_intensity = weather_intensity
				else if (season == "Dry Season" || season == "SUMMER" ||  season == "FALL")
					if (weather == WEATHER_EXTREME)
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = weather
						A.weather_intensity = weather_intensity

			else if (A.climate == "desert")
				if (season == "Dry Season" || season == "SUMMER" ||  season == "FALL")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "sandstorm"
						A.weather = WEATHER_EXTREME
						A.weather_intensity = weather_intensity
					else if (weather == WEATHER_WET)
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = weather
						A.weather_intensity = weather_intensity
				else if (season == "Wet Season" || season == "WINTER" || season == "SPRING")
					if (weather == WEATHER_EXTREME)
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity
					else if (weather == WEATHER_WET)
						A.icon_state = "rain1"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = weather
						A.weather_intensity = weather_intensity

			else if (A.climate == "sea")
				if (season == "Wet Season" || season == "WINTER" ||  season == "FALL")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "monsoon"
						A.weather = WEATHER_EXTREME
						A.weather_intensity = weather_intensity
					else if (weather == WEATHER_WET)
						A.icon_state = "rain1"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = weather
						A.weather_intensity = weather_intensity
				else if (season == "Dry Season" || season == "SUMMER" || season == "SPRING")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "rain2"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else if (weather == WEATHER_WET)
						A.icon_state = "rain2"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = weather
						A.weather_intensity = weather_intensity
			else if (A.climate == "semiarid")
				if (season == "Wet Season" || season == "WINTER" ||  season == "FALL")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "rain3"
						A.weather = WEATHER_WET
						A.weather_intensity = 3
					else if (weather == WEATHER_WET)
						A.icon_state = "rain1"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = weather
						A.weather_intensity = weather_intensity
				else if (season == "Dry Season" || season == "SUMMER" || season == "SPRING")
					if (weather == WEATHER_EXTREME)
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity
					else if (weather == WEATHER_WET)
						A.icon_state = "rain1"
						A.weather = WEATHER_WET
						A.weather_intensity = 1
					else
						A.icon_state = ""
						A.weather = weather
						A.weather_intensity = weather_intensity
			else if (A.climate == "temperate")
				if (season == "Wet Season" || season == "WINTER")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "snow_storm"
						A.weather = WEATHER_EXTREME
						A.weather_intensity = weather_intensity
					else if (weather == WEATHER_WET)
						A.icon_state = "snow2"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity
				else if (season == "Dry Season"|| season == "FALL" || season == "SPRING")
					if (weather == WEATHER_EXTREME)
						A.icon_state = "rain2"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else if (weather == WEATHER_WET)
						A.icon_state = "rain2"
						A.weather = WEATHER_WET
						A.weather_intensity = weather_intensity
					else
						A.icon_state = ""
						A.weather = WEATHER_NONE
						A.weather_intensity = weather_intensity
				else if (season == "SUMMER")
					A.icon_state = ""
					A.weather = WEATHER_NONE
					A.weather_intensity = weather_intensity
			else
				A.icon_state = ""
				A.weather = WEATHER_NONE
				A.weather_intensity = weather_intensity
			if (world_radiation >= 300)
				A.icon_state = "rad_[A.icon_state]"

/*
	if (old_weather != weather)
		announce_weather_change(old_weather, weather)
*/
/proc/modify_weather_somehow()
	if (weather == WEATHER_NONE)
		return

	if (prob(66) && weather_intensity < 3.0)
		++weather_intensity
	else if (weather_intensity > 1.0)
		--weather_intensity
	if (map.blizzard)
		weather_intensity = 3.0
	change_weather(weather, TRUE)

/proc/change_weather_somehow()

	var/list/possibilities = list(WEATHER_NONE)

	switch (season)
		if ("WINTER")
			possibilities = list(WEATHER_EXTREME, WEATHER_WET, WEATHER_NONE)
		if ("SPRING")
			possibilities = list(WEATHER_WET, WEATHER_NONE, WEATHER_EXTREME)
		if ("Wet Season")
			if (map.ID == MAP_NOMADS_DESERT)
				possibilities = list(WEATHER_WET,WEATHER_NONE)
			else
				possibilities = list(WEATHER_WET,WEATHER_NONE, WEATHER_EXTREME)
		if ("Dry Season")
			possibilities = list(WEATHER_NONE,WEATHER_EXTREME)
		if ("SUMMER")
			possibilities = list(WEATHER_NONE,WEATHER_WET,WEATHER_EXTREME)
		if ("FALL")
			possibilities = list(WEATHER_WET,WEATHER_NONE)
	if (map)
		if (map.pollutionmeter >= 2000)
			possibilities += WEATHER_SMOG
	if (possibilities.len)
		change_weather(pick(possibilities))

/proc/get_temp(var/atom/A) //gets the local (area-based) temperature
	var/loc_temp = 20
	if (!A)
		return loc_temp
	var/area/mob_area = get_area(A)

	if (!mob_area)
		return loc_temp

	switch (season)
		if ("WINTER")
			switch (mob_area.climate)
				if ("temperate")
					loc_temp = -29
				if ("sea")
					loc_temp = -11
				if ("tundra")
					loc_temp = -60
				if ("taiga")
					loc_temp = -53
				if ("semiarid")
					loc_temp = 0
				if ("desert")
					loc_temp = 32
				if ("jungle")
					loc_temp = 30
				if ("savanna")
					loc_temp = 27

		if ("FALL")
			switch (mob_area.climate)
				if ("temperate")
					loc_temp = 7
				if ("sea")
					loc_temp = 11
				if ("tundra")
					loc_temp = -50
				if ("taiga")
					loc_temp = -35
				if ("semiarid")
					loc_temp = 12
				if ("desert")
					loc_temp = 34
				if ("jungle")
					loc_temp = 32
				if ("savanna")
					loc_temp = 29

		if ("SUMMER")
			switch (mob_area.climate)
				if ("temperate")
					loc_temp = 30
				if ("sea")
					loc_temp = 23
				if ("tundra")
					loc_temp = -25
				if ("taiga")
					loc_temp = -10
				if ("semiarid")
					loc_temp = 35
				if ("desert")
					loc_temp = 50
				if ("jungle")
					loc_temp = 40
				if ("savanna")
					loc_temp = 35

		if ("SPRING")
			switch (mob_area.climate)
				if ("temperate")
					loc_temp = 10
				if ("sea")
					loc_temp = 14
				if ("tundra")
					loc_temp = -35
				if ("taiga")
					loc_temp = -15
				if ("semiarid")
					loc_temp = 28
				if ("desert")
					loc_temp = 40
				if ("jungle")
					loc_temp = 34
				if ("savanna")
					loc_temp = 29
		if ("Dry Season")
			loc_temp = 45
		if ("Wet Season")
			loc_temp = 30


	switch (time_of_day)
		if ("Midday")
			loc_temp *= 1.03
		if ("Afternoon")
			loc_temp *= 1.02
		if ("Morning")
			loc_temp *= 1.01
		if ("Evening")
			loc_temp *= 1.00 // default
		if ("Early Morning")
			loc_temp *= 0.99
		if ("Night")
			loc_temp *= 0.97

	switch (mob_area.weather)
		if (WEATHER_NONE)
			loc_temp *= 1.00
		if (WEATHER_WET)
			switch (mob_area.weather_intensity)
				if (1.0)
					loc_temp *= 0.94
				if (2.0)
					loc_temp *= 0.93
				if (3.0)
					loc_temp *= 0.92
		if (WEATHER_EXTREME)
			if (mob_area.icon_state == "snow_storm")
				loc_temp = -82
			else if (mob_area.icon_state == "sandstorm")
				loc_temp = 60
	loc_temp = round(loc_temp)

	//inside areas have natural insulation, so the temp will be more moderate than outside.
	if (mob_area.location == AREA_INSIDE)
		if (loc_temp > 22)
			loc_temp = (max(22,loc_temp-40))
		else if (loc_temp < 10)
			loc_temp = (min(10,loc_temp+40))
		if (mob_area.weather == WEATHER_EXTREME && season == "WINTER" && (mob_area.climate == "temperate" || mob_area.climate == "taiga" || mob_area.climate == "tundra"))
			loc_temp = -10

	for (var/obj/structure/brazier/BR in range(3, src))
		if (BR.on == TRUE)
			if (loc_temp < 22)
				loc_temp = 22
				break
	for (var/obj/structure/heatsource/HS in range(3, src))
		if (HS.on == TRUE)
			if (loc_temp < 22)
				loc_temp = 22
				break
	for (var/obj/structure/oven/fireplace/FP in range(1, src))
		if (FP.on == TRUE)
			if (loc_temp < 22)
				loc_temp = 22
				break
	return loc_temp