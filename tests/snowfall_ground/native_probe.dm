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
