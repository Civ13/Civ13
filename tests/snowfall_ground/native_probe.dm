// Source only: no world/New override or automatic invocation. A future isolated
// full-game harness must call this after its own admission/containment review.
/proc/snowfall_ground_native_probe(turf/floor/T)
	var/list/results = list()
	if (!T || !T.snowfall_ground_eligible())
		return list("rejected_fixture" = TRUE)
	var/old_units = T.weather_snow
	var/old_dirt = T.available_dirt
	var/old_type = T.type
	T.weather_snow = 2
	T.snowfall_ground_icon()
	results["predicate"] = T.has_snow_cover() && T.snow_units() == 2
	T.snowfall_ground_icon()
	results["owned_overlay"] = T.weather_snow_overlay && (T.weather_snow_overlay in T.overlays)
	results["durable_units"] = "weather_snow" in T.get_saved_vars()
	results["runtime_fields"] = T.persistence_runtime_var("weather_snow_overlay") && T.persistence_runtime_var("snowfall_ground_index")
	T.after_load()
	results["no_reload_accrual"] = T.weather_snow == 2
	results["substrate"] = T.type == old_type && T.available_dirt == old_dirt
	T.weather_snow = old_units
	T.snowfall_ground_icon()
	return results

// Future harness supplies an isolated exact dirt turf with get_temp(T) <= 0,
// no persistence operation, and owns cleanup. This is not a player wait test.
/proc/snowfall_generated_shovel_native_probe(turf/floor/dirt/T)
	if (!T || T.type != /turf/floor/dirt || get_temp(T) > 0 || persistence_active_operation || persistence_save_in_progress)
		return list("rejected_fixture" = TRUE)
	var/old_units = T.weather_snow
	var/old_soil = T.soil_nutrition
	var/old_dirt = T.available_dirt
	var/old_contents = T.contents.len
	var/generation = T.snowfall_ground_generation
	T.weather_snow = 2
	var/list/results = list()
	results["first_unit"] = T.take_snow(generation) && T.weather_snow == 1
	results["last_unit"] = T.take_snow(generation) && !T.has_snow_cover()
	results["no_repeat_yield"] = !T.take_snow(generation)
	results["same_substrate"] = T.type == /turf/floor/dirt && T.soil_nutrition == old_soil && T.available_dirt == old_dirt && T.contents.len == old_contents
	T.weather_snow = 1
	T.after_load()
	results["old_wait_rejected"] = !T.take_snow(generation) && T.weather_snow == 1
	T.weather_snow = old_units
	T.snowfall_ground_icon()
	return results
