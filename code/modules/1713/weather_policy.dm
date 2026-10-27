// Optional author policy. Defaults retain the existing random weather process.
/obj/map_metadata
	var/list/weather_timing = null // Deciseconds; keys below, null inherits process values.
	var/list/weather_transitions = null // Current identifier or ANY -> allowed target identifiers.

/proc/weather_policy_identifier(value)
	switch (value)
		if (WEATHER_NONE) return "NONE"
		if (WEATHER_WET) return "WET"
		if (WEATHER_EXTREME) return "EXTREME"
		if (WEATHER_SMOG) return "SMOG"
	return null

/obj/map_metadata/proc/weather_policy_valid()
	if (!isnull(weather_timing))
		if (!islist(weather_timing) || weather_timing.len > 4)
			return FALSE
		for (var/key in weather_timing)
			if (!(key in list("mod_interval", "change_interval", "minimum_mod_delay", "minimum_change_delay")))
				return FALSE
			var/value = weather_timing[key]
			if (!isnum(value) || value < 10 || value > 864000)
				return FALSE
	if (!isnull(weather_transitions))
		if (!islist(weather_transitions) || weather_transitions.len > 5)
			return FALSE
		for (var/key in weather_transitions)
			if (!(key in list("ANY", "NONE", "WET", "EXTREME", "SMOG")))
				return FALSE
			var/list/targets = weather_transitions[key]
			if (!islist(targets) || targets.len > 4)
				return FALSE
			var/list/seen = list()
			for (var/target in targets)
				if (!(target in list("NONE", "WET", "EXTREME", "SMOG")) || (target in seen) || !isnull(targets[target]))
					return FALSE
				seen += target
	return TRUE

/obj/map_metadata/proc/weather_timing_value(key, fallback)
	if (weather_timing && (key in weather_timing))
		return weather_timing[key]
	return fallback

/obj/map_metadata/proc/weather_policy_choices(list/possibilities)
	if (!weather_policy_valid())
		return null
	if (isnull(weather_transitions))
		return possibilities
	var/current = weather_policy_identifier(weather)
	var/list/targets
	if (current in weather_transitions)
		targets = weather_transitions[current]
	else if ("ANY" in weather_transitions)
		targets = weather_transitions["ANY"]
	else
		return possibilities // Unspecified source state retains legacy selection.
	var/list/choices = list()
	for (var/candidate in possibilities)
		if ((weather_policy_identifier(candidate) in targets) && (candidate == WEATHER_NONE || (candidate in valid_weather_types)))
			choices += candidate
	return choices // Empty intersection means hold current weather, never force clear.
