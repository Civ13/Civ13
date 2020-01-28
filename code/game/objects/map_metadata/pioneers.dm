
/obj/map_metadata/pioneers
	ID = MAP_PIONEERS
	title = "Pioneers (200x200x2)"
	lobby_icon_state = "wildwest"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 7200 // 12 minutes!
	squad_spawn_locations = FALSE
	no_winner ="The round is proceeding normally."
	faction_organization = list(
		CIVILIAN,
		INDIANS)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british,
		list(INDIANS) = /area/caribbean/british
		)
	age = "1873"
	ordinal_age = 4
	faction_distribution_coeffs = list( CIVILIAN = 0.8,INDIANS = 0.2)
	battle_name = "new frontier"
	mission_start_message = "<big>Pioneers</b> have reached the frontier! The <b>Pioneers</b> must build their town. The gracewall will be up after 25 minutes.</big><br><span class = 'notice'><i>THIS IS A RP MAP - PIONEERS ARE FRIENDLY BY DEFAULT.</b> No griefing will be tolerated. If you break the rules, you will be banned from this gamemode!<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	songs = list(
		"Nassau Shores:1" = 'sound/music/nassau_shores.ogg',)
	gamemode = "Pioneer Building RP"
	is_singlefaction = TRUE

/obj/map_metadata/pioneers/New()
	..()
	spawn(18000)
		seasons()
	civilians_forceEnabled = TRUE
/obj/map_metadata/pioneers/seasons()
	if (season == "WINTER")
		season = "SPRING"
		world << "<big>The weather is getting warmer. It is now <b>Spring</b>.</big>"
		for (var/obj/structure/wild/tree/live_tree/TREES)
			TREES.change_season()
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
			if (prob(50) && !istype(D, /turf/floor/dirt/underground) && !istype(D, /turf/floor/dirt/dust) && !istype(D, /turf/floor/dirt/ploughed) && A.location == AREA_OUTSIDE && !istype(A,/area/caribbean/tribes/swamp))
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
			for (var/turf/floor/dirt/D in get_area_turfs(/area/caribbean/nomads/forest))
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

obj/map_metadata/pioneers/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian))
		if (J.is_pioneer == TRUE)
			. = TRUE
		else
			. = FALSE

/obj/map_metadata/pioneers/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/pioneers/cross_message(faction)
	return ""


