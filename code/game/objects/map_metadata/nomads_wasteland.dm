
/obj/map_metadata/nomads_wasteland
	ID = MAP_NOMADS_WASTELAND
	title = "Nomads (Wasteland) (235x235x2)"
	lobby_icon_state = "civ13"
	no_winner ="The round is proceeding normally."
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
	age = "2013"
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>The world is on the verge of nuclear war... The nukes will drop in 2 to 3:30 hours. Then the world will become a wasteland. Can you survive?</big><br><b>Wiki Guide: http://civ13.com/wiki/index.php/Nomads</b>"
	ambience = list('sound/ambience/desert.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = 'sound/music/words_through_the_sky.ogg',)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Nuclear Wasteland"
	ordinal_age = 8
	default_research = 230
	research_active = FALSE
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE
	age7_done = TRUE
	age8_done = TRUE
/obj/map_metadata/nomads_wasteland/New()
	..()
	spawn(18000)
		seasons()
		var/randtimer = rand(72000,108000)
		nuke_proc(randtimer)
		supplydrop_proc()
/obj/map_metadata/nomads_wasteland/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_wasteland/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 0 || admin_ended_all_grace_periods)

/obj/map_metadata/nomads_wasteland/cross_message(faction)
	return ""

/obj/map_metadata/nomads_wasteland/proc/nuke_proc(var/timer=72000)
	if (processes.ticker.playtime_elapsed > timer)
		var/vx = rand(25,world.maxx-25)
		var/vy = rand(25,world.maxy-25)
		var/turf/epicenter = get_turf(locate(vx,vy,2))
		world << "<font size=3 color='red'><center>ATTENTION<br>A nuclear missile is incoming! Take cover!</center></font>"
		var/warning_sound = sound('sound/misc/siren.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		for (var/mob/M in player_list)
			M.client << warning_sound
		spawn(330)
			world << "<font size=3 color='red'>A nuclear explosion has happened! <br><i>(Game might freeze/lag for a while while processing, please wait)</i></font>"
			nuke_map(epicenter, 200, 180, 0)
			message_admins("Automatic nuke deployed at ([epicenter.x],[epicenter.y],[epicenter.z]) in area [epicenter.loc.name].")
			log_game("Automatic nuke deployed at ([epicenter.x],[epicenter.y],[epicenter.z]) in area [epicenter.loc.name].")
			return
	else
		spawn(600)
			nuke_proc(timer)
	return
/obj/map_metadata/nomads_wasteland/proc/supplydrop_proc()
	if (world_radiation >= 280)
		var/droptype = pick("supplies","food","weapons","medicine")
		var/turf/locationt = pick(supplydrop_turfs)
		switch(droptype)
			if("supplies")
				world << "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Supplies have been airdropped in the area!</center></font>"
				new/obj/structure/closet/crate/airdrops/supplies(locationt)

			if("food")
				world << "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Food has been airdropped in the area!</center></font>"
				new/obj/structure/closet/crate/airdrops/food(locationt)
				new/obj/item/weapon/reagent_containers/glass/barrel/modern/water(locationt)

			if("weapons")
				world << "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Weapons and ammunition have been airdropped in the area!</center></font>"
				new/obj/structure/closet/crate/airdrops/weapons(locationt)

			if("medicine")
				world << "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Medicine has been airdropped in the area!</center></font>"
				new/obj/structure/closet/crate/airdrops/medicine(locationt)
	spawn(rand(36000, 72000))
		supplydrop_proc()
/obj/map_metadata/nomads_wasteland/seasons()
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
				G.radiation = world_radiation/10
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
			if (prob(50) && !istype(D, /turf/floor/dirt/underground) && !istype(D, /turf/floor/dirt/dust) && !istype(D, /turf/floor/dirt/ploughed) && A.location == AREA_OUTSIDE && !istype(A,/area/caribbean/forest/dirt))
				D.ChangeTurf(/turf/floor/grass)
				D.radiation = world_radiation/10
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

/obj/map_metadata/nomads_wasteland/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE
