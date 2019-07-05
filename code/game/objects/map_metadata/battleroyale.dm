#define NO_WINNER "The fighting is still going."
/obj/map_metadata/battleroyale
	ID = MAP_ROBUSTA
	title = "Isla Robusta Battle Royale (125x125x1)"
	lobby_icon_state = "imperial"
	caribbean_blocking_area_types = list(/area/caribbean/no_mans_land/invisible_wall)
	respawn_delay = 0
	squad_spawn_locations = FALSE
//	min_autobalance_players = 90
	faction_organization = list(
		PIRATES)
	available_subfactions = list(
		)
	roundend_condition_sides = list(
		list(PIRATES) = /area/caribbean/british/ship, //it isnt in the map so nobody wins by capture
		)
	age = "1713"
	ordinal_age = 3
	faction_distribution_coeffs = list(PIRATES = 1)
	battle_name = "Battleroyale at Isla Robusta"
	mission_start_message = "<font size=4>You and several other pirates were abandoned at this forsaken island. Only one can survive! <b>Last standing player wins!</b></font>"
	var/winner_name = "Unknown"
	var/winner_ckey = "Unknown"
	faction1 = PIRATES
	faction2 = PIRATES
	var/message = ""
	gamemode = "Battleroyale"

/obj/map_metadata/battleroyale/job_enabled_specialcheck(var/datum/job/J)

	..()
	if (J.is_RP == TRUE)
		. = FALSE
	else if (J.is_army == TRUE)
		. = FALSE
	else if (J.is_coldwar == TRUE)
		. = FALSE
	else if (J.is_medieval == TRUE)
		. = FALSE
	else if (J.is_marooned == TRUE)
		. = FALSE
	else if (istype(J, /datum/job/pirates/battleroyale))
		J.total_positions = 32
		J.min_positions = 32
		J.max_positions = 32
		. = TRUE
	else
		. = FALSE
	return .

/obj/map_metadata/battleroyale/faction2_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/battleroyale/faction1_can_cross_blocks()
	return (processes.ticker.playtime_elapsed >= 1200 || admin_ended_all_grace_periods)

/obj/map_metadata/battleroyale/cross_message(faction)
	return "<font size = 4><b>The round has started!</b> Players may now cross the invisible wall!</font>"
/*
/obj/map_metadata/robusta/win_condition_specialcheck()
	if (alive_n_of_side(PIRATES) <= 1 && processes.ticker.playtime_elapsed >= 1200)
		for (var/mob/living/carbon/human/H in player_list)
			if (H.original_job && H.stat != DEAD)
				if (H.original_job.base_type_flag() == PIRATES)
					winner_name =  H.name
					winner_ckey = H.ckey
					message = "The battle is over! [winner_name] ([winner_ckey]) was the winner!"
		return FALSE
	else
		return TRUE
*/
/obj/map_metadata/battleroyale/update_win_condition()
	if (world.time >= 36000)
		if (win_condition_spam_check)
			return FALSE
		ticker.finished = TRUE
		message = "One hour has passed! The combat has ended in a stalemate!"
		world << "<font size = 4><span class = 'notice'>[message]</span></font>"
		win_condition_spam_check = TRUE
		return FALSE
	if (processes.ticker.playtime_elapsed >= 1200)
		if (alive_n_of_side(PIRATES) <= 1)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == PIRATES)
						winner_name =  H.name
						winner_ckey = H.ckey
						message = "The battle is over! [winner_name] ([winner_ckey]) was the winner!"
						world << "<font size = 4><span class = 'notice'>[message]</span></font>"
						win_condition_spam_check = TRUE
			ticker.finished = TRUE
			return FALSE

#undef NO_WINNER