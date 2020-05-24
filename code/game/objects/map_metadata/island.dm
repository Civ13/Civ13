
/obj/map_metadata/island
	ID = MAP_ISLAND
	title = "Skull Island"
	lobby_icon_state = "imperial"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 600

	no_winner ="No faction has captured the enemy's base."
	var/do_once_activations = TRUE

	faction_organization = list(
		BRITISH,
		PIRATES)

	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british/ship/,
		list(PIRATES) = /area/caribbean/pirates/land/inside
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(BRITISH = 0.5, PIRATES = 0.5)
	//songs = list()
	meme = TRUE
	battle_name = "Skull Island"
	mission_start_message = "<font size=4>All factions have <b>5 minutes</b> to prepare before the combat starts.</font>"
	var/done = FALSE
obj/map_metadata/island/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_RP == TRUE)
		. = FALSE
	else if (J.is_army == TRUE)
		. = FALSE
	else if (J.is_coldwar == TRUE)
		. = FALSE
	else if (J.is_ww1 == TRUE)
		. = FALSE
	else if (J.is_marooned == TRUE)
		. = FALSE
	else if (J.is_medieval == TRUE)
		. = FALSE
	else if (istype(J, /datum/job/pirates/battleroyale))
		. = FALSE
	else if (istype(J, /datum/job/indians/tribes))
		. = FALSE
	else if (J.is_prison == TRUE)
		. = FALSE
	else if (J.is_ww2 == TRUE)
		. = FALSE
	else
		. = TRUE
/obj/map_metadata/island/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/island/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 3000 || admin_ended_all_grace_periods)

/obj/map_metadata/island/tick()
	..()
	if (processes.ticker.playtime_elapsed >= 3600 || admin_ended_all_grace_periods)
		for (var/obj/effect/area_teleporter/AT)
			AT.Activated()
		do_once_activations = FALSE

