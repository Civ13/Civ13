// Generated snow is cover on an existing ground tile, never a guessed terrain type.
#define SNOWFALL_GROUND_BATCH 256
#define SNOWFALL_GROUND_INTERVAL 20
#define SNOWFALL_STICK_C 0
#define SNOWFALL_MELT_C 2
#define SNOWFALL_MAX_UNITS 2

var/global/list/snowfall_ground = list()
var/global/snowfall_ground_cursor = 1
var/global/snowfall_ground_next = 0
var/global/next_snowfall_ground_generation = 0

/turf
	var/weather_snow = 0 // Durable generated loose-snow units; authored snow uses available_snow.
	var/tmp/snowfall_ground_index = 0
	var/tmp/snowfall_ground_generation = 0
	var/tmp/image/weather_snow_overlay = null

/turf/proc/has_snow_cover()
	return weather_snow > 0 || icon == 'icons/turf/snow.dmi'

/turf/proc/snow_units()
	return weather_snow > 0 ? weather_snow : available_snow

/turf/proc/take_snow(expected_generation = null)
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || locate(x, y, z) != src)
		return FALSE
	if (!isnull(expected_generation) && expected_generation != snowfall_ground_generation)
		return FALSE
	if (weather_snow > 0)
		snowfall_ground_check(FALSE) // A newly lit heater can melt cover during the action wait.
		if (weather_snow <= 0)
			return FALSE
		weather_snow--
		snowfall_ground_icon()
		return TRUE
	if (available_snow <= 0)
		return FALSE
	available_snow--
	return TRUE

/turf/proc/snowfall_ground_eligible()
	return type == /turf/floor/dirt || type == /turf/floor/grass

/turf/proc/snowfall_ground_exposed()
	var/area/A = get_area(src)
	if (!istype(A, /area/caribbean) || A.location != AREA_OUTSIDE || (locate(/obj/roof) in src) || (locate(/obj/covers) in src))
		return FALSE
	// Follow only connected physical levels; unrelated map z-levels are not ceilings.
	var/turf/above = GetAbove(src)
	while (above)
		if (!istype(above, /turf/sky) && !istype(above, /turf/floor/broken_floor) && !istype(above, /turf/floor/space))
			return FALSE
		if ((locate(/obj/roof) in above) || (locate(/obj/covers) in above))
			return FALSE
		above = GetAbove(above)
	return TRUE

/turf/proc/snowfall_ground_icon()
	if (weather_snow_overlay)
		overlays -= weather_snow_overlay
	if (weather_snow > 0)
		if (!weather_snow_overlay)
			weather_snow_overlay = image('icons/turf/snow.dmi', icon_state = "snow", layer = 2.03)
			weather_snow_overlay.plane = plane
		overlays += weather_snow_overlay
	else
		weather_snow_overlay = null

/turf/proc/snowfall_ground_check(accumulate = TRUE)
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || !snowfall_ground_eligible() || locate(x, y, z) != src)
		return
	var/area/A = get_area(src)
	var/precipitation = replacetext("[A.icon_state]", "rad_", "")
	var/snowing = (A.weather == WEATHER_WET || A.weather == WEATHER_EXTREME) && A.weather_intensity > 0 && (precipitation in list("snow1", "snow2", "snow_storm"))
	if (weather_snow <= 0 && !snowing)
		return // Clear ground in dry/rain weather needs no heat or exposure query.
	var/local_c = get_temp(src) // Existing climate, weather and nearby active heat sources.
	if (local_c > SNOWFALL_MELT_C)
		weather_snow = 0
	else if (accumulate && snowing && local_c <= SNOWFALL_STICK_C && snowfall_ground_exposed())
		weather_snow = min(SNOWFALL_MAX_UNITS, weather_snow + 1)
	snowfall_ground_icon()

/turf/proc/snowfall_ground_register()
	if (!snowfall_ground_index && snowfall_ground_eligible())
		snowfall_ground += src
		snowfall_ground_index = snowfall_ground.len
		snowfall_ground_generation = ++next_snowfall_ground_generation

/turf/proc/snowfall_ground_unregister()
	if (!snowfall_ground_index)
		return
	var/last_index = snowfall_ground.len
	var/turf/last_ground = snowfall_ground[last_index]
	snowfall_ground[snowfall_ground_index] = last_ground
	last_ground.snowfall_ground_index = snowfall_ground_index
	snowfall_ground.Cut(last_index, last_index + 1)
	snowfall_ground_index = 0

// Native turf replacement calls Del; qdel cleanup may also pass Destroy.
/turf/floor/Del()
	snowfall_ground_unregister()
	..()

/turf/floor/after_load()
	..()
	weather_snow = snowfall_ground_eligible() && isnum(weather_snow) ? clamp(round(weather_snow), 0, SNOWFALL_MAX_UNITS) : 0
	snowfall_ground_register()
	if (snowfall_ground_eligible())
		snowfall_ground_generation = ++next_snowfall_ground_generation
	snowfall_ground_icon() // No weather sampling or accumulation during restore.

/turf/get_saved_vars()
	. = ..()
	if (weather_snow > 0)
		. |= "weather_snow"
