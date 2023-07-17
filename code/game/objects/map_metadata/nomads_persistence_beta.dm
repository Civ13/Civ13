/obj/map_metadata/nomads_persistence_beta
	ID = MAP_NOMADS_PERSISTENCE_BETA
	title = "Nations RP (Persistence BETA)"
	lobby_icon = "icons/lobby/campaign.png"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 3000 // 5 minutes
	has_hunger = TRUE
	faction_organization = list(
		PIRATES,
		CIVILIAN)

	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/japanese,
		list(CIVILIAN) = /area/caribbean/british,
		)
	age = "2023"
	no_winner = "The round is proceeding normally."
	is_RP = TRUE
	civilizations = TRUE
	faction_distribution_coeffs = list(PIRATES = 0.5, CIVILIAN = 0.5)
	battle_name = "the nations"
	faction1 = PIRATES
	faction2 = CIVILIAN
	availablefactions = list("Redmenian Civilian", "Blugoslavian Civilian")
	mission_start_message = "<big>Two modern countries govern this land. The grace wall will end in <b>2 DAYS</b>. This is an event round, both factions will go into TOTAL WAR and must capture and hold the most petrolium spring as possible.</b>"
	ambience = list('sound/ambience/jungle1.ogg')
	nomads = FALSE
	availablefactions_run = FALSE
	songs = list(
		"Emma:1" = "sound/music/emma.ogg",)
	default_research = 210
	gamemode = "Nations RP (Persistence)"
	ordinal_age = 8
	age1_done = TRUE
	age2_done = TRUE
	age3_done = TRUE
	age4_done = TRUE
	age5_done = TRUE
	age6_done = TRUE
	age7_done = TRUE
	age8_done = TRUE
	research_active = FALSE
	grace_wall_timer = 2 DAYS
	force_mapgen = TRUE

/obj/map_metadata/nomads_persistence_beta/New()
	..()
	civname_a = "Redmenian Nation"
	civname_b = "Blugoslavian Nation"
	var/newnamea = list("Redmenian Nation" = list(default_research,default_research,default_research,null,0,"star","#D7A326","#DA1515"))
	var/newnameb = list("Blugoslavian Nation" = list(default_research,default_research,default_research,null,0,"sun","#B5AA6C","#2A44CF"))
	custom_civs += newnamea
	custom_civs += newnameb
	civa_research = list(default_research,default_research,default_research,null)
	civb_research = list(default_research,default_research,default_research,null)
	spawn(18000)
		seasons()
		config.no_respawn_delays = FALSE

/obj/map_metadata/nomads_persistence_beta/cross_message(faction)
	var/warning_sound = sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = TRUE, channel = 777)
	for (var/mob/M in player_list)
		M.client << warning_sound

	if (faction == PIRATES)
		return "<font size = 5><b>THE GRACE PERIOD HAS ENDED, REDMENIA AND BLUGOSLAVIA ARE AT WAR!</b></font>"
	else if (faction == CIVILIAN)
		return "<font size = 5><b>THE GRACE PERIOD HAS ENDED, REDMENIA AND BLUGOSLAVIA ARE AT WAR!</b></font>"
	else
		return ""

/obj/map_metadata/nomads_persistence_beta/check_caribbean_block(var/mob/living/human/H, var/turf/T)
	if (!istype(H) || !istype(T))
		return FALSE
	var/area/A = get_area(T)
	if (istype(A, /area/caribbean/no_mans_land/invisible_wall))
		if (istype(A, /area/caribbean/no_mans_land/invisible_wall/two))
			if (H.faction_text == faction1)
				return TRUE
		else if (istype(A, /area/caribbean/no_mans_land/invisible_wall/one))
			if (H.faction_text == faction2)
				return TRUE
		else
			return !faction1_can_cross_blocks()
	return FALSE

/obj/map_metadata/nomads_persistence_beta/proc/captured_enemy_capital(var/faction)
	switch (faction)
		if ("Redmenia")
			var/warning_sound = sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			for (var/mob/M in player_list)
				M.client << warning_sound
			world << "<font size = 5><b>REDMENIA HAS CAPTURED THE BLUGOSLAVIAN CAPITAL.</b></font>"
		if ("Blugoslavia")
			var/warning_sound = sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			for (var/mob/M in player_list)
				M.client << warning_sound
			world << "<font size = 5><b>BLUGOSLAVIA HAS CAPTURED THE REDMENIAN CAPITAL.</b></font>"
	return

/obj/map_metadata/nomads_persistence_beta/proc/lost_control_enemy_capital(var/faction)
	switch (faction)
		if ("Redmenia")
			var/warning_sound = sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			for (var/mob/M in player_list)
				M.client << warning_sound
			world << "<font size = 5><b>REDMENIA HAS LOST CONTROL OVER THE BLUGOSLAVIAN CAPITAL.</b></font>"
		if ("Blugoslavia")
			var/warning_sound = sound('sound/effects/siren_once.ogg', repeat = FALSE, wait = TRUE, channel = 777)
			for (var/mob/M in player_list)
				M.client << warning_sound
			world << "<font size = 5><b>BLUGOSLAVIA HAS LOST CONTROL OVER THE REDMENIAN CAPITAL.</b></font>"
	return