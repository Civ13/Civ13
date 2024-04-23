/obj/map_metadata/nomads_frozen_wasteland
	ID = MAP_NOMADS_FROZEN_WASTELAND
	title = "Frozen Wasteland"
	lobby_icon = 'icons/lobby/civilizations.gif'
	no_winner ="The round is proceeding normally."
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 6000 // 10 minutes!
	has_hunger = TRUE

	faction_organization = list(
		CIVILIAN,)

	roundend_condition_sides = list(
		list(CIVILIAN) = /area/caribbean/british
		)
	is_wasteland = TRUE
	age = "2013"
	civilizations = TRUE
	var/tribes_nr = 1
	faction_distribution_coeffs = list(CIVILIAN = 1)
	battle_name = "the civilizations"
	mission_start_message = "<big>The world has become desolate and frozen.</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/Civilizations_and_Nomads</b>"
	ambience = list('sound/ambience/desert.ogg')
	faction1 = CIVILIAN
	availablefactions = list("Nomad")
	songs = list(
		"Words Through the Sky:1" = "sound/music/words_through_the_sky.ogg",)
	research_active = TRUE
	nomads = TRUE
	gamemode = "Frozen Wasteland"
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


	hasnukes = FALSE
	is_zombie = FALSE

/obj/map_metadata/nomads_frozen_wasteland/New()
	..()
	spawn(10)


	spawn(10)
		seasons()
		var/randtimer = rand(10,20)
		if (hasnukes)
			nuke_proc(randtimer)
			supplydrop_proc()
		else
			supplydrop_proc()

/obj/map_metadata/nomads_frozen_wasteland/cross_message(faction)
	return ""

/obj/map_metadata/nomads_frozen_wasteland/proc/nuke_proc(var/timer=15)
	if (processes.ticker.playtime_elapsed > timer && hasnukes )
		var/vx = rand(25,world.maxx-25)
		var/vy = rand(25,world.maxy-25)
		var/turf/epicenter = get_turf(locate(vx,vy,2))
		world << "<font size=3 color='red'><center>ATTENTION<br>A nuclear missile is incoming! Take cover!</center></font>"
		var/warning_sound = sound('sound/misc/siren.ogg', repeat = FALSE, wait = TRUE, channel = 777)
		for (var/mob/M in player_list)
			M.client << warning_sound
		spawn(330)
			world << "<font size=4 color='red'>A nuclear explosion has happened! <br><i>(Game might freeze/lag for a while while processing, please wait)</i></font>"
			nuke_map(epicenter, 200, 180, 0)
			message_admins("Automatic nuke deployed at ([epicenter.x],[epicenter.y],[epicenter.z]) in area [epicenter.loc.name].")
			log_game("Automatic nuke deployed at ([epicenter.x],[epicenter.y],[epicenter.z]) in area [epicenter.loc.name].")
			return
	else
		spawn(600) // 1 minute
			nuke_proc(timer)
	return

/obj/map_metadata/nomads_frozen_wasteland/proc/supplydrop_proc()
	if ((global_radiation >= 280 && hasnukes)||(is_zombie == TRUE))
		var/droptype = pick("supplies","food","weapons","military","medicine","rad","cold")
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

			if("military")
				world << "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Military equipment has been airdropped in the area!</center></font>"
				new/obj/structure/closet/crate/airdrops/military(locationt)

			if("medicine")
				world << "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Medicine has been airdropped in the area!</center></font>"
				new/obj/structure/closet/crate/airdrops/medicine(locationt)

			if("rad")
				world << "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Radiation equipment has been airdropped in the area!</center></font>"
				new/obj/structure/closet/crate/airdrops/rads(locationt)

			if("cold")
				world << "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Cold weather equipment has been airdropped in the area!</center></font>"
				new/obj/structure/closet/crate/airdrops/cold(locationt)
	spawn(rand(36000, 72000))
		supplydrop_proc()

/obj/map_metadata/nomads_frozen_wasteland/job_enabled_specialcheck(var/datum/job/J)
	if (J.is_nomad == TRUE)
		. = TRUE
	else
		. = FALSE

/obj/map_metadata/nomads_frozen_wasteland/proc/zombies(var/start = TRUE)
	if (is_zombie == TRUE)
		for(var/obj/effect/spawner/mobspawner/zombies/special/S in world)
			S.activated = start