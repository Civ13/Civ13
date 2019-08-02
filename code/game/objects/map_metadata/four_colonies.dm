#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/four_colonies
	ID = MAP_FOUR_COLONIES
	title = "Four Colonies (225x225x2)"
	lobby_icon_state = "imperial"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 7200 // 12 minutes!
	squad_spawn_locations = FALSE
	faction_organization = list(
		BRITISH,
		PORTUGUESE,
		FRENCH,
		SPANISH)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
	//nonexistent in this map, to prevent win by capture
		list(SPANISH) = /area/caribbean/british,
		list(PORTUGUESE) = /area/caribbean/british,
		list(FRENCH) = /area/caribbean/british,
		list(SPANISH) = /area/caribbean/british,
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(BRITISH = 0.25, SPANISH = 0.25, FRENCH = 0.25, PORTUGUESE = 0.25)
	battle_name = "Colonization"
	mission_start_message = "<big>Four countries have reached this Island! The <b>Colonists</b> must build their villages. After <b>30</b> minutes, the grace wall will end.</big><br><span class = 'notice'><i>THIS IS A RP MAP - ALL FACTIONS ARE FRIENDLY BY DEFAULT.</b> No griefing will be tolerated. If you break the rules, you will be banned from this gamemode!<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = INDIANS
	faction2 = CIVILIAN
	songs = list(
		"Nassau Shores:1" = 'sound/music/nassau_shores.ogg',)
	gamemode = "Faction-Based RP"

obj/map_metadata/four_colonies/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/civilian/fantasy))
		. = FALSE
	if (J.is_RP == FALSE)
		. = FALSE
	else if (J.is_army == TRUE)
		. = FALSE
	else if (J.is_medieval == TRUE)
		. = FALSE
	else if (J.is_ww1 == TRUE)
		. = FALSE
	else
		. = TRUE
/obj/map_metadata/four_colonies/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 18000 || admin_ended_all_grace_periods)

/obj/map_metadata/four_colonies/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 18000 || admin_ended_all_grace_periods)

/obj/map_metadata/four_colonies/cross_message(faction)
	return ""