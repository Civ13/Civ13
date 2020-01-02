
/obj/map_metadata/tribes
	ID = MAP_TRIBES
	title = "Tribes (225x225x2)"
	no_winner ="The round is proceeding normally."
	lobby_icon_state = "civ13"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/temperate)
	respawn_delay = 3600 // 6 minutes!
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		CIVILIAN,)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	age = "the lost time"
	ordinal_age = 2
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the four tribes"
	mission_start_message = "<big>Four tribes are settling in this land. Will they be able to get along?<br>The grace wall will be up for <b>25 minutes</b>.</big>"
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	is_singlefaction = TRUE
	valid_weather_types = list(WEATHER_RAIN, WEATHER_NONE, WEATHER_STORM, WEATHER_SMOG)
	availablefactions = list("Orc tribesman")
	availablefactions_run = TRUE
	civilizations = TRUE
	songs = list(
		"Words Through the Sky:1" = 'sound/music/words_through_the_sky.ogg',)
	gamemode = "Faction-Based RP"
/obj/map_metadata/tribes/New()
	var/newnamea = list("Orc Horde" = list(48,48,48,null,0,"skull","#9A1313","#000000"))
	var/newnameb = list("Ant Colony" = list(21,21,21,null,0,"star","#0C1EA7","#67A7CE"))
	var/newnamec = list("Gorilla Tribe" = list(27,32,30,null,0,"sun","#9A9A9A","#098518"))
	var/newnamed = list("Human Kingdom" = list(62,62,62,null,0,"cross","#E5C100","#FFFFFF"))
	var/newnamee = list("Lizard Clan" = list(21,21,21,null,0,"big_cross","#669932","#1E1E1E"))
	var/newnamef = list("Wolfpack" = list(21,21,21,null,0,"moon","#FFFFFF","#848484"))
	var/newnameg = list("Crustacean Union" = list(21,21,21,null,0,"seashell","#EEEEEE","#7F0000"))
	custom_civs += newnamea
	custom_civs += newnameb
	custom_civs += newnamec
	custom_civs += newnamed
	custom_civs += newnamee
	custom_civs += newnamef
	custom_civs += newnameg

	spawn(1)
		civilians_forceEnabled = TRUE

	spawn(18000)
		seasons()
	..()
/obj/map_metadata/tribes/seasons()
	if (season == "WINTER")
		season = "SPRING"
		world << "<big>The weather is getting warmer. It is now <b>Spring</b>.</big>"
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
			TREES.leaves = TREES.max_leaves
		for (var/turf/floor/dirt/winter/D)
			if (prob(60))
				D.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/winter/grass/G)
			if (prob(60))
				G.ChangeTurf(/turf/floor/grass)
		for (var/turf/floor/dirt/burned/B)
			var/area/A = get_area(B)
			if (A.location == AREA_OUTSIDE)
				if (prob(60))
					B.ChangeTurf(/turf/floor/dirt)
		spawn(150)
			change_weather(WEATHER_NONE)
			for (var/obj/structure/window/snowwall/SW1)
				if (prob(60))
					qdel(SW1)
			for (var/obj/covers/snow_wall/SW2)
				if (prob(60))
					qdel(SW2)
			for (var/obj/item/weapon/snowwall/SW3)
				if (prob(60))
					qdel(SW3)
		spawn(1500)
			for (var/turf/floor/beach/water/ice/salty/SW)
				SW.ChangeTurf(/turf/floor/beach/water/shallowsaltwater)
			for (var/turf/floor/beach/water/ice/W)
				W.ChangeTurf(/turf/floor/beach/water)
		spawn(3000)
			for (var/turf/floor/dirt/winter/D)
				D.ChangeTurf(/turf/floor/dirt)
			for (var/turf/floor/winter/grass/G)
				G.ChangeTurf(/turf/floor/grass)
			for (var/obj/structure/window/snowwall/SW1)
				qdel(SW1)
			for (var/obj/covers/snow_wall/SW2)
				qdel(SW2)
			for (var/obj/item/weapon/snowwall/SW3)
				qdel(SW3)
	else if (season == "SUMMER")
		season = "FALL"
		world << "<big>The leaves start to fall and the weather gets colder. It is now <b>Fall</b>.</big>"
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
		for (var/turf/floor/dirt/D)
			var/area/A = get_area(D)
			if (prob(50) && !istype(D, /turf/floor/dirt/underground) && !istype(D, /turf/floor/dirt/dust) && !istype(D, /turf/floor/dirt/ploughed) && A.location == AREA_OUTSIDE)
				D.ChangeTurf(/turf/floor/grass)
			D.update_icon()
		for (var/turf/floor/dirt/burned/BD)
			BD.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/grass/G)
			G.update_icon()
		spawn(100)
			change_weather(WEATHER_RAIN)
		spawn(15000)
			change_weather(WEATHER_SNOW)
			for (var/turf/floor/dirt/D in get_area_turfs(/area/caribbean/no_mans_land/temperate))
				var/area/A = get_area(D)
				if (A.location == AREA_OUTSIDE && prob(40) && !istype(D, /turf/floor/dirt/underground) && !istype(D, /turf/floor/dirt/dust))
					D.ChangeTurf(/turf/floor/dirt/winter)
			for (var/turf/floor/grass/G)
				if (prob(40))
					G.ChangeTurf(/turf/floor/winter/grass)
			spawn(1200)
				for (var/turf/floor/dirt/D)
					if (!istype(D,/turf/floor/dirt/winter))
						var/area/A = get_area(D)
						if (A.location == AREA_OUTSIDE && prob(50))
							D.ChangeTurf(/turf/floor/dirt/winter)
				for (var/turf/floor/grass/G)
					if (prob(50))
						G.ChangeTurf(/turf/floor/winter/grass)
	else if (season == "FALL")
		season = "WINTER"
		world << "<big>The weather gets very cold. <b>Winter</b> has arrived.</big>"
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
		for (var/turf/floor/dirt/D)
			if (!istype(D,/turf/floor/dirt/winter) && !istype(D,/turf/floor/dirt/underground) && !istype(D,/turf/floor/dirt/dust))
				var/area/A = get_area(D)
				if (A.location == AREA_OUTSIDE)
					D.ChangeTurf(/turf/floor/dirt/winter)
		for (var/turf/floor/grass/G)
			G.ChangeTurf(/turf/floor/winter/grass)
		spawn(100)
			change_weather(WEATHER_SNOW)
		spawn(800)
		for (var/turf/floor/beach/water/shallowsaltwater/SW)
			if (SW.water_level <= 50 && SW.z > 1)
				SW.ChangeTurf(/turf/floor/beach/water/ice/salty)
		for (var/turf/floor/beach/water/W)
			if (W.water_level <= 50 && W.z > 1)
				W.ChangeTurf(/turf/floor/beach/water/ice)
		spawn(12000)
			for (var/turf/floor/dirt/winter/D)
				if (prob(20))
					D.ChangeTurf(/turf/floor/dirt)
			for (var/turf/floor/winter/grass/G)
				if (prob(20))
					G.ChangeTurf(/turf/floor/grass)
	else if (season == "SPRING")
		season = "SUMMER"
		world << "<big>The weather is warm. It is now <b>Summer</b>.</big>"
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
		for (var/turf/floor/dirt/winter/D)
			D.ChangeTurf(/turf/floor/dirt)
		for (var/turf/floor/winter/grass/G)
			G.ChangeTurf(/turf/floor/grass)
		spawn(100)
			change_weather(WEATHER_NONE)
	spawn(18000)
		seasons()
/obj/map_metadata/tribes/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian/fantasy))
		. = TRUE
	else
		. = FALSE
/obj/map_metadata/tribes/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/tribes/cross_message(faction)
	return ""

