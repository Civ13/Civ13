/obj/map_metadata/nomads/frozen_wasteland
	ID = MAP_NOMADS_FROZEN_WASTELAND
	title = "Frozen Wasteland"
	is_wasteland = TRUE
	age = "2013"
	mission_start_message = "<big>The world has become desolate and frozen.</big><br><b>Wiki Guide: https://civ13.github.io/civ13-wiki/gamemodes/Civilizations_and_Nomads</b>"
	ambience = list("sound/ambience/desert.ogg")
	research_active = TRUE

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

/obj/map_metadata/nomads/frozen_wasteland/New()
	..()
	if(durable_schedule("nomads_wasteland_boot", 10)) return
	spawn(10)
		var/randtimer = rand(10,20)
		if (hasnukes)
			nuke_proc(randtimer)
			supplydrop_proc()
		else
			supplydrop_proc()

/obj/map_metadata/nomads/frozen_wasteland/proc/nuke_proc(var/timer=15)
	if(uses_durable_metadata()) nomads_nuke_threshold = timer
	if (processes.ticker.playtime_elapsed > timer && hasnukes )
		var/vx = rand(25,world.maxx-25)
		var/vy = rand(25,world.maxy-25)
		var/turf/epicenter = get_turf(locate(vx,vy,2))
		to_chat(world, "<font size=3 color='red'><center>ATTENTION<br>A nuclear missile is incoming! Take cover!</center></font>")
		var/warning_sound = sound("sound/misc/siren.ogg", repeat = FALSE, wait = TRUE, channel = 777)
		for (var/mob/M in player_list)
			M.client << warning_sound
		if(uses_durable_metadata())
			if(!epicenter) throw EXCEPTION("Nomads nuke target is unavailable")
			nomads_nuke_x = vx
			nomads_nuke_y = vy
			nomads_nuke_z = 2
			durable_schedule("nomads_nuke_fire", 330)
			return
		spawn(330)
			to_chat(world, "<font size=4 color='red'>A nuclear explosion has happened! <br><i>(Game might freeze/lag for a while while processing, please wait)</i></font>")
			nuke_map(epicenter, 200, 180, 0)
			message_admins("Automatic nuke deployed at ([epicenter.x],[epicenter.y],[epicenter.z]) in area [epicenter.loc.name].")
			log_game("Automatic nuke deployed at ([epicenter.x],[epicenter.y],[epicenter.z]) in area [epicenter.loc.name].")
			return
	else
		if(durable_schedule("nomads_nuke_check", 600)) return
		spawn(600) // 1 minute
			nuke_proc(timer)
	return

/obj/map_metadata/nomads/frozen_wasteland/proc/supplydrop_proc()
	if ((global_radiation >= 280 && hasnukes)||(is_zombie == TRUE))
		var/droptype = pick("supplies","food","weapons","military","medicine","rad","cold")
		var/turf/locationt = pick(supplydrop_turfs)
		switch(droptype)
			if("supplies")
				to_chat(world, "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Supplies have been airdropped in the area!</center></font>")
				new/obj/structure/closet/crate/airdrops/supplies(locationt)

			if("food")
				to_chat(world, "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Food has been airdropped in the area!</center></font>")
				new/obj/structure/closet/crate/airdrops/food(locationt)
				new/obj/item/weapon/reagent_containers/glass/barrel/modern/water(locationt)

			if("weapons")
				to_chat(world, "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Weapons and ammunition have been airdropped in the area!</center></font>")
				new/obj/structure/closet/crate/airdrops/weapons(locationt)

			if("military")
				to_chat(world, "<font size=3 color='red'><center>EMERGENCY BROADCAST SYSTEM<br>Military equipment has been airdropped in the area!</center></font>")
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
	var/delay = rand(36000, 72000)
	if(durable_schedule("nomads_supplydrop", delay)) return
	spawn(delay)
		supplydrop_proc()

/obj/map_metadata/nomads/frozen_wasteland/proc/zombies(var/start = TRUE)
	if (is_zombie == TRUE)
		for(var/obj/effect/spawner/mobspawner/zombies/special/S in world)
			S.activated = start