// Profiles are intentionally explicit. Other maps retain their existing timers
// until their subtype calendars/events have their own recovery contract.
/obj/map_metadata
	var/tmp/datum/durable_timer_queue/durable_callbacks
	var/tmp/research_clock_offset = 0

/obj/map_metadata/proc/uses_durable_metadata()
	return type in list(/obj/map_metadata/nomads/gaia, /obj/map_metadata/nomads/europe)

/obj/map_metadata/proc/durable_callback_names()
	return list("wind" = "wind", "religion" = "religious_timer", "tips" = "tip_process", "pollution" = "pollution", "autoresearch" = "durable_autoresearch_step", "season_loop" = "durable_season_loop", "season_phase_1" = "durable_season_phase_1", "season_phase_2" = "durable_season_phase_2", "season_phase_3" = "durable_season_phase_3", "season_phase_4" = "durable_season_phase_4", "season_phase_5" = "durable_season_phase_5", "season_phase_6" = "durable_season_phase_6", "season_phase_7" = "durable_season_phase_7", "season_phase_8" = "durable_season_phase_8", "season_phase_9" = "durable_season_phase_9", "blizzard_start" = "durable_blizzard_start", "blizzard_end" = "durable_blizzard_end", "heat_start" = "durable_heat_start", "heat_end" = "durable_heat_end", "sandstorm_start" = "durable_sandstorm_start", "sandstorm_end" = "durable_sandstorm_end")

/obj/map_metadata/proc/durable_timer_queue()
	if(!durable_callbacks)
		durable_callbacks = new(src, durable_callback_names())
	return durable_callbacks

// TRUE means this profile owns the callback, including an already scheduled
// singleton. Callers must not fall back to spawning another sleeper then.
/obj/map_metadata/proc/durable_schedule(key, delay)
	if(!uses_durable_metadata()) return FALSE
	var/datum/durable_timer_queue/Q = durable_timer_queue()
	Q.schedule(key, delay)
	return TRUE

/obj/map_metadata/proc/durable_pending(key)
	return durable_callbacks && durable_callbacks.pending[key]

/obj/map_metadata/proc/durable_cancel_season_phases()
	if(!durable_callbacks) return
	for(var/i = 1, i <= 9, i++)
		durable_callbacks.cancel("season_phase_[i]")

/obj/map_metadata/proc/durable_season_loop()
	season_loop_scheduled = FALSE
	if(!season_retired && map == src) seasons()

// Retain the existing serialized season worker rather than running terrain
// phases concurrently with another yielding transition.
/obj/map_metadata/proc/durable_enqueue_season_phase(phase)
	if(!season_worker_valid(season_epoch)) return
	season_queue += list(phase, season_epoch, FALSE, FALSE)
	season_run_queue()

/obj/map_metadata/proc/durable_season_phase_1()
	durable_enqueue_season_phase("season_phase_1")
/obj/map_metadata/proc/durable_season_phase_2()
	durable_enqueue_season_phase("season_phase_2")
/obj/map_metadata/proc/durable_season_phase_3()
	durable_enqueue_season_phase("season_phase_3")
/obj/map_metadata/proc/durable_season_phase_4()
	durable_enqueue_season_phase("season_phase_4")
/obj/map_metadata/proc/durable_season_phase_5()
	durable_enqueue_season_phase("season_phase_5")
/obj/map_metadata/proc/durable_season_phase_6()
	durable_enqueue_season_phase("season_phase_6")
/obj/map_metadata/proc/durable_season_phase_7()
	durable_enqueue_season_phase("season_phase_7")
/obj/map_metadata/proc/durable_season_phase_8()
	durable_enqueue_season_phase("season_phase_8")
/obj/map_metadata/proc/durable_season_phase_9()
	durable_enqueue_season_phase("season_phase_9")

/obj/map_metadata/proc/durable_autoresearch_step()
	if(!autoresearch || default_research >= 230) return
	autoresearch_step()

/obj/map_metadata/proc/durable_weather_events()
	if(season == "WINTER" && triggered_blizzard && !blizzard && !durable_pending("blizzard_start"))
		to_chat(world, "<big>A huge blizzard is approaching!</big>")
		triggered_blizzard = FALSE
		durable_schedule("blizzard_start", 600)
	if((season == "SUMMER" || triggered_heatwave) && !heat_wave && !durable_pending("heat_start"))
		if((prob(1) || triggered_heatwave) && (prob(50) || triggered_heatwave))
			to_chat(world, "<big>The weather starts to get hotter than normal...</big>")
			triggered_heatwave = FALSE
			durable_schedule("heat_start", 600)
	if(season == "Dry Season" && triggered_sandstorm && !sandstorm && !durable_pending("sandstorm_start"))
		to_chat(world, "<big>You start seeing dark clouds in the horizon...</big>")
		triggered_sandstorm = FALSE
		durable_schedule("sandstorm_start", 600)

/obj/map_metadata/proc/durable_blizzard_start()
	blizzard = TRUE
	change_weather(WEATHER_EXTREME)
	durable_schedule("blizzard_end", rand(2400, 3600))
/obj/map_metadata/proc/durable_blizzard_end()
	blizzard = FALSE
	change_weather(WEATHER_NONE)
/obj/map_metadata/proc/durable_sandstorm_start()
	sandstorm = TRUE
	change_weather(WEATHER_EXTREME)
	durable_schedule("sandstorm_end", rand(3000, 3600))
/obj/map_metadata/proc/durable_sandstorm_end()
	sandstorm = FALSE
	change_weather(WEATHER_NONE)
/obj/map_metadata/proc/durable_heat_start()
	heat_wave = TRUE
	change_weather(WEATHER_NONE)
	to_chat(world, "<big>A heat wave has arrived in this area!</big>")
	for(var/obj/structure/sink/S)
		if(istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
			S.dry = TRUE
			S.update_icon()
	durable_schedule("heat_end", rand(3000, 3600))
/obj/map_metadata/proc/durable_heat_end()
	heat_wave = FALSE
	to_chat(world, "<big>The heat wave has subsided.</big>")
	for(var/obj/structure/sink/S)
		if(istype(S, /obj/structure/sink/well) || istype(S, /obj/structure/sink/puddle))
			S.dry = FALSE
			S.update_icon()

/obj/map_metadata/proc/research_time()
	return world.time + research_clock_offset
