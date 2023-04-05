/obj/map_metadata/eft_factory
	ID = MAP_EFT_FACTORY
	title = "Factory"
	lobby_icon = "icons/lobby/battleroyale.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 3000

	faction_organization = list(
		AMERICAN,
		RUSSIAN,
		CIVILIAN)

	roundend_condition_sides = list(
		list(GERMAN) = /area/caribbean/german,
		list(RUSSIAN) = /area/caribbean/russian,
		list(CIVILIAN) = /area/caribbean/roman,
		)
	age = "2019"
	ordinal_age = 8
	faction_distribution_coeffs = list(GERMAN = 0.4, RUSSIAN = 0.4, CIVILIAN = 0.2)
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
				if(processes.ticker.playtime_elapsed >= 5 MINUTES)
					. = TRUE
				else
					. = FALSE
	else
		. = FALSE

/obj/map_metadata/eft_factory/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2 MINUTES || admin_ended_all_grace_periods)

/obj/map_metadata/eft_factory/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 2 MINUTES || admin_ended_all_grace_periods)

/obj/map_metadata/eft_factory/roundend_condition_def2name(define)
	..()
	switch (define)
		if (AMERICAN)
			return "USEC"
		if (RUSSIAN)
			return "BEAR"
		if (CIVILIAN)
			return "Scavs"
/obj/map_metadata/eft_factory/roundend_condition_def2army(define)
	..()
	switch (define)
		if (AMERICAN)
			return "USEC"
		if (RUSSIAN)
			return "BEAR"
		if (CIVILIAN)
			return "Scavs"

/obj/map_metadata/eft_factory/army2name(army)
	..()
	switch (army)
		if ("USEC")
			return "USEC"
		if ("BEAR")
			return "BEAR"
		if ("Scavs")
			return "Scavs"

/obj/map_metadata/eft_factory/cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The operation has begun!</font>"
	else if (faction == AMERICAN)
		return ""
	else if (faction == CIVILIAN)
		return ""
	else
		return ""

/obj/map_metadata/eft_factory/reverse_cross_message(faction)
	if (faction == RUSSIAN)
		return "<font size = 4>The has stopped!</font>"
	else if (faction == AMERICAN)
		return ""
	else if (faction == CIVILIAN)
		return ""
	else
		return ""

/obj/map_metadata/eft_factory/proc/show_extractees()
	if (extractees.len)
		world << "<big><b>Extracted:</b></big>"
		world << "<big>[jointext(extractees,"\n")]</big>"
	spawn(1 MINUTE)
	show_extractees()

/area/caribbean/extract/Entered(var/atom/movable/A)
	var/obj/map_metadata/eft_factory/MEFT = map
	if(!istype(A,/mob/living/human)) return

	var/mob/living/human/H = A
	if(!H.ckey)	return
	if(H.stat != DEAD)
		H << SPAN("b","Extracting, wait 10 seconds.")
		if(do_after(H,10 SECONDS,H,FALSE,can_move = FALSE))
			if(H.stat != DEAD)
				MEFT.extractees += "[H.ckey]"
				world << "[H.ckey] has extracted!"
				H.ghostize()
				qdel(H)
				return
			return
		else
			H << SPAN("b","You have moved, extraction failed.")
			return
/*
/datum/extract/proc/check(var/list/areas, var/list/extractess)
	for (var/mob/living/human/H in get_area_turfs(/area/caribbean/supply))
		if (H && H.original_job && H.client && H.stat == CONSCIOUS && !H.restrained() && !iscloset(H.loc))
			var/area/H_area = get_area(H)
			if (H_area && area_check(H_area, areas))
				spawn(100)
				if(H.stat != DEAD)
					extractees += H.ckey += ";"
					qdel(H)
*/
/area/caribbean/extract
	name = "extract"
	icon_state = "green1"

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