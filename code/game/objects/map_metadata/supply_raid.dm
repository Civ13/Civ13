#define NO_WINNER "The fighting is still going."
/obj/map_metadata/supply_raid
	ID = MAP_SUPPLY_RAID
	title = "Supply Raid (100x75x1)"
	lobby_icon_state = "imperial"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 900
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		BRITISH,
		INDIANS)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british/land,
		list(INDIANS) = /area/caribbean/pirates/land
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(BRITISH = 0.35, INDIANS = 0.65)
	battle_name = "Supply Raid on Port Andrew"
	mission_start_message = "<font size=4>All factions have <b>8 minutes</b> to prepare before the combat starts.</font>"
	faction1 = BRITISH
	faction2 = INDIANS

	ambience = list('sound/ambience/jungle1.ogg')

obj/map_metadata/supply_raid/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_RP == TRUE)
		. = FALSE
	else if (J.is_army == TRUE)
		. = FALSE
	else if (J.is_coldwar == TRUE)
		. = FALSE
	else if (J.is_medieval == TRUE)
		. = FALSE
	else if (J.is_ww1 == TRUE)
		. = FALSE
	else if (istype(J, /datum/job/pirates/battleroyale))
		. = FALSE
	else if (istype(J, /datum/job/indians/tribes))
		. = FALSE
	else
		. = TRUE
/obj/map_metadata/supply_raid/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

/obj/map_metadata/supply_raid/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 4800 || admin_ended_all_grace_periods)

#undef NO_WINNER