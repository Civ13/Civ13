/process/weather
	var/mod_weather_interval = 3500
	var/change_weather_interval = 3500

	var/minimum_mod_weather_delay = 1000
	var/minimum_change_weather_delay = 1000

	var/next_can_mod_weather = -1
	var/next_can_change_weather = -1

	var/enabled = TRUE

/process/weather/setup()
	name = "weather"
	schedule_interval = 10 SECONDS
	start_delay = 2 SECONDS
	next_can_mod_weather = world.realtime + 100
	next_can_change_weather = world.realtime + 12000
	fires_at_gamestates = list(GAME_STATE_PLAYING)
	priority = PROCESS_PRIORITY_IRRELEVANT
	processes.weather = src

/process/weather/fire()
	if(persistence_save_in_progress) return
	weather_systems_step()
	// Author policy gates random selection only, not independent event service.
	if (!map || map.weather_policy_valid())
		var/mod_interval = map ? map.weather_timing_value("mod_interval", mod_weather_interval) : mod_weather_interval
		var/change_interval = map ? map.weather_timing_value("change_interval", change_weather_interval) : change_weather_interval
		var/mod_delay = map ? map.weather_timing_value("minimum_mod_delay", minimum_mod_weather_delay) : minimum_mod_weather_delay
		var/change_delay = map ? map.weather_timing_value("minimum_change_delay", minimum_change_weather_delay) : minimum_change_weather_delay
		var/prob_of_weather_mod = (25*schedule_interval)/mod_interval
		// A wide map is rolled more often: each roll sends one storm, not a whole sky.
		var/prob_of_weather_change = ((25*schedule_interval)/change_interval) * weather_system_capacity()
		if (weather == WEATHER_WET || weather == WEATHER_EXTREME)
			prob_of_weather_change = (prob_of_weather_change*3)
		if (prob(prob_of_weather_mod))
			if (world.realtime >= next_can_mod_weather)
				modify_weather_somehow()
				next_can_mod_weather = world.realtime + mod_delay
		else if (prob(prob_of_weather_change))
			if (world.realtime >= next_can_change_weather)
				change_weather_somehow()
			next_can_change_weather = world.realtime + change_delay
	weather_events()

// Blizzards, sandstorms and heat waves are weather systems like any other:
// they arrive from upwind, pass over and move on. An admin calls one down by
// setting the map's triggered_ flag; summer also brings heat waves by itself.
/proc/weather_events()
	if (!map)
		return
	if (map.triggered_blizzard || map.triggered_sandstorm)
		map.triggered_blizzard = FALSE
		map.triggered_sandstorm = FALSE
		weather_system_spawn(WEATHER_SYSTEM_STORM, TRUE, null, null, 600)
	if (map.triggered_heatwave || (season == "SUMMER" && prob(1) && prob(50)))
		map.triggered_heatwave = FALSE
		if (weather_systems.len == weather_storm_count)
			weather_system_spawn(WEATHER_SYSTEM_HEAT, FALSE, null, null, 600)

// Draws the weather systems for the players near them (weather_chunks.dm).
/process/weather_chunks/setup()
	name = "weather drawing"
	schedule_interval = 2 SECONDS
	start_delay = 4 SECONDS
	priority = PROCESS_PRIORITY_IRRELEVANT
	fires_at_gamestates = list(GAME_STATE_PLAYING)

/process/weather_chunks/fire()
	weather_chunks_step()
