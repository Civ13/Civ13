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

	var/prob_of_weather_mod = ((((1/mod_weather_interval) * 10) / 2) * 100) * schedule_interval/20
	var/prob_of_weather_change = ((((1/change_weather_interval) * 10) / 2) * 100) * schedule_interval/20
	if (weather == WEATHER_RAIN || weather == WEATHER_STORM || weather == WEATHER_BLIZZARD || weather == WEATHER_SANDSTORM)
		prob_of_weather_change = (prob_of_weather_change*2)
	if (prob(prob_of_weather_mod))
		if (world.realtime >= next_can_mod_weather)
			modify_weather_somehow()
			next_can_mod_weather = world.realtime + minimum_mod_weather_delay
	else if (prob(prob_of_weather_change))
		if (world.realtime >= next_can_change_weather)
			change_weather_somehow()
			next_can_change_weather = world.realtime + minimum_change_weather_delay
	if ((season == "WINTER" && map.triggered_blizzard) && !map.blizzard)
		if (prob(1) || map.triggered_blizzard)
			if(prob(50) || map.triggered_blizzard)
				world << "<big>A huge blizzard is approaching!</big>"
				map.triggered_blizzard = FALSE
				spawn(600)
					map.blizzard = TRUE
					change_weather(WEATHER_BLIZZARD)
					//world << "<big>The blizzard is in full force!</big>"
					spawn(rand(2400,3600))
						map.blizzard = FALSE
						change_weather(WEATHER_NONE)
						//world << "<big>The blizzard has passed.</big>"
	if ((season == "SUMMER" || map.triggered_heatwave) && !map.heat_wave)
		if (prob(1) || map.triggered_heatwave)
			if(prob(50)|| map.triggered_heatwave)
				world << "<big>The weather starts to get hotter than normal...</big>"
				map.triggered_heatwave = FALSE
				spawn(600)
					map.heat_wave = TRUE
					change_weather(WEATHER_NONE)
					world << "<big>A heat wave has arrived in this area!</big>"
					for(var/obj/structure/sink/S)
						if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
							S.dry = TRUE
							S.update_icon()
					spawn(rand(3000,3600))
						map.heat_wave = FALSE
						world << "<big>The heat wave has subsided.</big>"
						for(var/obj/structure/sink/S)
							if (istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
								S.dry = FALSE
								S.update_icon()
	if ((season == "Dry Season" && map.triggered_sandstorm) && !map.sandstorm)
		if (prob(1) || map.triggered_sandstorm)
			if(prob(50)|| map.triggered_sandstorm)
				world << "<big>You start seeing dark clouds in the horizon...</big>"
				map.triggered_sandstorm = FALSE
				spawn(600)
					map.sandstorm = TRUE
					change_weather(WEATHER_SANDSTORM)
					//world << "<big>A sandstorm has arrived in this area!</big>"
					spawn(rand(3000,3600))
						map.sandstorm = FALSE
						//world << "<big>The sandstorm has subsided.</big>"
						change_weather(WEATHER_NONE)