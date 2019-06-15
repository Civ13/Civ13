#define NO_WINNER "The crew is alive."
/obj/map_metadata/cursed_island
	ID = MAP_CURSED_ISLAND
	title = "Cursed Island (100x100x1)"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall,
		/area/caribbean/no_mans_land/invisible_wall/inside)
	respawn_delay = 0
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		BRITISH,)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(BRITISH) = /area/caribbean/british
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(BRITISH = 1)
	battle_name = "battle of the cursed island"
	mission_start_message = "<big>After a storm, your battered ship had to dock at this island for repairs. Only then did the crew notice something was wrong about this place...<br><b>Retrieve the cursed treasure and bring it back to the ship to break the curse!</b></big>"
	ambience = list('sound/ambience/rain.ogg')
	faction1 = BRITISH
	availablefactions_run = TRUE
	songs = list(
		"Words Trough the Sky:1" = 'sound/music/words_through_the_sky.ogg',)
	gamemode = "Player vs NPCs"
obj/map_metadata/cursed_island/job_enabled_specialcheck(var/datum/job/J)
	..()
	if (J.is_RP == TRUE)
		. = FALSE
	else if (J.is_army == TRUE)
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

/obj/map_metadata/cursed_island/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/cursed_island/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/cursed_island/cross_message(faction)
	return ""

/obj/map_metadata/cursed_island/update_win_condition()
	var/treasure_location = get_area(locate(/obj/item/cursedtreasure))
	if (win_condition_spam_check)
		return FALSE
	if (istype(treasure_location, /area/caribbean/british/ship))
		ticker.finished = TRUE
		var/message = "The treasure was retrieved! The curse is broken!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		show_global_battle_report(null)
		win_condition_spam_check = TRUE
		return FALSE
#undef NO_WINNER