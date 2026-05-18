
/obj/map_metadata/nomads/wasteland
	ID = MAP_NOMADS_WASTELAND
	title = "Wasteland"
	description = "The world is on the verge of nuclear war... The nukes will drop in 2 to 3:30 hours. Then the world will become a wasteland."
	age = "2013"
	mission_start_message = "<big>The world is on the verge of nuclear war... The nukes will drop in 2 to 3:30 hours. Then the world will become a wasteland. Can you survive?</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/gamemodes/Civilizations_and_Nomads</b>"
	ambience = list("sound/ambience/desert.ogg")
	
	research_active = TRUE
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
	hasnukes = TRUE

/obj/map_metadata/nomads/wasteland/New()
	..()
	spawn(18000)
		var/randtimer = rand(72000,108000)
		if (hasnukes)
			nuke_proc(randtimer)
			supplydrop_proc()
		else
			supplydrop_proc()

/obj/map_metadata/nomads/wasteland/proc/nuke_proc(var/timer=72000)
	if (processes.ticker.playtime_elapsed > timer && hasnukes)
		var/vx = rand(25,world.maxx-25)
		var/vy = rand(25,world.maxy-25)
		var/turf/epicenter = get_turf(locate(vx,vy,2))
		to_chat(world, "<font size=4 color='red'><center>ATTENTION<br>A nuclear missile is incoming! Take cover!</center></font>")
		var/warning_sound = sound("sound/misc/siren.ogg", repeat = FALSE, wait = TRUE, channel = 777)
		for (var/mob/M in player_list)
			M.client << warning_sound
		spawn(330)
			to_chat(world, "<font size=4 color='red'>A nuclear explosion has happened! <br><i>(Game might freeze/lag for a while while processing, please wait)</i></font>")
			nuke_map(epicenter, 200, 180, 0)
			message_admins("Automatic nuke deployed at ([epicenter.x],[epicenter.y],[epicenter.z]) in area [epicenter.loc.name].")
			log_game("Automatic nuke deployed at ([epicenter.x],[epicenter.y],[epicenter.z]) in area [epicenter.loc.name].")
			return
	else
		spawn(600) // 1 minute
			nuke_proc(timer)
	return
/obj/map_metadata/nomads/wasteland/proc/supplydrop_proc()
	if ((global_radiation >= 280 && hasnukes)||is_zombie == TRUE)
		var/droptype = pick("supplies","food","weapons","military","medicine","rad","cold")
		var/turf/locationt = pick(supplydrop_turfs)
		switch(droptype)
			if("supplies")
				to_chat(world, "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Supplies have been airdropped in the area!</center></font>")
				new/obj/structure/closet/crate/airdrops/supplies(locationt)

			if("food")
				to_chat(world, "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Food and water have been airdropped in the area!</center></font>")
				new/obj/structure/closet/crate/airdrops/food(locationt)
				new/obj/item/weapon/reagent_containers/glass/barrel/modern/water(locationt)

			if("weapons")
				to_chat(world, "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Weapons and ammunition have been airdropped in the area!</center></font>")
				new/obj/structure/closet/crate/airdrops/weapons(locationt)

			if("military")
				to_chat(world, "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>military equipment has been airdropped in the area!</center></font>")
				new/obj/structure/closet/crate/airdrops/military(locationt)

			if("medicine")
				to_chat(world, "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Medicine has been airdropped in the area!</center></font>")
				new/obj/structure/closet/crate/airdrops/medicine(locationt)

			if("rad")
				to_chat(world, "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Radiation equipment has been airdropped in the area!</center></font>")
				new/obj/structure/closet/crate/airdrops/rads(locationt)

			if("cold")
				to_chat(world, "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Cold weather equipment has been airdropped in the area!</center></font>")
				new/obj/structure/closet/crate/airdrops/cold(locationt)

	spawn(rand(36000, 72000))
		supplydrop_proc()

///////////////////////////////////////////////
////////Wasteland 2: Electric Boogaloo/////////
///////////////////////////////////////////////

/obj/map_metadata/nomads/wasteland/two
	ID = MAP_NOMADS_WASTELAND_2
	title = "Wasteland II"
	gamemode = "Wasteland"
	hasnukes = FALSE
	is_zombie = TRUE
	lobby_icon = "icons/lobby/wasteland2.png"
	mission_start_message = "<big>Something has gone terribly wrong. The undead roam the world, and society has fallen. Can you survive?</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/gamemodes/Civilizations_and_Nomads</b>"
	ambience = list("sound/ambience/desert.ogg")
	songs = list(
		"Blawan - Why They Hide Their Bodies Under My Garage?:1" = "sound/music/whytheyhidetheirbodies.ogg",)

/obj/map_metadata/nomads/wasteland/two/proc/zombies(var/start = TRUE)
	for(var/obj/effect/spawner/mobspawner/zombies/special/S in world)
		S.activated = start


/////////////////////////////////////////////////
////////Wasteland 3: Return of the Antman////////
/////////////////////////////////////////////////

/obj/map_metadata/nomads/wasteland/three
	ID = MAP_NOMADS_WASTELAND_3
	title = "Wasteland III"
	gamemode = "Wasteland"
	hasnukes = FALSE
	is_zombie = FALSE
	lobby_icon = "icons/lobby/wasteland3.png"
	mission_start_message = "<big>The Great Radiance has rewritten the DNA of the survivors. In the ruins of the old world, the line between man and beast has blurred. Adapt to your new form, scavenge the toxic wastes, and prove that you are the one meant to inherit the earth.</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/gamemodes/Civilizations_and_Nomads</b>"
	ambience = list("sound/ambience/desert.ogg")
	songs = list(
		"Blawan - Why They Hide Their Bodies Under My Garage?:1" = "sound/music/whytheyhidetheirbodies.ogg",)
