
/obj/map_metadata/nomads/ice_age
	season_duration_minutes = 30 // Preserve initial loop before its asymmetric 15/45-minute cycle.
	abandonment_season_cycle = TRUE
	abandonment_season_autonomous = TRUE
	ID = MAP_NOMADS_ICE_AGE
	title = "Nomads (Ice Age)"
	description = "Battle on the Nomads (Ice Age) map."
	ambience = list("sound/ambience/desert.ogg")
	research_active = TRUE
	var/real_season = "WINTER"

/obj/map_metadata/nomads/ice_age/New()
	..()
	for (var/obj/structure/wild/tree/live_tree/TREES)
		TREES.change_season()

/obj/map_metadata/nomads/ice_age/seasons(looping = TRUE, force = FALSE, advance_decay = null)
	advance_decay = season_decay_requested(force, advance_decay)
	if (real_season == "SUMMER")
		season = "WINTER"
		record_abandonment_season_change(advance_decay)
		to_chat(world, "<big>It's getting very cold. <b>Winter</b> has started.</big>")
		change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
		for (var/obj/structure/wild/smallbush/SB)
			new/obj/structure/wild/smallbush/winter(SB.loc)
			qdel(SB)
		spawn(100)
			change_weather(WEATHER_WET)
		spawn(800)
		for (var/turf/floor/beach/water/shallowsaltwater/W)
			W.ChangeTurf(/turf/floor/beach/water/ice/salty)
		real_season = "WINTER"
	else
		season = "SUMMER"
		record_abandonment_season_change(advance_decay)
		to_chat(world, "<big>The weather gets warmer. <b>Summer</b> has started.</big>")
		change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
		for (var/obj/structure/wild/smallbush/winter/SBW)
			new/obj/structure/wild/smallbush(SBW.loc)
			qdel(SBW)
		for (var/turf/floor/dirt/burned/B)
			if (prob(60))
				B.ChangeTurf(/turf/floor/grass)
		spawn(150)
			change_weather(WEATHER_NONE)
		spawn(1500)
		for (var/turf/floor/beach/water/ice/salty/W)
			if (prob(65) && W.water_level >= 50)
				W.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
		real_season = "SUMMER"

	if (looping && real_season == "SUMMER")
		spawn(9000)
			seasons()
	else if (looping && real_season == "WINTER")
		spawn(27000)
			seasons()
