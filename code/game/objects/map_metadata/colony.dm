#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/colony
	ID = MAP_COLONY
	title = "Colony (155x225x2)"
	lobby_icon_state = "imperial"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 7200 // 12 minutes!
	squad_spawn_locations = FALSE
	faction_organization = list(
		INDIANS,
		CIVILIAN,
		PIRATES,
		SPANISH)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(INDIANS) = /area/caribbean/british,
		list(CIVILIAN) = /area/caribbean/british,
		list(PIRATES) = /area/caribbean/british,
		list(SPANISH) = /area/caribbean/british,
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(INDIANS = 0.4, CIVILIAN = 0.4, PIRATE = 0.1, SPANISH = 0.1)
	battle_name = "new colony"
	mission_start_message = "<big>Europeans</b> have reached the shore! The <b>Colonists</b> must build their villages. The gracewall will be up after 25 minutes.</big><br><span class = 'notice'><i>THIS IS A RP MAP - NATIVES AND COLONISTS ARE FRIENDLY BY DEFAULT.</b> No griefing will be tolerated. If you break the rules, you will be banned from this gamemode!<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	faction2 = CIVILIAN
	songs = list(
		"Nassau Shores:1" = 'sound/music/nassau_shores.ogg',)
	gamemode = "Colony Building RP"
obj/map_metadata/colony/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian))
		. = TRUE
		if (J.is_nomad == TRUE)
			. = FALSE
		if (J.is_cowboy == TRUE)
			. = FALSE
		if (J.is_civilizations == TRUE)
			. = FALSE
		if (J.is_rcw == TRUE)
			. = FALSE
	else if (istype(J, /datum/job/spanish/civilian))
		. = FALSE
	else if (J.is_medieval == TRUE)
		. = FALSE
	else if (istype(J, /datum/job/pirates/battleroyale))
		. = FALSE
	else if (J.is_army == TRUE)
		. = FALSE
	else if (J.is_marooned == TRUE)
		. = FALSE
	else if (istype(J, /datum/job/indians))
		if (istype(J, /datum/job/indians/tribes))
			. = FALSE
		else
			. = TRUE
	else
		. = TRUE
	if (istype(J, /datum/job/civilian/fantasy))
		. = FALSE
/obj/map_metadata/colony/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/colony/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/colony/cross_message(faction)
	return ""


#undef NO_WINNER