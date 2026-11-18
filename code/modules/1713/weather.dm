/var/global/weather = WEATHER_NONE
/var/global/weather_intensity = 1.0
/var/global/environment_weather_running = FALSE
/var/global/environment_weather_revision = 0

/var/global/global_radiation = 0.0
/var/global/global_pollution = 0.0

/proc/change_global_radiation(amount)
	global_radiation += amount

/proc/set_global_radiation(amount)
	global_radiation = amount

/proc/get_global_radiation()
	return global_radiation

/proc/change_global_pollution(amount)
	global_pollution += amount

/proc/set_global_pollution(amount)
	global_pollution = amount

/proc/get_global_pollution()
	return global_pollution

/proc/change_weather(_weather = WEATHER_NONE, var/bypass_same_weather_check = FALSE)
#ifdef CIV13_ZONE_PERSISTENCE
	if(persistence_area_registry_blocked()) return FALSE
#endif

	if (_weather == null)
		return

	if (weather == _weather && !bypass_same_weather_check)
		return

	if (map && !(_weather in map.valid_weather_types) && _weather != WEATHER_NONE)
		return

//	var/old_weather = weather
	switch (_weather)
		if (WEATHER_NONE) weather = WEATHER_NONE
		if (WEATHER_EXTREME) weather = WEATHER_EXTREME
		if (WEATHER_WET) weather = WEATHER_WET
		if (WEATHER_SMOG) weather = WEATHER_SMOG
		else weather = WEATHER_NONE

	environment_weather_revision++
	weather_sample_time = -1 // the per-tile answer may be a tick old (weather_systems.dm)
	if (environment_weather_running)
		return
	environment_weather_running = TRUE
	try
		while (TRUE)
			var/revision = environment_weather_revision
			var/work = 0
#ifdef CIV13_ZONE_PERSISTENCE
			var/datum/persistence_area_registry_epoch/registry_epoch = persistence_area_epoch
#endif
			for (var/area/caribbean/A in area_list)
#ifdef CIV13_ZONE_PERSISTENCE
				if(persistence_area_registry_blocked()) throw EXCEPTION("Weather registry became unavailable during load")
#endif
				apply_area_weather(A)
				if (environment_sweep_pause(++work))
					work = 0
#ifdef CIV13_ZONE_PERSISTENCE
					require_persistence_area_snapshot(registry_epoch)
#endif
					if (revision != environment_weather_revision)
						break
			if (revision == environment_weather_revision)
				break
	catch (var/exception/E)
		environment_weather_running = FALSE
		throw E
	environment_weather_running = FALSE

// What a climate makes of a weather class in the current season: the look
// (a precipitation icon state or ""), the local class and its intensity.
// Zone weather and moving weather systems both read this one table.
/proc/climate_weather_state(climate, weather, weather_intensity)
	var/look = ""
	var/local = WEATHER_NONE
	var/strength = weather_intensity
	switch (climate)
		if ("tundra")
			switch (season)
				if ("Wet Season", "WINTER", "FALL", "SPRING")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "snow_storm"
							local = WEATHER_EXTREME
							strength = weather_intensity
						if (WEATHER_WET)
							look = "snow2"
							local = WEATHER_WET
							strength = weather_intensity
						else
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity
				if ("Dry Season", "SUMMER")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "snow1"
							local = WEATHER_WET
							strength = weather_intensity
						if (WEATHER_WET)
							look = "snow2"
							local = WEATHER_WET
							strength = weather_intensity
						else
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity

		if ("taiga")
			switch (season)
				if ("Wet Season", "WINTER", "FALL")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "snow_storm"
							local = WEATHER_EXTREME
							strength = weather_intensity
						if (WEATHER_WET)
							look = "snow2"
							local = WEATHER_WET
							strength = weather_intensity
						else
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity

				if ("Dry Season", "SUMMER", "SPRING")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "snow1"
							local = WEATHER_WET
							strength = weather_intensity
						if (WEATHER_WET)
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity
						else
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity
		if ("jungle")
			switch (season)
				if ("Wet Season", "WINTER", "SPRING")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "monsoon"
							local = WEATHER_EXTREME
							strength = weather_intensity
						if (WEATHER_WET)
							look = "rain3"
							local = WEATHER_WET
							strength = weather_intensity
						else
							look = ""
							local = weather
							strength = weather_intensity
				if ("Dry Season", "SUMMER", "FALL")
					switch (weather)
						if (WEATHER_EXTREME)
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity
						else
							look = ""
							local = weather
							strength = weather_intensity

		if ("savanna")
			switch (season)
				if ("Wet Season", "WINTER", "SPRING")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "rain3"
							local = WEATHER_EXTREME
							strength = 3
						if (WEATHER_WET)
							look = "rain2"
							local = WEATHER_WET
							strength = 2
						else
							look = ""
							local = weather
							strength = weather_intensity
				if ("Dry Season", "SUMMER", "FALL")
					switch (weather)
						if (WEATHER_EXTREME)
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity
						else
							look = ""
							local = weather
							strength = weather_intensity

		if ("desert")
			switch (season)
				if ("Dry Season", "SUMMER", "FALL")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "sandstorm"
							local = WEATHER_EXTREME
							strength = weather_intensity
						if (WEATHER_WET)
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity
						else
							look = ""
							local = weather
							strength = weather_intensity
				if ("Wet Season", "WINTER", "SPRING")
					switch (weather)
						if (WEATHER_EXTREME)
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity
						if (WEATHER_WET)
							look = "rain1"
							local = WEATHER_WET
							strength = weather_intensity
						else
							look = ""
							local = weather
							strength = weather_intensity

		if ("sea")
			switch (season)
				if ("Wet Season", "WINTER", "FALL")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "monsoon"
							local = WEATHER_EXTREME
							strength = weather_intensity
						if (WEATHER_WET)
							look = "rain1"
							local = WEATHER_WET
							strength = weather_intensity
						else
							look = ""
							local = weather
							strength = weather_intensity
				if ("Dry Season", "SUMMER", "SPRING")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "rain2"
							local = WEATHER_WET
							strength = weather_intensity
						if (WEATHER_WET)
							look = "rain2"
							local = WEATHER_WET
							strength = weather_intensity
						else
							look = ""
							local = weather
							strength = weather_intensity
		if ("semiarid")
			switch (season)
				if ("Wet Season", "WINTER", "FALL")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "rain3"
							local = WEATHER_WET
							strength = 3
						if (WEATHER_WET)
							look = "rain1"
							local = WEATHER_WET
							strength = weather_intensity
						else
							look = ""
							local = weather
							strength = weather_intensity
				if ("Dry Season", "SUMMER", "SPRING")
					switch (weather)
						if (WEATHER_EXTREME)
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity
						if (WEATHER_WET)
							look = "rain1"
							local = WEATHER_WET
							strength = 1
						else
							look = ""
							local = weather
							strength = weather_intensity
		if ("temperate")
			switch (season)
				if ("Wet Season", "WINTER")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "snow_storm"
							local = WEATHER_EXTREME
							strength = weather_intensity
						if (WEATHER_WET)
							look = "snow2"
							local = WEATHER_WET
							strength = weather_intensity
						else
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity
				if ("Dry Season", "FALL", "SPRING")
					switch (weather)
						if (WEATHER_EXTREME)
							look = "rain2"
							local = WEATHER_WET
							strength = weather_intensity
						if (WEATHER_WET)
							look = "rain2"
							local = WEATHER_WET
							strength = weather_intensity
						else
							look = ""
							local = WEATHER_NONE
							strength = weather_intensity
				if ("SUMMER")
					look = ""
					local = WEATHER_NONE
					strength = weather_intensity
		else
			look = ""
			local = WEATHER_NONE
			strength = weather_intensity
	return list(look, local, strength)

/proc/apply_area_weather(var/area/caribbean/A)
#ifdef CIV13_ZONE_PERSISTENCE
	if(persistence_area_registry_blocked()) return
#endif
	if (!istype(A) || A.location != AREA_OUTSIDE)
		return
	var/list/state = climate_weather_state(A.climate, weather, weather_intensity)
	A.icon_state = state[1]
	A.weather = state[2]
	A.weather_intensity = state[3]
	/*
	if (global_pollution >= 2000)
		if (map.nomads || map.civilizations )
			A.icon_state = "fog"
			A.weather = WEATHER_SMOG
	*/
	if (global_radiation >= 300)
		A.icon_state = "rad_[A.icon_state]"
/*
	if (old_weather != weather)
		announce_weather_change(old_weather, weather)
*/
/// Returns TRUE if the given area icon_state represents precipitation
/// (rain, snow, monsoon) that would soak an MDF wand.
/proc/is_wet_weather_icon(var/icon_state_str)
	if (copytext(icon_state_str, 1, 5) == "rad_")
		icon_state_str = copytext(icon_state_str, 5)
	switch (icon_state_str)
		if ("rain", "rain1", "rain2", "rain3", "monsoon", "snow1", "snow2", "snow_storm")
			return TRUE
	return FALSE

/proc/modify_weather_somehow()
	if (map && !map.weather_policy_valid())
		return
	if (weather == WEATHER_NONE)
		return

	if (prob(66) && weather_intensity < 3.0)
		++weather_intensity
	else if (weather_intensity > 1.0)
		--weather_intensity
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
			possibilities = list(WEATHER_NONE,WEATHER_WET)
		if ("FALL")
			possibilities = list(WEATHER_WET,WEATHER_NONE)
	/*
	if (map)
		if (global_pollution >= 2000)
			if (map.nomads || map.civilizations )
				possibilities += WEATHER_SMOG
	*/
	if (map)
		possibilities = map.weather_policy_choices(possibilities)
	if (possibilities && possibilities.len)
		weather_roll(pick(possibilities))

/proc/get_temp(var/atom/A) //gets the local (area-based) temperature
	var/loc_temp = 20
	if (!A)
		return loc_temp
	var/area/mob_area = get_area(A)

	if (!mob_area)
		return loc_temp

	// The climate's air at this time of year and day (climate_normals.dm).
	loc_temp = climate_air_temperature(A, mob_area)

	// Underground the earth holds a steady cool temperature: no weather
	// reaches it, and the season only moves it a little.
	if (turf_in_cool_cellar(A))
		loc_temp = cool_cellar_temperature(loc_temp)
		var/datum/building_room/cellar_room = building_room_at(get_turf(A))
		if (cellar_room && cellar_room.heat > 0)
			loc_temp = round(loc_temp + (22 - loc_temp) * cellar_room.heat)
		var/mob/living/human/cellar_human = A
		if (istype(cellar_human) ? cellar_human.life_nearby_heat() : nearby_heat_source(A))
			loc_temp = max(loc_temp, 22)
		return loc_temp

	// The weather on this tile: a storm overhead or pinned zone weather.
	var/local_weather = weather_at(A)
	loc_temp += climate_weather_offset(A)
	// High ground is colder: hills from the terrain height file, plus any
	// authored geographic elevation (elevation_climate.dm).
	loc_temp -= elevation_temperature_drop(A)
	loc_temp = round(loc_temp)

	// A roofed room holds warmth by how well its walls, doors and windows
	// insulate it (building_insulation.dm); a bare roof only breaks the wind.
	var/datum/building_room/room = null
	if (mob_area.location == AREA_INSIDE)
		room = building_room_at(get_turf(A))
		var/shelter = room ? room.moderation() : 5
		if (loc_temp > 22)
			loc_temp = (max(22,loc_temp-shelter))
		else if (loc_temp < 10)
			loc_temp = (min(10,loc_temp+shelter))
		if ((!room || room.draughty) && local_weather == WEATHER_EXTREME && season == SEASON_WINTER && (mob_area.climate == "temperate" || mob_area.climate == "taiga" || mob_area.climate == "tundra"))
			loc_temp = min(loc_temp, -10)
		if (loc_temp < 19 && map && map.ID == MAP_ANTARCTICA)
			for (var/obj/structure/oven/big/FN in range(5, A))
				if (FN.on)
					if (loc_temp < 19)
						loc_temp = 19
						break
	if (loc_temp < 22)
		// A fire in the room warms it as far as the room can hold the heat.
		if (room && room.heat > 0)
			loc_temp = round(loc_temp + (22 - loc_temp) * room.heat)
		// A human asks every Life tick; it remembers the answer for its tile for 3 seconds.
		var/mob/living/human/H = A
		if (istype(H) ? H.life_nearby_heat() : nearby_heat_source(A))
			loc_temp = 22

	return loc_temp

// A lit brazier or heat source within 2 tiles, or a lit fireplace or running engine next to A.
/proc/nearby_heat_source(var/atom/A)
	for (var/obj/structure/brazier/BR in range(2, A))
		if (BR.on)
			return TRUE
	for (var/obj/structure/heatsource/HS in range(2, A))
		if (HS.on)
			return TRUE
	for (var/obj/structure/oven/fireplace/FP in range(1, A))
		if (FP.on)
			return TRUE
	for (var/obj/structure/engine/EN in range(1, A))
		if (EN.on)
			return TRUE
	return FALSE

// The seven range scans behind get_temp() and near_drying_fire() were a tenth of
// every human Life tick. A human standing on one tile repeats them every 3 seconds
// instead of every second; stepping onto another tile scans again at once.
#define LIFE_HEAT_SCAN_INTERVAL 30
/mob/living/human/var/tmp/turf/life_heat_scan_turf = null
/mob/living/human/var/tmp/life_heat_scan_until = 0
/mob/living/human/var/tmp/life_heat_scan_warm = null
/mob/living/human/var/tmp/life_heat_scan_drying = null

/mob/living/human/proc/life_heat_scan_current()
	var/turf/T = loc
	if (!isturf(T))
		return FALSE
	if (T != life_heat_scan_turf || world.time >= life_heat_scan_until)
		life_heat_scan_turf = T
		life_heat_scan_until = world.time + LIFE_HEAT_SCAN_INTERVAL
		life_heat_scan_warm = null
		life_heat_scan_drying = null
	return TRUE

/mob/living/human/proc/life_nearby_heat()
	if (!life_heat_scan_current())
		return nearby_heat_source(src)
	if (isnull(life_heat_scan_warm))
		life_heat_scan_warm = nearby_heat_source(src)
	return life_heat_scan_warm

/mob/living/human/proc/life_near_drying_fire()
	if (!life_heat_scan_current())
		return near_drying_fire(get_turf(src))
	if (isnull(life_heat_scan_drying))
		life_heat_scan_drying = near_drying_fire(life_heat_scan_turf)
	return life_heat_scan_drying
#undef LIFE_HEAT_SCAN_INTERVAL
