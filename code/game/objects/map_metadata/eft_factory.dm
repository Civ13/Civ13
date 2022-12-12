/obj/map_metadata/eft_factory
	ID = MAP_EFT_FACTORY
	title = "Factory"
	lobby_icon = "icons/lobby/battleroyale.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 3000

	faction_organization = list(
		AMERICAN,
		RUSSIAN)

	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/german/,
		list(RUSSIAN) = /area/caribbean/russian/,
		)
	age = "2019"
	ordinal_age = 8
	faction_distribution_coeffs = list(GERMAN = 0.5, RUSSIAN = 0.5)
	battle_name = "Firefight of Chemical Plant No. 16"
	mission_start_message = "<font size=4>PMCs and scavengers alike remain scatter across the industrial estate and facilities of Chemical Plant No. 16. You have <b>2 minutes</b> to prepare.</font>"
	faction1 = AMERICAN
	faction2 = RUSSIAN
	var/list/extractees = list()
	grace_wall_timer = 3600
	gamemode = "Firefight"
	valid_weather_types = list(WEATHER_NONE)
	songs = list(
		"Тоска - Molchat Doma:1" = "sound/music/tocka.ogg",)

/obj/map_metadata/eft_factory/New()
	..()
	//extract()
	show_extractees()


/obj/map_metadata/eft_factory/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_eft == TRUE)
		. = FALSE
		if (J.is_outlaw == TRUE)
			. = TRUE
			if (J.title == "Scavenger")
				if(processes.ticker.playtime_elapsed >= 4000) // Make scavs playable after 400 seconds
					. = TRUE
				else
					. = FALSE
	else
		. = FALSE

/obj/map_metadata/eft_factory/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/eft_factory/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/eft_factory/roundend_condition_def2name(define)
	..()
	switch (define)
		if (AMERICAN)
			return "USEC"
		if (RUSSIAN)
			return "BEAR"
/obj/map_metadata/eft_factory/roundend_condition_def2army(define)
	..()
	switch (define)
		if (AMERICAN)
			return "USEC"
		if (RUSSIAN)
			return "BEAR"

/obj/map_metadata/eft_factory/army2name(army)
	..()
	switch (army)
		if ("USEC")
			return "USEC"
		if ("BEAR")
			return "BEAR"

/obj/map_metadata/eft_factory/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The BEAR may now cross the invisible wall!</font>"
	else if (faction == AMERICAN)
		return "<font size = 4>The USEC may now cross the invisible wall!</font>"

/obj/map_metadata/eft_factory/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<span class = 'userdanger'>The BEAR may no longer cross the invisible wall!</span>"
	else if (faction == AMERICAN)
		return "<span class = 'userdanger'>The USEC may no longer cross the invisible wall!</span>"
/*
/obj/map_metadata/eft_factory/proc/extract()
	for(var/turf/T in get_area_turfs(/area/caribbean/extract))
		for (var/mob/living/human/H in T)
			if(H.stat != DEAD)
				H << "Extracting, wait 10 seconds." 
				world << "[H.name] is extracting!"
				spawn(100)
					if(H.stat != DEAD)
						extractees += H.name
						qdel(H)
			extract()
*/

/obj/map_metadata/eft_factory/proc/show_extractees()
	spawn(3000)
		world << "<big>Extracted: [extractees] </big>"
		show_extractees()




/area/caribbean/extract/Entered(A)
	if(!istype(A,/mob/living/human))	return

	var/mob/living/human/H = A
	if(!H.ckey)	return
	if(H.stat != DEAD)
		H << "Extracting, wait 10 seconds." 
		world << "[H.name] is extracting!"
		spawn(100)
			if(H.stat != DEAD)
				//extractees += H.ckey
				qdel(H)

/*
/datum/extract/proc/check(var/list/areas, var/list/extractess)

	
	for (var/human in human_mob_list)
		var/mob/living/human/H = human
		if (H && H.original_job && H.client && H.stat == CONSCIOUS && !H.restrained() && !iscloset(H.loc))
			var/area/H_area = get_area(H)
			if (H_area && area_check(H_area, areas))
				spawn(100)
				if(H.stat != DEAD)
					extractees += H.ckey
					qdel(H)
	return FALSE
*/
///////////////////////////////Keys//////////////////////////////////////////////

/obj/item/weapon/key/eft/gate0
	name = "Gate 0 key"
	code = "1110"

/obj/item/weapon/key/eft/medgate
	name = "Med Tent Gate key"
	code = "1111"

/obj/item/weapon/key/eft/cellar
	name = "Cellar key"
	code = "1112"

/obj/item/weapon/key/eft/pump
	name = "Pumping Station front door key"
	code = "1113"

/obj/item/weapon/key/eft/pumpalt
	name = "Pumping Station back door key"
	code = "1114"

///////////////////////////////Doors//////////////////////////////////////////////

/obj/structure/simple_door/key_door/eft/gate0
	name = "Gate 0"
	code = "1110"

/obj/structure/simple_door/key_door/eft/medgate
	name = "Med Tent Gate"
	code = "1111"

/obj/structure/simple_door/key_door/eft/cellar
	name = "Cellar Door"
	code = "1112"

/obj/structure/simple_door/key_door/eft/pump
	name = "Pumping Station front door"
	code = "1113"

/obj/structure/simple_door/key_door/eft/pumpalt
	name = "Pumping Station back door"
	code = "1114"