/obj/map_metadata/eft_factory
	ID = MAP_EFT_FACTORY
	title = "Factory"
	lobby_icon = 'icons/lobby/battleroyale.png'
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
		"Тоска - Molchat Doma:1" = 'sound/music/toska.ogg',)

/obj/map_metadata/eft_factory/New()
	..()
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
		to_chat(world, "<big><b>Extracted:</b></big>")
		to_chat(world, "<big>[jointext(extractees[1],"\n")]</big>")
	spawn(1 MINUTE)
	show_extractees()

/area/caribbean/extract/Entered(var/atom/movable/A)
	var/obj/map_metadata/eft_factory/MEFT = map
	if (!istype(A, /mob/living/human))	return

	var/mob/living/human/H = A
	if (!H.ckey)	return
	if (H.stat != DEAD)
		to_chat(H, "<big><font color='green'>Extracting, wait 10 seconds.</font></big>")
		if (do_after(H, 10 SECONDS, H, FALSE, can_move = TRUE))
			if (istype(get_area(H), /area/caribbean/extract))
				if (H.stat != DEAD)
					var/extracted_value = 0
					for (var/obj/item/I in H.contents)
						extracted_value += I.value
					MEFT.extractees += list("[H.ckey]", extracted_value)
					to_chat(world, "<big><font color='green'>[H.ckey] has extracted!</font></big>")
					H.ghostize()
					qdel(H)
					return
			else
				to_chat(H, SPAN_DANGER("Extraction failed - Left extraction zone."))
				return
	return

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