
/obj/map_metadata/jungle_colony
	ID = MAP_JUNGLE_COLONY
	title = "Chaos Rising"
	no_winner ="The round is proceeding normally."
	lobby_icon_state = "imperial"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0

	faction_organization = list(
		CIVILIAN,
		INDIANS,
		PIRATES,
		SPANISH)

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
	mission_start_message = "<big>Europeans</b> have reached the shore! The <b>Colonists</b> must build their villages.<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = CIVILIAN
	faction2 = INDIANS
	is_RP = TRUE
	songs = list(
		"Nassau Shores:1" = 'sound/music/nassau_shores.ogg',)
	gamemode = "Colony Building RP"
obj/map_metadata/jungle_colony/job_enabled_specialcheck(var/datum/job/J)
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
		if (J.is_pioneer == TRUE)
			. = FALSE
		if (J.is_prison == TRUE)
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
/obj/map_metadata/jungle_colony/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/jungle_colony/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 15000 || admin_ended_all_grace_periods)

/obj/map_metadata/jungle_colony/cross_message(faction)
	return ""


