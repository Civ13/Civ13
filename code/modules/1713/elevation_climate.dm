// Elevation temperature coupling (docs/elevation.md). Default off: every map's
// lapse rate is 0, so get_temp() and snowfall are unchanged until a map opts in.
// A map that authors elevation regions can set a lapse rate, typically 6.5 C
// per km, to make its high ground colder; rain over cold enough high ground
// then settles as snow there through the same local resolver.

/obj/map_metadata
	var/elevation_lapse_c_per_km = 0

/proc/elevation_lapse_valid(value)
	return isnum(value) && value >= 0 && value <= 10

// Celsius to subtract at this atom's physical turf; negative below sea level.
/proc/elevation_temperature_drop(atom/A)
	if (!map || !elevation_lapse_valid(map.elevation_lapse_c_per_km) || map.elevation_lapse_c_per_km == 0)
		return 0
	return map.elevation_lapse_c_per_km * get_elevation(A) / 1000

// Shared geographic precipitation resolver for one turf: "snow" when the area
// is snowing, or when it is raining but elevation has cooled this spot to the
// sticking point; otherwise "rain", or null when nothing is falling.
/proc/local_precipitation(turf/T, stick_c = 0)
	var/area/A = get_area(T)
	if (!A || !(A.weather == WEATHER_WET || A.weather == WEATHER_EXTREME) || A.weather_intensity <= 0)
		return null
	var/state = replacetext("[A.icon_state]", "rad_", "")
	if (state in list("snow1", "snow2", "snow_storm"))
		return "snow"
	if (findtext(state, "rain") || findtext(state, "monsoon"))
		if (elevation_temperature_drop(T) > 0 && get_temp(T) <= stick_c)
			return "snow"
		return "rain"
	return null
