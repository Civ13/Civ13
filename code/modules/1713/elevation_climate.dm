// Elevation temperature coupling (docs/elevation.md). Hills from a terrain
// height file always cool the air. Authored geographic elevation is opt-in:
// every map's lapse rate is 0 until it sets one, typically 6.5 C per km. Rain
// over cold enough high ground then settles as snow there through the same
// local resolver.

/obj/map_metadata
	var/elevation_lapse_c_per_km = 0

/proc/elevation_lapse_valid(value)
	return isnum(value) && value >= 0 && value <= 10

// Hills from a map's terrain height file (terrain_height.dm) cool the air at
// the standard 6.5 C per km. A hill level stands for 50 metres, so the top
// level (31.5) is about 10 C colder than the shore.
#define TERRAIN_LEVEL_METRES 50
#define TERRAIN_LAPSE_C_PER_KM 6.5

/proc/terrain_temperature_drop(atom/A)
	var/turf/T = get_turf(A)
	if (!T || !map || !map.terrain_height_file)
		return 0
	return terrain_height_at(T) * TERRAIN_LEVEL_METRES * TERRAIN_LAPSE_C_PER_KM / 1000

#undef TERRAIN_LEVEL_METRES
#undef TERRAIN_LAPSE_C_PER_KM

// Celsius to subtract at this atom's physical turf; negative below sea level.
// Hills always count; authored geographic elevation counts on maps that set a
// lapse rate.
/proc/elevation_temperature_drop(atom/A)
	. = terrain_temperature_drop(A)
	if (!map || !elevation_lapse_valid(map.elevation_lapse_c_per_km) || map.elevation_lapse_c_per_km == 0)
		return
	. += map.elevation_lapse_c_per_km * get_elevation(A) / 1000

// Shared geographic precipitation resolver for one turf: "snow" when the area
// is snowing, or when it is raining but elevation has cooled this spot to the
// sticking point; otherwise "rain", or null when nothing is falling.
/proc/local_precipitation(turf/T, stick_c = 0)
	var/area/A = get_area(T)
	if (!A || weather_intensity_at(T) <= 0)
		return null
	var/state = weather_look_at(T)
	if (state in list("snow1", "snow2", "snow_storm"))
		return "snow"
	if (findtext(state, "rain") || findtext(state, "monsoon"))
		if (elevation_temperature_drop(T) > 0 && get_temp(T) <= stick_c)
			return "snow"
		return "rain"
	return null
