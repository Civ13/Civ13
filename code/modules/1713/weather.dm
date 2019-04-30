/var/global/weather = WEATHER_NONE
/var/global/weather_intensity = 1.0

/proc/change_weather(_weather = WEATHER_NONE, var/bypass_same_weather_check = FALSE)

	if (_weather == null)
		return

	if (weather == _weather && !bypass_same_weather_check)
		return

	if (map && !(_weather in map.valid_weather_types) && _weather != WEATHER_NONE)
		return

//	var/old_weather = weather
	if (season == "WINTER")
		if (_weather == WEATHER_NONE)
			weather = WEATHER_NONE

		else if (_weather == WEATHER_BLIZZARD)
			weather = WEATHER_BLIZZARD
		else if (_weather == WEATHER_SNOW)
			weather = WEATHER_SNOW
		else if (_weather == WEATHER_RAIN)
			weather = WEATHER_RAIN
		else if (_weather == WEATHER_STORM)
			weather = WEATHER_STORM
		else if (_weather == WEATHER_SMOG)
			weather = WEATHER_SMOG
		else
			weather = WEATHER_NONE

	else if (season == "SPRING")
		if (_weather == WEATHER_NONE)
			weather = WEATHER_NONE
		else if (_weather == WEATHER_RAIN)
			weather = WEATHER_RAIN
		else if (_weather == WEATHER_SNOW)
			weather = WEATHER_SNOW
		else if (_weather == WEATHER_STORM)
			weather = WEATHER_STORM
		else if (_weather == WEATHER_SMOG)
			weather = WEATHER_SMOG
		else
			weather = WEATHER_NONE
	else if (season == "FALL")
		if (_weather == WEATHER_NONE)
			weather = WEATHER_NONE
		else if (_weather == WEATHER_SNOW)
			weather = WEATHER_SNOW
		else if (_weather == WEATHER_RAIN)
			weather = WEATHER_RAIN
		else if (_weather == WEATHER_SMOG)
			weather = WEATHER_SMOG
		else if (_weather == WEATHER_SANDSTORM)
			weather = WEATHER_SANDSTORM
		else
			weather = WEATHER_NONE

	else if (season == "SUMMER")
		if (_weather == WEATHER_NONE)
			weather = WEATHER_NONE
		else if (_weather == WEATHER_SNOW)
			weather = WEATHER_SNOW
		else if (_weather == WEATHER_RAIN)
			weather = WEATHER_RAIN
		else if (_weather == WEATHER_SANDSTORM)
			weather = WEATHER_SANDSTORM
		else if (_weather == WEATHER_SMOG)
			weather = WEATHER_SMOG
		else
			weather = WEATHER_NONE

	else if (season == "Wet Season")
		if (map.ID == MAP_NOMADS_DESERT)
			if (_weather == WEATHER_RAIN)
				weather = WEATHER_RAIN
			else if (_weather == WEATHER_NONE)
				weather = WEATHER_NONE
			else if (_weather == WEATHER_SMOG)
				weather = WEATHER_SMOG
			else
				weather = WEATHER_NONE
		else
			if (_weather == WEATHER_RAIN)
				weather = WEATHER_RAIN
			else if (_weather == WEATHER_STORM)
				weather = WEATHER_STORM
			else if (_weather == WEATHER_NONE)
				weather = WEATHER_NONE
			else if (_weather == WEATHER_SMOG)
				weather = WEATHER_SMOG
			else
				weather = WEATHER_NONE

	else if (season == "Dry Season")
		if (map.ID == MAP_NOMADS_DESERT)
			if (_weather == WEATHER_SANDSTORM)
				weather = WEATHER_SANDSTORM
			else if (_weather == WEATHER_NONE)
				weather = WEATHER_NONE
			else if (_weather == WEATHER_SMOG)
				weather = WEATHER_SMOG
			else
				weather = WEATHER_NONE
		else
			if (_weather == WEATHER_SANDSTORM)
				weather = WEATHER_SANDSTORM
			else if (_weather == WEATHER_NONE)
				weather = WEATHER_NONE
			else if (_weather == WEATHER_SMOG)
				weather = WEATHER_SMOG
			else
				weather = WEATHER_NONE
	var/area_icon_state = ""

	switch (weather)
		if (WEATHER_SNOW)
			switch (weather_intensity)
				if (1.0)
					area_icon_state = "snow1"
				if (2.0)
					area_icon_state = "snow2"
				if (3.0)
					area_icon_state = "snow3"
		if (WEATHER_RAIN)
			switch (weather_intensity)
				if (1.0)
					area_icon_state = "rain1"
				if (2.0)
					area_icon_state = "rain2"
				if (3.0)
					area_icon_state = "rain3"
		if (WEATHER_BLIZZARD)
			switch (weather_intensity)
				if (1.0)
					area_icon_state = "snow_storm"
				if (2.0)
					area_icon_state = "snow_storm"

				if (3.0)
					area_icon_state = "snow_storm"

		if (WEATHER_SANDSTORM)
			switch (weather_intensity)
				if (1.0)
					area_icon_state = "sandstorm"

				if (2.0)
					area_icon_state = "sandstorm"

				if (3.0)
					area_icon_state = "sandstorm"

		if (WEATHER_STORM)
			switch (weather_intensity)
				if (1.0)
					area_icon_state = "monsoon"

				if (2.0)
					area_icon_state = "monsoon"

				if (3.0)
					area_icon_state = "monsoon"

		if (WEATHER_SMOG)
			area_icon_state = "smog"


	if (map.civilizations)
		for (var/area/caribbean/A in area_list)
			if (istype(A) && A.location == AREA_OUTSIDE)
				if (A.climate == "tundra")
					if (season == "Wet Season" || season == "WINTER" ||  season == "FALL" || season == "SPRING")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "snow_storm"
							A.weather = WEATHER_BLIZZARD
							A.weather_intensity = weather_intensity
						else if (weather == WEATHER_RAIN || weather == WEATHER_SNOW)
							A.icon_state = "snow2"
							A.weather = WEATHER_SNOW
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = WEATHER_NONE
							A.weather_intensity = weather_intensity
					else if (season == "Dry Season" || season == "SUMMER")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "snow1"
							A.weather = WEATHER_SNOW
							A.weather_intensity = weather_intensity

						else if (weather == WEATHER_RAIN || weather == WEATHER_SNOW)
							A.icon_state = "snow2"
							A.weather = WEATHER_SNOW
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = WEATHER_NONE
							A.weather_intensity = weather_intensity

				else if (A.climate == "taiga")
					if (season == "Wet Season" || season == "WINTER" ||  season == "FALL")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "snow_storm"
							A.weather = WEATHER_BLIZZARD
							A.weather_intensity = weather_intensity
						else if (weather == WEATHER_RAIN || weather == WEATHER_SNOW)
							A.icon_state = "snow2"
							A.weather = WEATHER_SNOW
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = WEATHER_NONE
							A.weather_intensity = weather_intensity

					else if (season == "Dry Season" || season == "SUMMER" || season == "SPRING")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "snow1"
							A.weather = WEATHER_SNOW
							A.weather_intensity = weather_intensity

						else if (weather == WEATHER_RAIN || weather == WEATHER_SNOW)
							A.icon_state = ""
							A.weather = WEATHER_NONE
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = WEATHER_NONE
							A.weather_intensity = weather_intensity

				else if (A.climate == "jungle")
					if (season == "Wet Season" || season == "WINTER" || season == "SPRING")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "monsoon"
							A.weather = WEATHER_STORM
							A.weather_intensity = weather_intensity
						else if (weather == WEATHER_RAIN || weather == WEATHER_SNOW)
							A.icon_state = "rain3"
							A.weather = WEATHER_RAIN
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = weather
							A.weather_intensity = weather_intensity
					else if (season == "Dry Season" || season == "SUMMER" ||  season == "FALL")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = ""
							A.weather = WEATHER_NONE
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = weather
							A.weather_intensity = weather_intensity

				else if (A.climate == "savanna")
					if (season == "Wet Season" || season == "WINTER" || season == "SPRING")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "rain3"
							A.weather = WEATHER_STORM
							A.weather_intensity = 3
						else if (weather == WEATHER_RAIN || weather == WEATHER_SNOW)
							A.icon_state = "rain2"
							A.weather = WEATHER_RAIN
							A.weather_intensity = 2
						else
							A.icon_state = ""
							A.weather = weather
							A.weather_intensity = weather_intensity
					else if (season == "Dry Season" || season == "SUMMER" ||  season == "FALL")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = ""
							A.weather = WEATHER_NONE
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = weather
							A.weather_intensity = weather_intensity

				else if (A.climate == "desert")
					if (season == "Dry Season" || season == "SUMMER" ||  season == "FALL")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "sandstorm"
							A.weather = WEATHER_SANDSTORM
							A.weather_intensity = weather_intensity
						else if (weather == WEATHER_SNOW || weather == WEATHER_RAIN || weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = ""
							A.weather = WEATHER_NONE
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = weather
							A.weather_intensity = weather_intensity
					else if (season == "Wet Season" || season == "WINTER" || season == "SPRING")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = ""
							A.weather = WEATHER_NONE
							A.weather_intensity = weather_intensity
						else if (weather == WEATHER_RAIN || weather == WEATHER_SNOW)
							A.icon_state = "rain1"
							A.weather = WEATHER_RAIN
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = weather
							A.weather_intensity = weather_intensity

				else if (A.climate == "sea")
					if (season == "Wet Season" || season == "WINTER" ||  season == "FALL")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "monsoon"
							A.weather = WEATHER_STORM
							A.weather_intensity = weather_intensity
						else if (weather == WEATHER_RAIN || weather == WEATHER_SNOW)
							A.icon_state = "rain1"
							A.weather = WEATHER_RAIN
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = weather
							A.weather_intensity = weather_intensity
					else if (season == "Dry Season" || season == "SUMMER" || season == "SPRING")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "rain2"
							A.weather = WEATHER_RAIN
							A.weather_intensity = weather_intensity
						else if (weather == WEATHER_SNOW || weather == WEATHER_RAIN)
							A.icon_state = "rain2"
							A.weather = WEATHER_RAIN
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = weather
							A.weather_intensity = weather_intensity
				else if (A.climate == "semiarid")
					if (season == "Wet Season" || season == "WINTER" ||  season == "FALL")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "rain3"
							A.weather = WEATHER_RAIN
							A.weather_intensity = 3
						else if (weather == WEATHER_RAIN || weather == WEATHER_SNOW)
							A.icon_state = "rain1"
							A.weather = WEATHER_RAIN
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = weather
							A.weather_intensity = weather_intensity
					else if (season == "Dry Season" || season == "SUMMER" || season == "SPRING")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = ""
							A.weather = WEATHER_NONE
							A.weather_intensity = weather_intensity
						else if (weather == WEATHER_SNOW || weather == WEATHER_RAIN)
							A.icon_state = "rain1"
							A.weather = WEATHER_RAIN
							A.weather_intensity = 1
						else
							A.icon_state = ""
							A.weather = weather
							A.weather_intensity = weather_intensity
				else if (A.climate == "temperate")
					if (season == "Wet Season" || season == "WINTER")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "snow_storm"
							A.weather = WEATHER_BLIZZARD
							A.weather_intensity = weather_intensity
						else if (weather == WEATHER_SNOW || weather == WEATHER_RAIN)
							A.icon_state = "snow2"
							A.weather = WEATHER_SNOW
							A.weather_intensity = weather_intensity
						else
							A.icon_state = ""
							A.weather = WEATHER_NONE
							A.weather_intensity = weather_intensity
					else if (season == "Dry Season"|| season == "FALL" || season == "SPRING")
						if (weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
							A.icon_state = "rain2"
							A.weather = WEATHER_RAIN
							A.weather_intensity = weather_intensity
						else if (weather == WEATHER_SNOW || weather == WEATHER_RAIN)
							A.icon_state = "rain2"
							A.weather = WEATHER_RAIN
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
	else
		for (var/area/caribbean/A in area_list)
			if (istype(A) && A.location == AREA_OUTSIDE)
				A.icon_state = area_icon_state
				A.weather = weather
				A.weather_intensity = weather_intensity
/*
	if (old_weather != weather)
		announce_weather_change(old_weather, weather)
*/
/proc/modify_weather_somehow()
	if (weather == WEATHER_NONE)
		return

	var/old_intensity = weather_intensity

	if (prob(66) && weather_intensity < 3.0)
		++weather_intensity
	else if (weather_intensity > 1.0)
		--weather_intensity
	if (map.blizzard)
		weather_intensity = 3.0
	change_weather(weather, TRUE)

	if (old_intensity != weather_intensity)
		announce_weather_mod(old_intensity, weather_intensity)

/proc/change_weather_somehow()

	var/list/possibilities = list(WEATHER_NONE)

	switch (season)
		if ("WINTER")
			possibilities = list(WEATHER_BLIZZARD, WEATHER_RAIN, WEATHER_SNOW, WEATHER_NONE, WEATHER_STORM)
		if ("SPRING")
			possibilities = list(WEATHER_RAIN, WEATHER_NONE, WEATHER_STORM, WEATHER_SNOW)
		if ("Wet Season")
			if (map.ID == MAP_NOMADS_DESERT)
				possibilities = list(WEATHER_RAIN,WEATHER_NONE)
			else
				possibilities = list(WEATHER_RAIN,WEATHER_NONE, WEATHER_STORM)
		if ("Dry Season")
			if (map.ID == MAP_NOMADS_DESERT)
				possibilities = list(WEATHER_NONE,WEATHER_SANDSTORM)
			else
				possibilities = list(WEATHER_NONE,WEATHER_SANDSTORM)
		if ("SUMMER")
			possibilities = list(WEATHER_NONE,WEATHER_RAIN,WEATHER_SANDSTORM)
		if ("FALL")
			possibilities = list(WEATHER_RAIN,WEATHER_SNOW,WEATHER_NONE)
	if (map)
		if (map.pollutionmeter >= 2000)
			possibilities += WEATHER_SMOG
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
		if (WEATHER_BLIZZARD)
			return "blizzard"
		if (WEATHER_SANDSTORM)
			return "sandstorm"
		if (WEATHER_STORM)
			return "storm"
		if (WEATHER_SMOG)
			return "smog"
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
				if (WEATHER_BLIZZARD)
					. = "The <b>blizzard</b> has passed."
				if ( WEATHER_SANDSTORM)
					. = "The <b>sandstorm</b> has passed."
				if ( WEATHER_STORM)
					. = "The <b>storm</b> has passed."
		if (WEATHER_SNOW, WEATHER_RAIN)
			switch (old)
				if (WEATHER_NONE)
					. = "It's now <b>[get_weather_default(_new)]ing</b>."
				if (WEATHER_SNOW,  WEATHER_RAIN)
					. = ""
		if (WEATHER_SANDSTORM)
			switch (old)
				if (WEATHER_NONE)
					. = "A <b>sandstorm</b> has begun."
				if (WEATHER_SANDSTORM)
					. = ""
		if (WEATHER_BLIZZARD)
			switch (old)
				if (WEATHER_NONE)
					. = "A <b>blizzard</b> has begun."
				if (WEATHER_BLIZZARD)
					. = ""
		if (WEATHER_STORM)
			switch (old)
				if (WEATHER_NONE, WEATHER_RAIN)
					. = "A <b>storm</b> has begun."
				if (WEATHER_STORM)
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
		if (WEATHER_SANDSTORM)
			weathertype = "sandstorm"
		if (WEATHER_BLIZZARD)
			weathertype = "blizzard"
		if (WEATHER_STORM)
			weathertype = "storm"
	if (weather == WEATHER_NONE)
		. = ""

	if (.)
		if (weathertype != "sandstorm" && weathertype != "blizzard" && weathertype != "storm")
			world << "<font size=3><span class = 'notice'>[capitalize(weathertype)] is now coming down [.].</span></font>"