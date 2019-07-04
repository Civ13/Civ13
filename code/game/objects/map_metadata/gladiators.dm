#define NO_WINNER "The round is proceeding normally."
/obj/map_metadata/gladiators
	ID = MAP_GLADIATORS
	title = "Gladiators (100x100x1)"
	lobby_icon_state = "ancient"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall/)
	respawn_delay = 0
	squad_spawn_locations = FALSE
	faction_organization = list(
		ROMAN)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(ROMAN) = /area/caribbean/british,
		)
	age = "313 B.C."
	ordinal_age = 1
	faction_distribution_coeffs = list(ROMAN = 1)
	battle_name = "marooned pirates"
	mission_start_message = "<big>After a major storm, a Pirate shipwreck has come ashore in an unknown Island. However, they are not alone...<br> The gracewall will be up after <b>45 minutes</b>.</big><br><span class = 'notice'><i>THIS IS A RP MAP - NATIVES AND PIRATES ARE FRIENDLY BY DEFAULT.</b> No griefing will be tolerated. If you break the rules, you will be banned from this gamemode!<i></span>" // to be replaced with the round's main event
	ambience = list('sound/ambience/jungle1.ogg')
	faction1 = ROMAN
	songs = list(
		"Divinitus:1" = 'sound/music/divinitus.ogg',)
	gamemode = "Gladiatorial Combat"

obj/map_metadata/gladiators/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (istype(J, /datum/job/roman))
		if (J.is_gladiator == TRUE)
			. = TRUE
		else
			. = FALSE
/obj/map_metadata/gladiators/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 27000 || admin_ended_all_grace_periods)

/obj/map_metadata/gladiators/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 27000 || admin_ended_all_grace_periods)

/obj/map_metadata/gladiators/cross_message(faction)
	return "The gracewall is now removed."


#undef NO_WINNER