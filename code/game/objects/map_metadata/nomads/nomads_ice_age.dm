
/obj/map_metadata/nomads/ice_age
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

/obj/map_metadata/nomads/ice_age/seasons()
	if (real_season == "SUMMER")
		season = "WINTER"
		to_chat(world, "<big>It's getting very cold. <b>Winter</b> has started.</big>")
		change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
		for (var/obj/structure/wild/smallbush/SB)
			new/obj/structure/wild/smallbush/winter(SB.loc)
			qdel(SB)
		for (var/turf/floor/dirt/D)
			if (!istype(D,/turf/floor/dirt/winter) && !istype(D,/turf/floor/dirt/underground) && !istype(D, /turf/floor/dirt/dust))
				var/area/A = get_area(D)
				if  (A.location != AREA_INSIDE)
					D.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/grass/G)
			var/area/A = get_area(G)
			if  (A.location != AREA_INSIDE)
				G.ChangeTurf(/turf/floor/winter/grass)
		spawn(100)
			change_weather(WEATHER_WET)
		spawn(800)
		for (var/turf/floor/beach/water/shallowsaltwater/W)
			W.ChangeTurf(/turf/floor/beach/water/ice/salty)
		real_season = "WINTER"
	else
		season = "SUMMER"
		to_chat(world, "<big>The weather gets warmer. <b>Summer</b> has started.</big>")
		change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
		for (var/obj/structure/wild/smallbush/winter/SBW)
			new/obj/structure/wild/smallbush(SBW.loc)
			qdel(SBW)
		for (var/turf/floor/dirt/winter/D)
			if (prob(50))
				D.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/winter/grass/G)
			if (prob(50))
				G.ChangeTurf(/turf/floor/grass)
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

	if (real_season == "SUMMER")
		spawn(9000)
			seasons()
	else if (real_season == "WINTER")
		spawn(27000)
			seasons()
