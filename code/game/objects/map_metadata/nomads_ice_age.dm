#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/nomads_ice_age
	ID = MAP_NOMADS_ICE_AGE
	title = "Nomads Ice Age (275x275x1)"
	lobby_icon_state = "civilizations"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		CIVILIAN,)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "5000 B.C."
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>After ages as hunter-gatherers, people are starting to form groups and settling down. Will they be able to work together?</big><br><b>Wiki Guide: http://1713.eu/wiki/index.php/Civilizations</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Empire Earth Intro:1" = 'sound/music/empire_earth_intro.ogg',)
	research_active = TRUE
	age1_lim = 90
	age1_done = 0
	age1_top = 35
	age2_lim = 150
	age2_done = 0
	age2_timer = 40000
	age2_top = 65
	age3_lim = 240
	age3_done = 0
	age3_timer = 42000
	nomads = TRUE

	var/real_season = "WINTER"

/obj/map_metadata/nomads_ice_age/New()
	..()
	spawn(180)
		seasons()

/obj/map_metadata/nomads_ice_age/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_ice_age/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_ice_age/cross_message(faction)
	return ""

/obj/map_metadata/nomads_ice_age/proc/seasons()
	if (real_season == "SUMMER")
		season = "WINTER"
		world << "<big>It's getting very cold. <b>Winter</b> has started.</big>"
			change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.update_icon()
		for (var/turf/floor/dirt/D)
			if (!istype(D,/turf/floor/dirt/winter))
				var/area/A = get_area(D)
				if  (A.location != AREA_INSIDE)
					D.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/plating/grass/wild/G)
			var/area/A = get_area(G)
			if  (A.location != AREA_INSIDE)
				G.ChangeTurf(/turf/floor/winter/grass)
		spawn(100)
			change_weather(WEATHER_SNOW)
		spawn(800)
		for (var/turf/floor/plating/beach/water/W)
			W.ChangeTurf(/turf/floor/plating/beach/water/ice)
		real_season = "WINTER"
	else
		season = "SUMMER"
		world << "<big>The weather gets warmer. <b>Summer</b> has started.</big>"
			change_weather_somehow()
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.update_icon()
		for (var/turf/floor/dirt/winter/D)
			if (prob(50))
				D.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/winter/grass/G)
			if (prob(50))
				G.ChangeTurf(/turf/floor/plating/grass/wild)
		for (var/turf/floor/dirt/burned/B)
			if (prob(60))
				B.ChangeTurf(/turf/floor/plating/grass/wild)
		spawn(150)
			change_weather(WEATHER_NONE)
		spawn(1500)
		for (var/turf/floor/plating/beach/water/ice/W)
			if (prob(65) && W.water_level >= 50)
				W.ChangeTurf(/turf/floor/plating/beach/water)
		real_season = "SUMMER"

	if (real_season == "SUMMER")
		spawn(9000)
			seasons()
	else if (real_season == "WINTER")
		spawn(18000)
			seasons()



/obj/map_metadata/nomads_ice_age/tick()
	..()
	if (age1_done == FALSE)
		var/count = 0
		for(var/i = 1, i <= custom_faction_nr.len, i++)
			count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
			if (count > age1_lim && world.time > 36000)
				world << "<big>The world has advanced into the Bronze Age!</big>"
				age = "313 B.C."
				set_ordinal_age()
				age1_done = TRUE
				age2_timer = (world.time + age2_timer)
				break

	else if (age2_done == FALSE)
		var/count = 0
		for(var/i = 1, i <= custom_faction_nr.len, i++)
			count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
			if (count > age2_lim && world.time >= age2_timer)
				world << "<big>The world has advanced into the Medieval Age!</big>"
				age = "1013"
				set_ordinal_age()
				age2_done = TRUE
				age3_timer = (world.time + age3_timer)
				break

	else if (age3_done == FALSE)
		var/count = 0
		for(var/i = 1, i <= custom_faction_nr.len, i++)
			count = custom_civs[custom_faction_nr[i]][1]+custom_civs[custom_faction_nr[i]][2]+custom_civs[custom_faction_nr[i]][3]
			if (count > age3_lim && world.time >= age3_timer)
				world << "<big>The world has advanced into the Imperial Age!</big>"
				age = "1713"
				set_ordinal_age()
				age3_done = TRUE
				break

/obj/map_metadata/nomads_ice_age/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
#undef NO_WINNER